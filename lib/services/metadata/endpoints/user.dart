import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:spotube/models/metadata/metadata.dart';

class MetadataPluginUserEndpoint {
  final Hetu hetu;
  MetadataPluginUserEndpoint(this.hetu);

  HTInstance get hetuMetadataUser =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("user")
          as HTInstance;

  Future<SpotubeUserObject> me() async {
    try {
      final raw = await hetuMetadataUser.invoke("me") as Map;

      return SpotubeUserObject.fromJson(
        raw.cast<String, dynamic>(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<SpotubePaginationResponseObject<SpotubeFullTrackObject>> savedTracks({
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataUser.invoke(
        "savedTracks",
        namedArgs: {
          "offset": offset,
          "limit": limit,
        }..removeWhere((key, value) => value == null),
      ) as Map;

      return SpotubePaginationResponseObject<SpotubeFullTrackObject>.fromJson(
        raw.cast<String, dynamic>(),
        (Map json) =>
            SpotubeFullTrackObject.fromJson(json.cast<String, dynamic>()),
      );
    } catch (e) {
      return SpotubePaginationResponseObject(
        items: [],
        hasMore: false,
        limit: 20,
        nextOffset: null,
        total: 0,
      );
    }
  }

  Future<SpotubePaginationResponseObject<SpotubeSimplePlaylistObject>>
      savedPlaylists({
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataUser.invoke(
        "savedPlaylists",
        namedArgs: {
          "offset": offset,
          "limit": limit,
        }..removeWhere((key, value) => value == null),
      ) as Map;

      return SpotubePaginationResponseObject<
          SpotubeSimplePlaylistObject>.fromJson(
        raw.cast<String, dynamic>(),
        (Map json) =>
            SpotubeSimplePlaylistObject.fromJson(json.cast<String, dynamic>()),
      );
    } catch (e) {
      return SpotubePaginationResponseObject(
        items: [],
        hasMore: false,
        limit: 20,
        nextOffset: null,
        total: 0,
      );
    }
  }

  Future<SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>>
      savedAlbums({
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataUser.invoke(
        "savedAlbums",
        namedArgs: {
          "offset": offset,
          "limit": limit,
        }..removeWhere((key, value) => value == null),
      ) as Map;

      return SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>.fromJson(
        raw.cast<String, dynamic>(),
        (Map json) =>
            SpotubeSimpleAlbumObject.fromJson(json.cast<String, dynamic>()),
      );
    } catch (e) {
      return SpotubePaginationResponseObject(
        items: [],
        hasMore: false,
        limit: 20,
        nextOffset: null,
        total: 0,
      );
    }
  }

  Future<SpotubePaginationResponseObject<SpotubeFullArtistObject>>
      savedArtists({
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataUser.invoke(
        "savedArtists",
        namedArgs: {
          "offset": offset,
          "limit": limit,
        }..removeWhere((key, value) => value == null),
      ) as Map;

      return SpotubePaginationResponseObject<SpotubeFullArtistObject>.fromJson(
        raw.cast<String, dynamic>(),
        (Map json) =>
            SpotubeFullArtistObject.fromJson(json.cast<String, dynamic>()),
      );
    } catch (e) {
      return SpotubePaginationResponseObject(
        items: [],
        hasMore: false,
        limit: 20,
        nextOffset: null,
        total: 0,
      );
    }
  }

  Future<bool> isSavedPlaylist(String playlistId) async {
    try {
      return await hetuMetadataUser.invoke(
        "isSavedPlaylist",
        positionalArgs: [playlistId],
      ) as bool;
    } catch (e) {
      return false;
    }
  }

  Future<List<bool>> isSavedTracks(List<String> ids) async {
    try {
      final values = await hetuMetadataUser.invoke(
        "isSavedTracks",
        positionalArgs: [ids],
      );
      return (values as List).cast<bool>();
    } catch (e) {
      return List.filled(ids.length, false);
    }
  }

  Future<List<bool>> isSavedAlbums(List<String> ids) async {
    try {
      final values = await hetuMetadataUser.invoke(
        "isSavedAlbums",
        positionalArgs: [ids],
      ) as List;
      return values.cast<bool>();
    } catch (e) {
      return List.filled(ids.length, false);
    }
  }

  Future<List<bool>> isSavedArtists(List<String> ids) async {
    try {
      final values = await hetuMetadataUser.invoke(
        "isSavedArtists",
        positionalArgs: [ids],
      ) as List;

      return values.cast<bool>();
    } catch (e) {
      return List.filled(ids.length, false);
    }
  }
}
