import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/youtube_engine/youtube_engine.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:spotube/services/metadata/errors/exceptions.dart';
import 'package:spotube/services/metadata/metadata_url_resolver.dart';
import 'package:spotube/services/youtube_engine/youtube_search_service.dart';

final metadataPluginSearchAllProvider =
    FutureProvider.autoDispose.family<SpotubeSearchResponseObject, String>(
  (ref, query) async {
    final metadataPlugin = await ref.watch(metadataPluginProvider.future);
    final youtubeEngine = ref.watch(youtubeEngineProvider);

    if (metadataPlugin == null) {
      throw MetadataPluginException.noDefaultMetadataPlugin();
    }

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return SpotubeSearchResponseObject(
        albums: [],
        artists: [],
        playlists: [],
        tracks: [],
      );
    }

    if (MetadataUrlResolver.isRecognizedUrlOrId(trimmed)) {
      final resolved = await MetadataUrlResolver.resolveUrlSearch(
        query: trimmed,
        metadataPlugin: metadataPlugin,
        youtubeEngine: youtubeEngine,
      );
      if (resolved != null &&
          (resolved.albums.isNotEmpty ||
              resolved.tracks.isNotEmpty ||
              resolved.artists.isNotEmpty)) {
        return resolved;
      }
    }

    final results = await Future.wait([
      metadataPlugin.search.all(trimmed).catchError((e, stack) {
        AppLogger.reportError(e, stack);
        return SpotubeSearchResponseObject(
          albums: [],
          artists: [],
          playlists: [],
          tracks: [],
        );
      }),
      YouTubeSearchService.search(trimmed, youtubeEngine, limit: 12),
    ]);

    final pluginResults = results[0] as SpotubeSearchResponseObject;
    final ytTracks = results[1] as List<SpotubeFullTrackObject>;

    final mergedTracks = <SpotubeFullTrackObject>[];
    final seen = <String>{};

    for (final track in [...ytTracks, ...pluginResults.tracks]) {
      final key =
          "${track.name.toLowerCase()} - ${track.artists.firstOrNull?.name.toLowerCase()}";
      if (!seen.contains(key)) {
        seen.add(key);
        mergedTracks.add(track);
      }
    }

    return pluginResults.copyWith(tracks: mergedTracks);
  },
);

final metadataPluginSearchChipsProvider = FutureProvider((ref) async {
  final metadataPlugin = await ref.watch(metadataPluginProvider.future);

  if (metadataPlugin == null) {
    throw MetadataPluginException.noDefaultMetadataPlugin();
  }
  return metadataPlugin.search.chips;
});
