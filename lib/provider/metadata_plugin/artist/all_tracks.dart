import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/metadata_plugin/artist/albums.dart';
import 'package:spotube/provider/metadata_plugin/artist/artist.dart';
import 'package:spotube/provider/metadata_plugin/artist/top_tracks.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/metadata_plugin/utils/common.dart';

final metadataPluginArtistAllTracksProvider = FutureProvider.autoDispose
    .family<List<SpotubeFullTrackObject>, String>((ref, artistId) async {
  ref.cacheFor();
  ref.watch(metadataPluginProvider);

  final List<SpotubeFullTrackObject> collectedTracks = [];
  final Set<String> trackIds = {};
  final Set<String> normalizedTitles = {};

  // 1. Obtener Top Tracks (que ya vienen enriquecidas con las más populares)
  try {
    final top =
        await ref.watch(metadataPluginArtistTopTracksProvider(artistId).future);
    for (final track in top.items) {
      final norm = track.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (trackIds.add(track.id)) {
        if (norm.isNotEmpty) normalizedTitles.add(norm);
        collectedTracks.add(track);
      }
    }
  } catch (_) {}

  final plugin = await ref.watch(metadataPluginProvider.future);
  if (plugin == null) {
    return collectedTracks;
  }

  // 2. Obtener catálogo online completo de canciones del artista (hasta 100 tracks)
  String? artistName;
  try {
    final artist =
        await ref.watch(metadataPluginArtistProvider(artistId).future);
    if (artist.name.isNotEmpty &&
        artist.name != 'Artist' &&
        artist.name != 'Unknown Artist') {
      artistName = artist.name;
    }
  } catch (_) {}

  if (artistName != null && artistName.isNotEmpty) {
    try {
      final onlineCatalog = await plugin.artist.resolveArtistOnlineTracks(
        artistName,
        limit: 100,
      );
      for (final track in onlineCatalog) {
        final norm = track.name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
        if ((norm.isEmpty || !normalizedTitles.contains(norm)) &&
            trackIds.add(track.id)) {
          if (norm.isNotEmpty) normalizedTitles.add(norm);
          collectedTracks.add(track);
        }
      }
    } catch (_) {}
  }

  // 3. Extraer pistas de álbumes del artista disponibles
  SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>? albumsResponse;
  try {
    albumsResponse =
        await ref.watch(metadataPluginArtistAlbumsProvider(artistId).future);
  } catch (_) {}

  final albums = albumsResponse?.items ?? [];
  for (final album in albums.take(10)) {
    try {
      final albumTracks = await plugin.album.tracks(album.id);
      for (final track in albumTracks.items) {
        final norm = track.name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
        if ((norm.isEmpty || !normalizedTitles.contains(norm)) &&
            trackIds.add(track.id)) {
          if (norm.isNotEmpty) normalizedTitles.add(norm);
          final trackWithAlbum = (track.album.images.isEmpty &&
                  album.images.isNotEmpty)
              ? track.copyWith(
                  album: track.album.copyWith(images: album.images),
                )
              : track;
          collectedTracks.add(trackWithAlbum);
        }
      }
    } catch (_) {}
  }

  return collectedTracks;
});
