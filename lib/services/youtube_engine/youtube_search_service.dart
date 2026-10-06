import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:spotube/services/youtube_engine/youtube_engine.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeSearchService {
  static final _filterRegex = RegExp(
    r"\s*(\(|\[)(official\s*(music\s*)?(video|audio)|video\s*oficial|audio\s*oficial|visualizer|letra(\/lyrics)?|lyrics)(\)|\])",
    caseSensitive: false,
  );

  static SpotubeFullTrackObject videoToSpotubeTrack(Video video) {
    var cleanTitle = video.title
        .replaceAll(_filterRegex, "")
        .replaceAll(
          RegExp(r"\[(4k|hd|hq|remastered|official).*?\]",
              caseSensitive: false),
          "",
        )
        .replaceAll(RegExp(r"\|.*$"), "")
        .replaceAll(RegExp(r"\s+[–—]\s+"), " - ")
        .trim();

    String artistName = video.author;
    String trackName = cleanTitle;

    if (cleanTitle.contains(" - ")) {
      final parts = cleanTitle.split(" - ");
      final p0 = parts[0].trim();
      final p1 = parts.sublist(1).join(" - ").trim();
      final authorLower = video.author.toLowerCase();

      if (p0.toLowerCase().contains(authorLower) ||
          authorLower.contains(p0.toLowerCase())) {
        artistName = p0;
        trackName = p1;
      } else if (p1.toLowerCase().contains(authorLower) ||
          authorLower.contains(p1.toLowerCase())) {
        artistName = p1;
        trackName = p0;
      } else {
        artistName = p0;
        trackName = p1;
      }
    }

    final thumbnailUrl = video.thumbnails.highResUrl.isNotEmpty
        ? video.thumbnails.highResUrl
        : video.thumbnails.mediumResUrl;

    final durationMs = video.duration?.inMilliseconds ?? 0;

    final cleanArtist = artistName
        .replaceFirst(RegExp(r"\s*-\s*Topic$", caseSensitive: false), "")
        .replaceFirst(RegExp(r"\s+VEVO$", caseSensitive: false), "")
        .replaceFirst(RegExp(r"\s+Official$", caseSensitive: false), "")
        .trim();
    final artistId =
        "yt-artist:${Uri.encodeComponent(cleanArtist)}::img:${Uri.encodeComponent(thumbnailUrl)}";

    return SpotubeFullTrackObject(
      id: "yt:${video.id.value}",
      name: trackName,
      externalUri: "https://youtube.com/watch?v=${video.id.value}",
      durationMs: durationMs,
      explicit: false,
      isrc: "",
      artists: [
        SpotubeSimpleArtistObject(
          id: artistId,
          name: cleanArtist,
          externalUri: "https://youtube.com/channel/${video.channelId.value}",
          images: [
            SpotubeImageObject(
              url: thumbnailUrl,
              height: 300,
              width: 300,
            ),
          ],
        ),
      ],
      album: SpotubeSimpleAlbumObject(
        id: "yt-album:${video.id.value}",
        name: trackName,
        externalUri: "https://youtube.com/watch?v=${video.id.value}",
        albumType: SpotubeAlbumType.single,
        releaseDate: video.uploadDate?.toIso8601String() ?? "",
        artists: [
          SpotubeSimpleArtistObject(
            id: artistId,
            name: cleanArtist,
            externalUri:
                "https://youtube.com/channel/${video.channelId.value}",
            images: [
              SpotubeImageObject(
                url: thumbnailUrl,
                height: 300,
                width: 300,
              ),
            ],
          ),
        ],
        images: [
          SpotubeImageObject(
            url: thumbnailUrl,
            height: 300,
            width: 300,
          ),
        ],
      ),
    );
  }

  static Future<List<SpotubeFullTrackObject>> search(
    String query,
    YouTubeEngine youtubeEngine, {
    int limit = 15,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    try {
      final videos = await youtubeEngine.searchVideos(trimmedQuery);
      return videos.take(limit).map(videoToSpotubeTrack).toList();
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return [];
    }
  }
}
