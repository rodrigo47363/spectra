import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/logger/logger.dart';

class MetadataPluginBrowseEndpoint {
  final Hetu hetu;
  MetadataPluginBrowseEndpoint(this.hetu);

  HTInstance get hetuMetadataBrowse =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("browse")
          as HTInstance;

  Future<SpotubePaginationResponseObject<SpotubeBrowseSectionObject<Object>>>
      sections({
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = (await hetuMetadataBrowse.invoke(
        "sections",
        namedArgs: {
          "offset": offset,
          "limit": limit,
        }..removeWhere((key, value) => value == null),
      ).timeout(const Duration(seconds: 15))) as Map?;

      if (raw == null) {
        return SpotubePaginationResponseObject(
          limit: limit ?? 20,
          nextOffset: null,
          total: 0,
          hasMore: false,
          items: [],
        );
      }

      return SpotubePaginationResponseObject<
          SpotubeBrowseSectionObject<Object>>.fromJson(
        raw.cast<String, dynamic>(),
        (Map json) => SpotubeBrowseSectionObject<Object>.fromJson(
          json.cast<String, dynamic>(),
          (json) {
            final isPlaylist = json["owner"] != null;
            final isAlbum = json["artists"] != null;
            if (isPlaylist) {
              return SpotubeSimplePlaylistObject.fromJson(
                json.cast<String, dynamic>(),
              );
            } else if (isAlbum) {
              return SpotubeSimpleAlbumObject.fromJson(
                json.cast<String, dynamic>(),
              );
            } else {
              return SpotubeFullArtistObject.fromJson(
                json.cast<String, dynamic>(),
              );
            }
          },
        ),
      );
    } catch (e) {
      AppLogger.log.w("Metadata browse sections unavailable: $e");
      return SpotubePaginationResponseObject(
        limit: limit ?? 20,
        nextOffset: null,
        total: 0,
        hasMore: false,
        items: [],
      );
    }
  }

  Future<SpotubePaginationResponseObject<Object>> sectionItems(
    String id, {
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = (await hetuMetadataBrowse.invoke(
        "sectionItems",
        positionalArgs: [id],
        namedArgs: {
          "offset": offset,
          "limit": limit,
        }..removeWhere((key, value) => value == null),
      ).timeout(const Duration(seconds: 15))) as Map?;

      if (raw == null) {
        return SpotubePaginationResponseObject(
          limit: limit ?? 20,
          nextOffset: null,
          total: 0,
          hasMore: false,
          items: [],
        );
      }

      return SpotubePaginationResponseObject<Object>.fromJson(
        raw.cast<String, dynamic>(),
        (json) {
          final isPlaylist = json["owner"] != null;
          final isAlbum = json["artists"] != null;
          if (isPlaylist) {
            return SpotubeSimplePlaylistObject.fromJson(
              json.cast<String, dynamic>(),
            );
          } else if (isAlbum) {
            return SpotubeSimpleAlbumObject.fromJson(
              json.cast<String, dynamic>(),
            );
          } else {
            return SpotubeFullArtistObject.fromJson(
              json.cast<String, dynamic>(),
            );
          }
        },
      );
    } catch (e) {
      AppLogger.log.w("Metadata browse sectionItems unavailable: $e");
      return SpotubePaginationResponseObject(
        limit: limit ?? 20,
        nextOffset: null,
        total: 0,
        hasMore: false,
        items: [],
      );
    }
  }
}

