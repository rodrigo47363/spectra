import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:spotube/models/database/database.dart';
import 'package:spotube/services/kv_store/kv_store.dart';
import 'package:spotube/services/youtube_engine/youtube_engine.dart';
import 'package:spotube/utils/platform.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:yt_dlp_dart/yt_dlp_dart.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';

class YtDlpEngine implements YouTubeEngine {
  MediaType _parseMediaType(String? ext) {
    try {
      if (ext == null || ext.isEmpty || ext == "m4a") {
        return MediaType("audio", "mp4");
      }
      return MediaType("audio", ext);
    } catch (_) {
      return MediaType("audio", "mp4");
    }
  }

  StreamContainer _parseContainer(dynamic container, dynamic protocol) {
    try {
      final name = (container?.toString() ?? "")
          .replaceAll("_dash", "")
          .replaceAll("m4a", "mp4");
      if (name.isNotEmpty) {
        return StreamContainer.parse(name);
      }
      if (protocol?.toString() == "m3u8_native") {
        return StreamContainer.parse("m3u8");
      }
      return StreamContainer.mp4;
    } catch (_) {
      return StreamContainer.mp4;
    }
  }

  StreamManifest _parseFormats(List formats, videoId) {
    final audioOnlyStreams = formats
        .where((f) => f is Map && (f["resolution"] == "audio only" || f["vcodec"] == "none"))
        .sorted((a, b) {
          final qA = (a["quality"] as num?) ?? 0;
          final qB = (b["quality"] as num?) ?? 0;
          return qA > qB ? 1 : -1;
        })
        .map((f) {
      final filesize = f["filesize"] ?? f["filesize_approx"];
      final abr = f["abr"] ?? f["tbr"] ?? 0;
      final bitrateVal = (((abr is num ? abr : (num.tryParse(abr.toString()) ?? 0))) * 1000).toInt();
      final qualityLabel = switch (bitrateVal) {
        > 130 * 1024 => "high",
        > 64 * 1024 => "medium",
        _ => "low",
      };

      return AudioOnlyStreamInfo(
        VideoId(videoId),
        f["format_id"] is int
            ? f["format_id"]
            : (int.tryParse(f["format_id"]?.toString() ?? "0") ?? 0),
        Uri.parse(f["url"]),
        _parseContainer(f["container"], f["protocol"]),
        filesize != null
            ? FileSize(filesize is int ? filesize : (int.tryParse(filesize.toString()) ?? 0))
            : FileSize.unknown,
        Bitrate(bitrateVal),
        f["acodec"]?.toString() ?? "aac",
        f["format_note"]?.toString() ?? qualityLabel,
        [],
        _parseMediaType(f["audio_ext"]?.toString()),
        null,
      );
    });

    return StreamManifest(audioOnlyStreams);
  }

  Video _parseInfo(Map<String, dynamic> info) {
    DateTime publishDate;
    try {
      final uploadDateStr = info["upload_date"]?.toString();
      if (uploadDateStr != null && uploadDateStr.length == 8) {
        publishDate = DateTime.tryParse(
              "${uploadDateStr.substring(0, 4)}-${uploadDateStr.substring(4, 6)}-${uploadDateStr.substring(6, 8)}",
            ) ??
            DateTime.now();
      } else if (uploadDateStr != null && int.tryParse(uploadDateStr) != null) {
        publishDate = DateTime.fromMillisecondsSinceEpoch(
          int.parse(uploadDateStr) * 1000,
        );
      } else {
        publishDate = DateTime.now();
      }
    } catch (_) {
      publishDate = DateTime.now();
    }
    return Video(
      VideoId(info["id"]),
      info["title"]?.toString() ?? "",
      info["channel"]?.toString() ?? (info["uploader"]?.toString() ?? ""),
      ChannelId(info["channel_id"]?.toString() ?? ""),
      publishDate,
      info["upload_date"] as String? ?? DateTime.now().toString(),
      publishDate,
      info["description"]?.toString() ?? "",
      Duration(seconds: ((info["duration"] as num?)?.toInt()) ?? 0),
      ThumbnailSet(info["id"]),
      (info["tags"] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      Engagement(
        ((info["view_count"] as num?)?.toInt()) ?? 0,
        (info["like_count"] as num?)?.toInt(),
        null,
      ),
      info["is_live"] ?? false,
    );
  }

  static bool get isAvailableForPlatform => kIsDesktop;

  static Future<String?> findYtDlpBinary() async {
    final customPath = KVStoreService.getYoutubeEnginePath(YoutubeClientEngine.ytDlp);
    if (customPath != null && await File(customPath).exists()) {
      return customPath;
    }
    final home = Platform.environment['HOME'] ?? '';
    final candidates = [
      if (home.isNotEmpty) '$home/.local/bin/yt-dlp',
      '/usr/local/bin/yt-dlp',
      '/usr/bin/yt-dlp',
      '/bin/yt-dlp',
    ];
    for (final path in candidates) {
      if (await File(path).exists()) {
        return path;
      }
    }
    if (await YtDlp.instance.checkAvailableInPath()) {
      return "yt-dlp${Platform.isWindows ? '.exe' : ''}";
    }
    return null;
  }

  static Future<bool> isInstalled() async {
    if (!isAvailableForPlatform) return false;
    final binary = await findYtDlpBinary();
    if (binary != null) {
      try {
        await YtDlp.instance.setBinaryLocation(binary);
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  @override
  Future<StreamManifest> getStreamManifest(String videoId) async {
    try {
      final formats = await YtDlp.instance.extractInfo(
        "https://www.youtube.com/watch?v=$videoId",
        formatSpecifiers: "%(formats)j",
        extraArgs: [
          "--no-check-certificate",
          "--geo-bypass",
          "--quiet",
          "--ignore-errors"
        ],
      );

      if (formats is List) {
        return _parseFormats(formats, videoId);
      }
    } catch (_) {}

    final info = await YtDlp.instance.extractInfo(
      "https://www.youtube.com/watch?v=$videoId",
      formatSpecifiers: "%()j",
      extraArgs: [
        "--no-check-certificate",
        "--geo-bypass",
        "--quiet",
        "--ignore-errors"
      ],
    );

    if (info is Map && info["formats"] is List) {
      return _parseFormats(info["formats"] as List, videoId);
    }

    throw Exception("No audio streams found for videoId: $videoId");
  }

  @override
  Future<Video> getVideo(String videoId) async {
    final info = await YtDlp.instance.extractInfo(
      "https://www.youtube.com/watch?v=$videoId",
      formatSpecifiers: "%()j",
      extraArgs: [
        "--skip-download",
        "--no-check-certificate",
        "--geo-bypass",
        "--quiet",
        "--ignore-errors",
      ],
    ) as Map<String, dynamic>;

    return _parseInfo(info);
  }

  @override
  Future<(Video, StreamManifest)> getVideoWithStreamInfo(String videoId) async {
    final info = await YtDlp.instance.extractInfo(
      "https://www.youtube.com/watch?v=$videoId",
      formatSpecifiers: "%()j",
      extraArgs: [
        "--no-check-certificate",
        "--geo-bypass",
        "--quiet",
        "--ignore-errors",
      ],
    ) as Map<String, dynamic>;

    return (_parseInfo(info), _parseFormats(info["formats"], videoId));
  }

  @override
  Future<List<Video>> searchVideos(String query) async {
    final stdout = await YtDlp.instance.extractInfoString(
      "ytsearch10:$query",
      formatSpecifiers: "%()j",
      extraArgs: [
        "--skip-download",
        "--no-check-certificate",
        "--geo-bypass",
        "--quiet",
        "--ignore-errors",
        "--flat-playlist",
        "--no-playlist",
      ],
    );

    final items = <Video>[];
    for (final line in stdout.split("\n")) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          items.add(_parseInfo(decoded));
        } else if (decoded is Map) {
          items.add(_parseInfo(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {}
    }

    return items;
  }

  @override
  void dispose() {}
}
