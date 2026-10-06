import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotube/models/database/database.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/models/playback/track_sources.dart';
import 'package:spotube/provider/database/database.dart';
import 'package:spotube/provider/metadata_plugin/audio_source/quality_presets.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/youtube_engine/youtube_engine.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:spotube/services/metadata/metadata.dart';

import 'package:spotube/services/sourced_track/exceptions.dart';
import 'package:spotube/utils/service_utils.dart';

final officialMusicRegex = RegExp(
  r"official\s(video|audio|music\svideo|lyric\svideo|visualizer)",
  caseSensitive: false,
);

class SourcedTrack extends BasicSourcedTrack {
  final Ref ref;

  SourcedTrack({
    required this.ref,
    required super.info,
    required super.query,
    required super.source,
    required super.siblings,
    required super.sources,
  });

  static Future<List<SpotubeAudioSourceStreamObject>> _fetchStreams({
    required SpotubeAudioSourceMatchObject match,
    required Ref ref,
    MetadataPlugin? audioSource,
  }) async {
    if (audioSource != null) {
      try {
        final manifest = await audioSource.audioSource.streams(match);
        if (manifest.isNotEmpty) return manifest;
      } catch (e) {
        AppLogger.log.w("Audio source plugin stream fetch failed: $e");
      }
    }

    try {
      final ytEngine = ref.read(youtubeEngineProvider);
      final manifest = await ytEngine.getStreamManifest(match.id);
      return manifest.audioOnly
          .map(
            (stream) => SpotubeAudioSourceStreamObject(
              url: stream.url.toString(),
              container: stream.container.name,
              type: SpotubeMediaCompressionType.lossy,
              codec: stream.audioCodec,
              bitrate: stream.bitrate.bitsPerSecond.toDouble(),
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.log.w("YouTube engine stream fallback failed: $e");
    }

    return [];
  }

  static Future<SourcedTrack> fetchFromTrack({
    required SpotubeFullTrackObject query,
    required Ref ref,
  }) async {
    final audioSource = await ref.read(audioSourcePluginProvider.future);
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));
    final sourceSlug = audioSourceConfig?.slug ?? "youtube-audio";

    final database = ref.read(databaseProvider);
    final cachedSource = await (database.select(database.sourceMatchTable)
          ..where((s) =>
              s.trackId.equals(query.id) &
              s.sourceType.equals(sourceSlug))
          ..limit(1)
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ]))
        .get()
        .then((s) => s.firstOrNull);

    if (cachedSource == null) {
      final siblings = await fetchSiblings(ref: ref, query: query);
      if (siblings.isEmpty) {
        throw TrackNotFoundError(query);
      }

      await database.into(database.sourceMatchTable).insert(
            SourceMatchTableCompanion.insert(
              trackId: query.id,
              sourceInfo: Value(jsonEncode(siblings.first)),
              sourceType: sourceSlug,
            ),
          );

      final manifest = await _fetchStreams(
        match: siblings.first,
        ref: ref,
        audioSource: audioSource,
      );

      return SourcedTrack(
        ref: ref,
        siblings: siblings.skip(1).toList(),
        info: siblings.first,
        source: sourceSlug,
        sources: manifest,
        query: query,
      );
    }
    final item = SpotubeAudioSourceMatchObject.fromJson(
      jsonDecode(cachedSource.sourceInfo),
    );
    final manifest = await _fetchStreams(
      match: item,
      ref: ref,
      audioSource: audioSource,
    );

    final sourcedTrack = SourcedTrack(
      ref: ref,
      siblings: [],
      sources: manifest,
      info: item,
      query: query,
      source: sourceSlug,
    );

    AppLogger.log.i("${query.name}: ${sourcedTrack.url}");

    return sourcedTrack;
  }

  static List<SpotubeAudioSourceMatchObject> rankResults(
    List<SpotubeAudioSourceMatchObject> results,
    SpotubeFullTrackObject track,
  ) {
    return results
        .map((sibling) {
          int score = 0;

          for (final artist in track.artists) {
            final isSameChannelArtist =
                sibling.artists.any((a) => a.toLowerCase() == artist.name);

            if (isSameChannelArtist) {
              score += 1;
            }

            final titleContainsArtist =
                sibling.title.toLowerCase().contains(artist.name.toLowerCase());

            if (titleContainsArtist) {
              score += 1;
            }
          }

          final titleContainsTrackName =
              sibling.title.toLowerCase().contains(track.name.toLowerCase());

          final hasOfficialFlag =
              officialMusicRegex.hasMatch(sibling.title.toLowerCase());

          if (titleContainsTrackName) {
            score += 3;
          }

          if (hasOfficialFlag) {
            score += 1;
          }

          if (hasOfficialFlag && titleContainsTrackName) {
            score += 2;
          }

          return (sibling: sibling, score: score);
        })
        .sorted((a, b) => b.score.compareTo(a.score))
        .map((e) => e.sibling)
        .toList();
  }

  static Future<List<SpotubeAudioSourceMatchObject>> fetchSiblings({
    required SpotubeFullTrackObject query,
    required Ref ref,
  }) async {
    if (query.id.startsWith("yt:") || query.id.startsWith("youtube:")) {
      final ytId = query.id.replaceFirst(RegExp(r"^(yt:|youtube:)"), "");
      final directMatch = SpotubeAudioSourceMatchObject(
        id: ytId,
        title: query.name,
        artists: query.artists.map((a) => a.name).toList(),
        duration: Duration(milliseconds: query.durationMs),
        thumbnail: query.album.images.firstOrNull?.url,
        externalUri: "https://youtube.com/watch?v=$ytId",
      );
      return [directMatch];
    }

    final videoResults = <SpotubeAudioSourceMatchObject>[];

    try {
      final audioSource = await ref.read(audioSourcePluginProvider.future);
      if (audioSource != null) {
        final searchResults = await audioSource.audioSource.matches(query);
        if (ServiceUtils.onlyContainsEnglish(query.name)) {
          videoResults.addAll(searchResults);
        } else {
          videoResults.addAll(rankResults(searchResults, query));
        }
      }
    } catch (e) {
      AppLogger.log.w("Failed to fetch matches from audioSource plugin: $e");
    }

    // Native fallback to internal YouTube engine if audioSource produced no results
    if (videoResults.isEmpty) {
      try {
        final ytEngine = ref.read(youtubeEngineProvider);
        final searchQuery = "${query.name} ${query.artists.map((a) => a.name).join(" ")}";
        final ytVideos = await ytEngine.searchVideos(searchQuery);
        for (final v in ytVideos) {
          videoResults.add(
            SpotubeAudioSourceMatchObject(
              id: v.id.value,
              title: v.title,
              artists: [v.author],
              duration: v.duration ?? Duration(milliseconds: query.durationMs),
              thumbnail: v.thumbnails.highResUrl,
              externalUri: "https://youtube.com/watch?v=${v.id.value}",
            ),
          );
        }
      } catch (e) {
        AppLogger.log.w("Internal YouTube engine search fallback failed: $e");
      }
    }

    return videoResults.toSet().toList();
  }

  Future<SourcedTrack> copyWithSibling() async {
    if (siblings.isNotEmpty) {
      return this;
    }
    final fetchedSiblings = await fetchSiblings(ref: ref, query: query);

    return SourcedTrack(
      ref: ref,
      siblings: fetchedSiblings.where((s) => s.id != info.id).toList(),
      source: source,
      sources: sources,
      info: info,
      query: query,
    );
  }

  Future<SourcedTrack?> swapWithSibling(
    SpotubeAudioSourceMatchObject sibling,
  ) async {
    if (sibling.id == info.id) {
      return null;
    }

    final audioSource = await ref.read(audioSourcePluginProvider.future);
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));
    final sourceSlug = audioSourceConfig?.slug ?? source;

    // a sibling source that was fetched from the search results
    final isStepSibling = siblings.none((s) => s.id == sibling.id);

    final newSourceInfo = isStepSibling
        ? sibling
        : siblings.firstWhere((s) => s.id == sibling.id);

    final newSiblings = siblings.where((s) => s.id != sibling.id).toList()
      ..insert(0, info);

    final manifest = await _fetchStreams(
      match: newSourceInfo,
      ref: ref,
      audioSource: audioSource,
    );

    final database = ref.read(databaseProvider);

    // Delete the old Entry
    await (database.sourceMatchTable.delete()
          ..where(
            (table) =>
                table.trackId.equals(query.id) &
                table.sourceType.equals(sourceSlug),
          ))
        .go();

    await database.into(database.sourceMatchTable).insert(
          SourceMatchTableCompanion.insert(
            trackId: query.id,
            sourceInfo: Value(jsonEncode(sibling)),
            sourceType: sourceSlug,
            createdAt: Value(DateTime.now()),
          ),
          mode: InsertMode.replace,
        );

    return SourcedTrack(
      ref: ref,
      source: sourceSlug,
      siblings: newSiblings,
      sources: manifest,
      info: newSourceInfo,
      query: query,
    );
  }

  Future<SourcedTrack?> swapWithSiblingOfIndex(int index) {
    return swapWithSibling(siblings[index]);
  }

  Future<SourcedTrack> refreshStream() async {
    final audioSource = await ref.read(audioSourcePluginProvider.future);
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));
    final sourceSlug = audioSourceConfig?.slug ?? source;

    final validStreams = await _fetchStreams(
      match: info,
      ref: ref,
      audioSource: audioSource,
    );

    final sourcedTrack = SourcedTrack(
      ref: ref,
      siblings: siblings,
      source: sourceSlug,
      sources: validStreams,
      info: info,
      query: query,
    );

    AppLogger.log.i("Refreshing ${query.name}: ${sourcedTrack.url}");

    return sourcedTrack;
  }

  String? get url {
    final preferences = ref.read(audioSourcePresetsProvider);

    final preset = preferences.presets
        .elementAtOrNull(preferences.selectedStreamingContainerIndex);
    if (preset == null) {
      return sources.firstOrNull?.url;
    }

    return getUrlOfQuality(
          preset,
          preferences.selectedStreamingQualityIndex,
        ) ??
        sources.firstOrNull?.url;
  }

  /// Returns the URL of the track based on the codec and quality preferences.
  /// If an exact match is not found, it will return the closest match based on
  /// the user's audio quality preference.
  ///
  /// If no sources match the codec, it will return the first or last source
  /// based on the user's audio quality preference.
  SpotubeAudioSourceStreamObject? getStreamOfQuality(
    SpotubeAudioSourceContainerPreset preset,
    int qualityIndex,
  ) {
    if (sources.isEmpty) return null;

    final quality = preset.qualities.elementAtOrNull(qualityIndex) ??
        preset.qualities.firstOrNull;
    if (quality == null) return sources.firstOrNull;

    final exactMatch = sources.firstWhereOrNull(
      (source) {
        if (source.container != preset.name) return false;

        if (quality case SpotubeAudioLosslessContainerQuality()) {
          return source.sampleRate == quality.sampleRate &&
              source.bitDepth == quality.bitDepth;
        } else {
          return source.bitrate ==
              (quality as SpotubeAudioLossyContainerQuality).bitrate;
        }
      },
    );

    if (exactMatch != null) {
      return exactMatch;
    }

    final containerMatches = sources.where((source) {
      return source.container == preset.name;
    }).toList();

    if (containerMatches.isEmpty) {
      return sources.firstOrNull;
    }

    // Find the preset with closest quality to the supplied quality
    return containerMatches.reduce((prev, curr) {
      if (quality is SpotubeAudioLosslessContainerQuality) {
        final prevDiff = ((prev.sampleRate ?? 0) - quality.sampleRate).abs() +
            ((prev.bitDepth ?? 0) - quality.bitDepth).abs();
        final currDiff = ((curr.sampleRate ?? 0) - quality.sampleRate).abs() +
            ((curr.bitDepth ?? 0) - quality.bitDepth).abs();
        return currDiff < prevDiff ? curr : prev;
      } else {
        final prevDiff = ((prev.bitrate ?? 0) -
                (quality as SpotubeAudioLossyContainerQuality).bitrate)
            .abs();
        final currDiff = ((curr.bitrate ?? 0) - quality.bitrate).abs();
        return currDiff < prevDiff ? curr : prev;
      }
    });
  }

  String? getUrlOfQuality(
    SpotubeAudioSourceContainerPreset preset,
    int qualityIndex,
  ) {
    return getStreamOfQuality(preset, qualityIndex)?.url;
  }

  SpotubeAudioSourceContainerPreset? get qualityPreset {
    final presetState = ref.read(audioSourcePresetsProvider);
    return presetState.presets
        .elementAtOrNull(presetState.selectedStreamingContainerIndex);
  }
}
