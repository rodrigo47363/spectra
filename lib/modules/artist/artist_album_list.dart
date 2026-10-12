import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/audio_player/audio_player.dart';
import 'package:spotube/provider/metadata_plugin/artist/albums.dart';
import 'package:spotube/provider/metadata_plugin/tracks/album.dart';
import 'package:spotube/provider/metadata_plugin/utils/common.dart';
import 'package:spotube/services/audio_player/audio_player.dart';

class ArtistAlbumList extends HookConsumerWidget {
  final String artistId;

  const ArtistAlbumList(
    this.artistId, {
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final albumsQuery = ref.watch(metadataPluginArtistAlbumsProvider(artistId));
    final albumsQueryNotifier =
        ref.watch(metadataPluginArtistAlbumsProvider(artistId).notifier);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);

    final albums = albumsQuery.asData?.value.items ?? [];
    final isLoadingDiscography = useState(false);

    final theme = Theme.of(context);

    Future<void> playAllAlbums({bool shuffle = false}) async {
      if (albums.isEmpty) return;
      isLoadingDiscography.value = true;
      try {
        final List<SpotubeFullTrackObject> allTracks = [];
        for (final album in albums) {
          try {
            final tracks = await ref
                .read(metadataPluginAlbumTracksProvider(album.id).future);
            allTracks.addAll(tracks.items);
          } catch (_) {}
        }
        if (allTracks.isEmpty) return;
        final uniqueTracks = <String, SpotubeFullTrackObject>{};
        for (final t in allTracks) {
          uniqueTracks[t.id] = t;
        }
        final list = uniqueTracks.values.toList();
        if (shuffle) {
          list.shuffle();
        }
        await playlistNotifier.load(list, autoPlay: true);
        if (shuffle) {
          await audioPlayer.setShuffle(true);
        }
        if (context.mounted) {
          showToast(
            context: context,
            location: ToastLocation.topRight,
            builder: (context, overlay) => SurfaceCard(
              child: Text(context.l10n.tracks_in_queue(list.length)),
            ),
          );
        }
      } finally {
        isLoadingDiscography.value = false;
      }
    }

    return HorizontalPlaybuttonCardView<SpotubeSimpleAlbumObject>(
      isLoadingNextPage: albumsQuery.isLoadingNextPage,
      hasNextPage: albumsQuery.asData?.value.hasMore ?? false,
      items: albums,
      onFetchMore: albumsQueryNotifier.fetchMore,
      title: Text(
        context.l10n.albums,
        style: theme.typography.h4,
      ),
      titleTrailing: albums.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Tooltip(
                  tooltip: TooltipContainer(
                    child: Text(context.l10n.play),
                  ).call,
                  child: Button.ghost(
                    leading: isLoadingDiscography.value
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(SpotubeIcons.play, size: 14),
                    onPressed: isLoadingDiscography.value
                        ? null
                        : () => playAllAlbums(shuffle: false),
                    child: Text(context.l10n.play),
                  ),
                ),
                Tooltip(
                  tooltip: TooltipContainer(
                    child: Text(context.l10n.shuffle_playlist),
                  ).call,
                  child: IconButton.ghost(
                    icon: const Icon(SpotubeIcons.shuffle, size: 14),
                    onPressed: isLoadingDiscography.value
                        ? null
                        : () => playAllAlbums(shuffle: true),
                  ),
                ),
              ],
            ),
    );
  }
}
