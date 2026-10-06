import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:spotube/services/metadata/metadata.dart';
import 'package:spotube/services/youtube_engine/youtube_engine.dart';
import 'package:spotube/services/youtube_engine/youtube_search_service.dart';

class MetadataUrlResolver {
  static final _mbReleaseGroupRegex = RegExp(
    r'musicbrainz\.org/release-group/([a-f0-9-]{36})',
    caseSensitive: false,
  );
  static final _mbReleaseRegex = RegExp(
    r'musicbrainz\.org/release/([a-f0-9-]{36})',
    caseSensitive: false,
  );
  static final _mbRecordingRegex = RegExp(
    r'musicbrainz\.org/recording/([a-f0-9-]{36})',
    caseSensitive: false,
  );
  static final _mbArtistRegex = RegExp(
    r'musicbrainz\.org/artist/([a-f0-9-]{36})',
    caseSensitive: false,
  );
  static final _uuidRegex = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
    caseSensitive: false,
  );
  static final _youtubeRegex = RegExp(
    r'(?:youtube\.com\/(?:watch\?v=|shorts\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );

  static bool isRecognizedUrlOrId(String query) {
    final trimmed = query.trim();
    return _mbReleaseGroupRegex.hasMatch(trimmed) ||
        _mbReleaseRegex.hasMatch(trimmed) ||
        _mbRecordingRegex.hasMatch(trimmed) ||
        _mbArtistRegex.hasMatch(trimmed) ||
        _uuidRegex.hasMatch(trimmed) ||
        _youtubeRegex.hasMatch(trimmed);
  }

  static Future<SpotubeSearchResponseObject?> resolveUrlSearch({
    required String query,
    required MetadataPlugin metadataPlugin,
    required YouTubeEngine youtubeEngine,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    // 1. MusicBrainz Release Group (Album)
    final mbReleaseGroupMatch = _mbReleaseGroupRegex.firstMatch(trimmed);
    if (mbReleaseGroupMatch != null) {
      final id = mbReleaseGroupMatch.group(1)!;
      return await _resolveMbAlbum(id, metadataPlugin, youtubeEngine);
    }

    // 2. MusicBrainz Recording (Track)
    final mbRecordingMatch = _mbRecordingRegex.firstMatch(trimmed);
    if (mbRecordingMatch != null) {
      final id = mbRecordingMatch.group(1)!;
      return await _resolveMbTrack(id, metadataPlugin, youtubeEngine);
    }

    // 3. MusicBrainz Artist
    final mbArtistMatch = _mbArtistRegex.firstMatch(trimmed);
    if (mbArtistMatch != null) {
      final id = mbArtistMatch.group(1)!;
      return await _resolveMbArtist(id, metadataPlugin);
    }

    // 4. MusicBrainz Release
    final mbReleaseMatch = _mbReleaseRegex.firstMatch(trimmed);
    if (mbReleaseMatch != null) {
      final id = mbReleaseMatch.group(1)!;
      return await _resolveMbAlbum(id, metadataPlugin, youtubeEngine);
    }

    // 5. Bare UUID (could be release-group, recording, or artist)
    if (_uuidRegex.hasMatch(trimmed)) {
      final resAlbum =
          await _resolveMbAlbum(trimmed, metadataPlugin, youtubeEngine);
      if (resAlbum != null && resAlbum.albums.isNotEmpty) return resAlbum;

      final resTrack =
          await _resolveMbTrack(trimmed, metadataPlugin, youtubeEngine);
      if (resTrack != null && resTrack.tracks.isNotEmpty) return resTrack;

      final resArtist = await _resolveMbArtist(trimmed, metadataPlugin);
      if (resArtist != null && resArtist.artists.isNotEmpty) return resArtist;
    }

    // 6. YouTube Video URL
    final ytMatch = _youtubeRegex.firstMatch(trimmed);
    if (ytMatch != null) {
      final videoId = ytMatch.group(1)!;
      try {
        final video = await youtubeEngine.getVideo(videoId);
        final track = YouTubeSearchService.videoToSpotubeTrack(video);
        return SpotubeSearchResponseObject(
          albums: [track.album],
          artists: track.artists
              .map((a) => SpotubeFullArtistObject(
                    id: a.id,
                    name: a.name,
                    externalUri: a.externalUri,
                    genres: [],
                    images: a.images ?? [],
                    followers: 0,
                  ))
              .toList(),
          playlists: [],
          tracks: [track],
        );
      } catch (e, s) {
        AppLogger.reportError(e, s);
      }
    }

    return null;
  }

  static Future<SpotubeSimpleAlbumObject?> resolveAlbumSearch({
    required String query,
    required MetadataPlugin metadataPlugin,
  }) async {
    final trimmed = query.trim();
    String? albumId;

    final match = _mbReleaseGroupRegex.firstMatch(trimmed) ??
        _mbReleaseRegex.firstMatch(trimmed);
    if (match != null) {
      albumId = match.group(1);
    } else if (_uuidRegex.hasMatch(trimmed)) {
      albumId = trimmed;
    }

    if (albumId == null) return null;

    try {
      final album = await metadataPlugin.album.getAlbum(albumId);
      return SpotubeSimpleAlbumObject(
        id: album.id,
        name: album.name,
        artists: album.artists,
        images: album.images,
        albumType: album.albumType,
        externalUri: album.externalUri,
        releaseDate: album.releaseDate,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<SpotubeFullTrackObject>?> resolveTracksSearch({
    required String query,
    required MetadataPlugin metadataPlugin,
    required YouTubeEngine youtubeEngine,
  }) async {
    final res = await resolveUrlSearch(
      query: query,
      metadataPlugin: metadataPlugin,
      youtubeEngine: youtubeEngine,
    );
    return res?.tracks;
  }

  static Future<SpotubeSearchResponseObject?> _resolveMbAlbum(
    String id,
    MetadataPlugin metadataPlugin,
    YouTubeEngine youtubeEngine,
  ) async {
    try {
      final album = await metadataPlugin.album.getAlbum(id);
      final simpleAlbum = SpotubeSimpleAlbumObject(
        id: album.id,
        name: album.name,
        artists: album.artists,
        images: album.images,
        albumType: album.albumType,
        externalUri: album.externalUri,
        releaseDate: album.releaseDate,
      );

      List<SpotubeFullTrackObject> albumTracks = [];
      try {
        final tracksRes = await metadataPlugin.album.tracks(id);
        albumTracks = tracksRes.items;
      } catch (_) {}

      final artistName = album.artists.firstOrNull?.name ?? '';
      final ytTracks = await YouTubeSearchService.search(
        "${album.name} $artistName",
        youtubeEngine,
        limit: 10,
      );

      final mergedTracks = <SpotubeFullTrackObject>[];
      final seen = <String>{};

      for (final track in [...albumTracks, ...ytTracks]) {
        final key =
            "${track.name.toLowerCase()} - ${track.artists.firstOrNull?.name.toLowerCase()}";
        if (!seen.contains(key)) {
          seen.add(key);
          mergedTracks.add(track);
        }
      }

      return SpotubeSearchResponseObject(
        albums: [simpleAlbum],
        tracks: mergedTracks,
        artists: album.artists
            .map((a) => SpotubeFullArtistObject(
                  id: a.id,
                  name: a.name,
                  externalUri: a.externalUri,
                  genres: [],
                  images: a.images ?? [],
                  followers: 0,
                ))
            .toList(),
        playlists: [],
      );
    } catch (e, s) {
      AppLogger.reportError(e, s);
      return null;
    }
  }

  static Future<SpotubeSearchResponseObject?> _resolveMbTrack(
    String id,
    MetadataPlugin metadataPlugin,
    YouTubeEngine youtubeEngine,
  ) async {
    try {
      final track = await metadataPlugin.track.getTrack(id);
      final artistName = track.artists.firstOrNull?.name ?? '';
      final ytTracks = await YouTubeSearchService.search(
        "${track.name} $artistName",
        youtubeEngine,
        limit: 10,
      );

      final mergedTracks = <SpotubeFullTrackObject>[];
      final seen = <String>{};

      for (final t in [track, ...ytTracks]) {
        final key =
            "${t.name.toLowerCase()} - ${t.artists.firstOrNull?.name.toLowerCase()}";
        if (!seen.contains(key)) {
          seen.add(key);
          mergedTracks.add(t);
        }
      }

      return SpotubeSearchResponseObject(
        albums: [track.album],
        tracks: mergedTracks,
        artists: track.artists
            .map((a) => SpotubeFullArtistObject(
                  id: a.id,
                  name: a.name,
                  externalUri: a.externalUri,
                  genres: [],
                  images: a.images ?? [],
                  followers: 0,
                ))
            .toList(),
        playlists: [],
      );
    } catch (e, s) {
      AppLogger.reportError(e, s);
      return null;
    }
  }

  static Future<SpotubeSearchResponseObject?> _resolveMbArtist(
    String id,
    MetadataPlugin metadataPlugin,
  ) async {
    try {
      final artist = await metadataPlugin.artist.getArtist(id);
      return SpotubeSearchResponseObject(
        albums: [],
        tracks: [],
        artists: [artist],
        playlists: [],
      );
    } catch (e, s) {
      AppLogger.reportError(e, s);
      return null;
    }
  }
}
