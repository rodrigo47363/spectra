import 'dart:convert';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:http/http.dart' as http;
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/wikipedia/wikipedia.dart';

class MetadataPluginArtistEndpoint {
  final Hetu hetu;
  MetadataPluginArtistEndpoint(this.hetu);

  HTInstance get hetuMetadataArtist =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("artist")
          as HTInstance;

  HTInstance? get _hetuMetadataSearch {
    try {
      return (hetu.fetch("metadataPlugin") as HTInstance).memberGet("search")
          as HTInstance;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveMbId(String query) async {
    final search = _hetuMetadataSearch;
    if (search == null) return null;
    try {
      final raw = await search.invoke(
        "artists",
        positionalArgs: [query],
        namedArgs: {"limit": 1},
      ).timeout(const Duration(seconds: 4));
      if (raw is Map && raw['items'] is List && (raw['items'] as List).isNotEmpty) {
        final first = (raw['items'] as List).first;
        if (first is Map && first['id'] != null) {
          return first['id'].toString();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<({List<SpotubeImageObject> images, int? followers})?>
      _resolveArtistOnlineInfo(String artistName) async {
    final cleanName = artistName.trim();
    final lower = cleanName.toLowerCase();
    if (lower.isEmpty ||
        lower == 'unknown artist' ||
        lower == 'artist' ||
        lower == 'null' ||
        lower == 'nan' ||
        lower == 'undefined' ||
        lower == '[untitled]' ||
        lower == 'untitled' ||
        lower == 'none' ||
        RegExp(r'^[\?\.\s!@#\$%\^&\*\(\)_\+=\[\]\{\};:,<>\/\\|\-]+$').hasMatch(cleanName)) {
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(cleanName)}&limit=15',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map &&
            data['data'] is List &&
            (data['data'] as List).isNotEmpty) {
          final items = (data['data'] as List).whereType<Map>().toList();
          final cleanLower = cleanName.toLowerCase();

          // 1. Exact name matches (case-insensitive & trimmed), sorted by highest followers
          final exactMatches = items.where((it) {
            final n = it['name']?.toString().trim().toLowerCase();
            return n == cleanLower;
          }).toList();

          final Map item;
          if (exactMatches.isNotEmpty) {
            exactMatches.sort((a, b) {
              final fanA = int.tryParse(a['nb_fan']?.toString() ?? '0') ?? 0;
              final fanB = int.tryParse(b['nb_fan']?.toString() ?? '0') ?? 0;
              return fanB.compareTo(fanA);
            });
            item = exactMatches.first;
          } else {
            // 2. Contains matches, sorted by highest followers
            final containsMatches = items.where((it) {
              final n = it['name']?.toString().trim().toLowerCase() ?? '';
              return n.contains(cleanLower) || cleanLower.contains(n);
            }).toList();

            if (containsMatches.isNotEmpty) {
              containsMatches.sort((a, b) {
                final fanA = int.tryParse(a['nb_fan']?.toString() ?? '0') ?? 0;
                final fanB = int.tryParse(b['nb_fan']?.toString() ?? '0') ?? 0;
                return fanB.compareTo(fanA);
              });
              item = containsMatches.first;
            } else {
              // 3. Fallback: highest fan count among all returned items
              items.sort((a, b) {
                final fanA = int.tryParse(a['nb_fan']?.toString() ?? '0') ?? 0;
                final fanB = int.tryParse(b['nb_fan']?.toString() ?? '0') ?? 0;
                return fanB.compareTo(fanA);
              });
              item = items.first;
            }
          }

          final List<SpotubeImageObject> images = [];
          final xl = item['picture_xl']?.toString();
          final big = item['picture_big']?.toString();
          final med = item['picture_medium']?.toString();
          final small = item['picture_small']?.toString();

          if (xl != null && xl.isNotEmpty) {
            images.add(
              SpotubeImageObject(url: xl, height: 1000, width: 1000),
            );
          }
          if (big != null && big.isNotEmpty && big != xl) {
            images.add(
              SpotubeImageObject(url: big, height: 500, width: 500),
            );
          }
          if (med != null &&
              med.isNotEmpty &&
              med != big &&
              med != xl) {
            images.add(
              SpotubeImageObject(url: med, height: 250, width: 250),
            );
          }
          if (small != null &&
              small.isNotEmpty &&
              small != med) {
            images.add(
              SpotubeImageObject(url: small, height: 56, width: 56),
            );
          }

          int? followers;
          if (item['nb_fan'] != null) {
            followers = int.tryParse(item['nb_fan'].toString());
          }

          if (images.isNotEmpty || (followers != null && followers > 0)) {
            return (images: images, followers: followers);
          }
        }
      }
    } catch (_) {}

    try {
      final wikiQuery = Uri.encodeComponent(cleanName.replaceAll(' ', '_'));
      final res = await wikipedia.pageContent
          .pageSummaryTitleGet(wikiQuery)
          .timeout(const Duration(seconds: 4));
      final source = res?.thumbnail?.source_ ?? res?.originalimage?.source_;
      if (source != null && source.isNotEmpty) {
        final width =
            res?.thumbnail?.width ?? res?.originalimage?.width ?? 300;
        final height =
            res?.thumbnail?.height ?? res?.originalimage?.height ?? 300;
        return (
          images: [
            SpotubeImageObject(url: source, width: width, height: height)
          ],
          followers: null,
        );
      }
    } catch (_) {}

    return null;
  }

  Future<SpotubeFullArtistObject?> _fetchFromHetu(String id) async {
    final cleanId = id.split('::')[0].trim();
    try {
      final raw = await hetuMetadataArtist
          .invoke("getArtist", positionalArgs: [cleanId]);
      if (raw is Map &&
          raw['name'] != null &&
          raw['name'].toString().trim().isNotEmpty &&
          raw['name'].toString().trim() != 'Unknown Artist') {
        return SpotubeFullArtistObject.fromJson(
          raw.cast<String, dynamic>(),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<SpotubeFullArtistObject> getArtist(String id) async {
    String cleanId = id;
    String? embeddedImage;

    if (id.contains('::img:')) {
      final parts = id.split('::img:');
      cleanId = parts[0];
      if (parts.length > 1) {
        final raw = parts[1].split('::')[0];
        if (raw.isNotEmpty) {
          try {
            embeddedImage = Uri.decodeComponent(raw);
          } catch (_) {
            embeddedImage = raw;
          }
        }
      }
    }

    if (cleanId.startsWith('yt-') || cleanId.startsWith('yt:')) {
      final decodedName = Uri.decodeComponent(
        cleanId
            .replaceFirst(RegExp(r'^yt-(artist:|channel:)?'), '')
            .replaceFirst(RegExp(r'^yt:'), ''),
      ).trim();

      if (decodedName.isNotEmpty) {
        final mbId = await _resolveMbId(decodedName);
        if (mbId != null) {
          final realArtist = await _fetchFromHetu(mbId);
          if (realArtist != null &&
              realArtist.name.isNotEmpty &&
              realArtist.name != 'Unknown Artist') {
            final needsImages = realArtist.images.isEmpty;
            final needsFollowers = realArtist.followers == null ||
                realArtist.followers == 0 ||
                realArtist.followers!.toDouble().isInfinite;
            if (!needsImages && !needsFollowers) {
              return realArtist;
            }
            final onlineInfo =
                await _resolveArtistOnlineInfo(realArtist.name);
            final images = <SpotubeImageObject>[
              if (embeddedImage != null && embeddedImage.isNotEmpty)
                SpotubeImageObject(
                  url: embeddedImage,
                  height: 300,
                  width: 300,
                ),
              if (realArtist.images.isNotEmpty)
                ...realArtist.images
              else
                ...?onlineInfo?.images,
            ];
            final followers = (!needsFollowers)
                ? realArtist.followers
                : onlineInfo?.followers;
            return realArtist.copyWith(
              images: images.isNotEmpty ? images : realArtist.images,
              followers: followers,
            );
          }
        }

        final onlineInfo = await _resolveArtistOnlineInfo(decodedName);
        final images = <SpotubeImageObject>[
          if (embeddedImage != null && embeddedImage.isNotEmpty)
            SpotubeImageObject(
              url: embeddedImage,
              height: 300,
              width: 300,
            ),
          ...?onlineInfo?.images,
        ];
        return SpotubeFullArtistObject(
          id: id,
          name: decodedName,
          externalUri:
              'https://musicbrainz.org/search?query=${Uri.encodeComponent(decodedName)}&type=artist',
          images: images,
          genres: const [],
          followers: onlineInfo?.followers,
        );
      }
    }

    final artist = await _fetchFromHetu(cleanId);
    if (artist != null &&
        artist.name.isNotEmpty &&
        artist.name != 'Unknown Artist') {
      final needsImages = artist.images.isEmpty;
      final needsFollowers = artist.followers == null ||
          artist.followers == 0 ||
          artist.followers!.toDouble().isInfinite;
      if (!needsImages && !needsFollowers) {
        return artist;
      }
      final onlineInfo = await _resolveArtistOnlineInfo(artist.name);
      final images = <SpotubeImageObject>[
        if (embeddedImage != null && embeddedImage.isNotEmpty)
          SpotubeImageObject(
            url: embeddedImage,
            height: 300,
            width: 300,
          ),
        if (artist.images.isNotEmpty)
          ...artist.images
        else
          ...?onlineInfo?.images,
      ];
      final followers = (!needsFollowers)
          ? artist.followers
          : onlineInfo?.followers;
      return artist.copyWith(
        images: images.isNotEmpty ? images : artist.images,
        followers: followers,
      );
    }

    final fallbackInfo = cleanId.isNotEmpty && !cleanId.startsWith('yt-')
        ? null
        : await _resolveArtistOnlineInfo(cleanId);
    return SpotubeFullArtistObject(
      id: id,
      name: 'Artist',
      externalUri: 'https://musicbrainz.org/artist/$cleanId',
      images: [
        if (embeddedImage != null && embeddedImage.isNotEmpty)
          SpotubeImageObject(
            url: embeddedImage,
            height: 300,
            width: 300,
          ),
        ...?fallbackInfo?.images,
      ],
      genres: const [],
    );
  }

  Future<SpotubePaginationResponseObject<SpotubeFullTrackObject>> topTracks(
    String id, {
    int? offset,
    int? limit,
  }) async {
    String queryId = id.split('::')[0].trim();
    if (queryId.startsWith('yt-') || queryId.startsWith('yt:')) {
      final decodedName = Uri.decodeComponent(
        queryId
            .replaceFirst(RegExp(r'^yt-(artist:|channel:)?'), '')
            .replaceFirst(RegExp(r'^yt:'), ''),
      ).trim();
      if (decodedName.isNotEmpty) {
        final mbId = await _resolveMbId(decodedName);
        if (mbId != null) queryId = mbId;
      }
    }

    try {
      final raw = await hetuMetadataArtist.invoke(
        "topTracks",
        positionalArgs: [queryId],
        namedArgs: {
          "offset": offset,
          "limit": limit,
        }..removeWhere((key, value) => value == null),
      );
      if (raw is Map) {
        return SpotubePaginationResponseObject<SpotubeFullTrackObject>.fromJson(
          raw.cast<String, dynamic>(),
          (Map json) => SpotubeFullTrackObject.fromJson(
            json.cast<String, dynamic>(),
          ),
        );
      }
    } catch (_) {}

    return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
      items: [],
      total: 0,
      limit: limit ?? 20,
      hasMore: false,
      nextOffset: null,
    );
  }

  Future<SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>> albums(
    String id, {
    int? offset,
    int? limit,
  }) async {
    String queryId = id.split('::')[0].trim();
    if (queryId.startsWith('yt-') || queryId.startsWith('yt:')) {
      final decodedName = Uri.decodeComponent(
        queryId
            .replaceFirst(RegExp(r'^yt-(artist:|channel:)?'), '')
            .replaceFirst(RegExp(r'^yt:'), ''),
      ).trim();
      if (decodedName.isNotEmpty) {
        final mbId = await _resolveMbId(decodedName);
        if (mbId != null) queryId = mbId;
      }
    }

    try {
      final raw = await hetuMetadataArtist.invoke(
        "albums",
        positionalArgs: [queryId],
        namedArgs: {
          "offset": offset,
          "limit": limit,
        }..removeWhere((key, value) => value == null),
      );
      if (raw is Map) {
        return SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>.fromJson(
          raw.cast<String, dynamic>(),
          (Map json) => SpotubeSimpleAlbumObject.fromJson(
            json.cast<String, dynamic>(),
          ),
        );
      }
    } catch (_) {}

    return SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>(
      items: [],
      total: 0,
      limit: limit ?? 20,
      hasMore: false,
      nextOffset: null,
    );
  }

  Future<void> save(List<String> ids) async {
    final cleanIds = ids.map((e) => e.split('::')[0].trim()).toList();
    try {
      await hetuMetadataArtist.invoke(
        "save",
        positionalArgs: [cleanIds],
      );
    } catch (_) {}
  }

  Future<void> unsave(List<String> ids) async {
    final cleanIds = ids.map((e) => e.split('::')[0].trim()).toList();
    try {
      await hetuMetadataArtist.invoke(
        "unsave",
        positionalArgs: [cleanIds],
      );
    } catch (_) {}
  }

  Future<SpotubePaginationResponseObject<SpotubeFullArtistObject>> related(
    String id, {
    int? offset,
    int? limit,
  }) async {
    String queryId = id.split('::')[0].trim();
    if (queryId.startsWith('yt-') || queryId.startsWith('yt:')) {
      final decodedName = Uri.decodeComponent(
        queryId
            .replaceFirst(RegExp(r'^yt-(artist:|channel:)?'), '')
            .replaceFirst(RegExp(r'^yt:'), ''),
      ).trim();
      if (decodedName.isNotEmpty) {
        final mbId = await _resolveMbId(decodedName);
        if (mbId != null) queryId = mbId;
      }
    }

    try {
      final raw = await hetuMetadataArtist.invoke(
        "related",
        positionalArgs: [queryId],
        namedArgs: {
          "offset": offset,
          "limit": limit ?? 20,
        }..removeWhere((key, value) => value == null),
      );
      if (raw is Map) {
        return SpotubePaginationResponseObject<SpotubeFullArtistObject>.fromJson(
          raw.cast<String, dynamic>(),
          (Map json) => SpotubeFullArtistObject.fromJson(
            json.cast<String, dynamic>(),
          ),
        );
      }
    } catch (_) {}

    return SpotubePaginationResponseObject<SpotubeFullArtistObject>(
      items: [],
      total: 0,
      limit: limit ?? 20,
      hasMore: false,
      nextOffset: null,
    );
  }
}
