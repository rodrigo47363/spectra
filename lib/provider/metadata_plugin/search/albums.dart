import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/metadata_plugin/utils/common.dart';
import 'package:spotube/provider/metadata_plugin/utils/family_paginated.dart';

import 'package:spotube/services/metadata/metadata_url_resolver.dart';

class MetadataPluginSearchAlbumsNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SpotubeSimpleAlbumObject,
        String> {
  MetadataPluginSearchAlbumsNotifier() : super();

  @override
  fetch(offset, limit) async {
    final trimmed = arg.trim();
    if (trimmed.isEmpty) {
      return SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>(
        limit: limit,
        nextOffset: null,
        total: 0,
        items: [],
        hasMore: false,
      );
    }

    final resolved = await MetadataUrlResolver.resolveAlbumSearch(
      query: trimmed,
      metadataPlugin: await metadataPlugin,
    );
    if (resolved != null) {
      return SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>(
        limit: limit,
        nextOffset: null,
        total: 1,
        items: [resolved],
        hasMore: false,
      );
    }

    final res = await (await metadataPlugin).search.albums(
          trimmed,
          offset: offset,
          limit: limit,
        );

    return res;
  }

  @override
  build(arg) async {
    ref.cacheFor();

    ref.watch(metadataPluginProvider);
    return await fetch(0, 20);
  }
}

final metadataPluginSearchAlbumsProvider =
    AutoDisposeAsyncNotifierProviderFamily<MetadataPluginSearchAlbumsNotifier,
        SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>, String>(
  () => MetadataPluginSearchAlbumsNotifier(),
);
