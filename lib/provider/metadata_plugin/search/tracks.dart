import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/metadata_plugin/utils/common.dart';
import 'package:spotube/provider/metadata_plugin/utils/family_paginated.dart';
import 'package:spotube/provider/youtube_engine/youtube_engine.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:spotube/services/metadata/metadata_url_resolver.dart';
import 'package:spotube/services/youtube_engine/youtube_search_service.dart';

class MetadataPluginSearchTracksNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SpotubeFullTrackObject,
        String> {
  MetadataPluginSearchTracksNotifier() : super();

  @override
  fetch(offset, limit) async {
    final trimmed = arg.trim();
    if (trimmed.isEmpty) {
      return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
        limit: limit,
        nextOffset: null,
        total: 0,
        items: [],
        hasMore: false,
      );
    }

    if (offset == 0 && MetadataUrlResolver.isRecognizedUrlOrId(trimmed)) {
      final youtubeEngine = ref.read(youtubeEngineProvider);
      final resolved = await MetadataUrlResolver.resolveTracksSearch(
        query: trimmed,
        metadataPlugin: await metadataPlugin,
        youtubeEngine: youtubeEngine,
      );
      if (resolved != null && resolved.isNotEmpty) {
        return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
          limit: limit,
          nextOffset: null,
          total: resolved.length,
          items: resolved,
          hasMore: false,
        );
      }
    }

    if (offset == 0) {
      final youtubeEngine = ref.read(youtubeEngineProvider);
      final results = await Future.wait([
        (await metadataPlugin).search.tracks(
          trimmed,
          offset: offset,
          limit: limit,
        ).catchError((e, stack) {
          AppLogger.reportError(e, stack);
          return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
            limit: limit,
            nextOffset: null,
            total: 0,
            items: [],
            hasMore: false,
          );
        }),
        YouTubeSearchService.search(trimmed, youtubeEngine, limit: 15),
      ]);

      final pluginTracks =
          results[0] as SpotubePaginationResponseObject<SpotubeFullTrackObject>;
      final ytTracks = results[1] as List<SpotubeFullTrackObject>;

      final merged = <SpotubeFullTrackObject>[];
      final seen = <String>{};

      for (final track in [...ytTracks, ...pluginTracks.items]) {
        final key =
            "${track.name.toLowerCase()} - ${track.artists.firstOrNull?.name.toLowerCase()}";
        if (!seen.contains(key)) {
          seen.add(key);
          merged.add(track);
        }
      }

      return pluginTracks.copyWith(
        items: merged,
        total: pluginTracks.total + ytTracks.length,
      );
    }

    final tracks = await (await metadataPlugin).search.tracks(
          trimmed,
          offset: offset,
          limit: limit,
        );

    return tracks;
  }

  @override
  build(arg) async {
    ref.cacheFor();

    ref.watch(metadataPluginProvider);
    ref.watch(youtubeEngineProvider);
    return await fetch(0, 20);
  }
}

final metadataPluginSearchTracksProvider =
    AutoDisposeAsyncNotifierProviderFamily<MetadataPluginSearchTracksNotifier,
        SpotubePaginationResponseObject<SpotubeFullTrackObject>, String>(
  () => MetadataPluginSearchTracksNotifier(),
);
