import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/youtube_engine/youtube_engine.dart';
import 'package:spotube/services/metadata/errors/exceptions.dart';
import 'package:spotube/services/youtube_engine/youtube_search_service.dart';

final metadataPluginTrackProvider =
    FutureProvider.family<SpotubeFullTrackObject, String>((ref, trackId) async {
  if (trackId.startsWith("yt:") || trackId.startsWith("youtube:")) {
    final ytId = trackId.replaceFirst(RegExp(r"^yt:|^youtube:"), "");
    final youtubeEngine = ref.read(youtubeEngineProvider);
    final video = await youtubeEngine.getVideo(ytId);
    return YouTubeSearchService.videoToSpotubeTrack(video);
  }

  final metadataPlugin = await ref.watch(metadataPluginProvider.future);

  if (metadataPlugin == null) {
    throw MetadataPluginException.noDefaultMetadataPlugin();
  }

  return metadataPlugin.track.getTrack(trackId);
});
