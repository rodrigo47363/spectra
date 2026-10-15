import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:spotube/collections/fake.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/dialogs/select_device_dialog.dart';
import 'package:spotube/components/track_tile/track_tile.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/models/connect/connect.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/connect/connect.dart';
import 'package:spotube/provider/audio_player/audio_player.dart';
import 'package:spotube/provider/metadata_plugin/artist/all_tracks.dart';
import 'package:spotube/provider/metadata_plugin/artist/top_tracks.dart';
import 'package:spotube/services/audio_player/audio_player.dart';

class ArtistPageTopTracks extends HookConsumerWidget {
  final String artistId;
  const ArtistPageTopTracks({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final isLoading = useState(false);
    final activeTab = useState(0); // 0: Top Tracks, 1: All Songs
    final searchQuery = useState("");

    final playlist = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);

    // Consultas
    final topTracksQuery =
        ref.watch(metadataPluginArtistTopTracksProvider(artistId));
    final allTracksAsync =
        ref.watch(metadataPluginArtistAllTracksProvider(artistId));

    if (topTracksQuery.hasError) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(topTracksQuery.error.toString()),
        ),
      );
    }

    final isTopTracksLoading = activeTab.value == 0 &&
        topTracksQuery.isLoading &&
        topTracksQuery.asData?.value == null;

    final topTracks = topTracksQuery.asData?.value.items ?? [];

    final allTracks = allTracksAsync.asData?.value ?? [];

    final filteredAllTracks = useMemoized(() {
      final q = searchQuery.value.trim().toLowerCase();
      if (q.isEmpty) return allTracks;
      return allTracks.where((t) {
        final nameMatch = t.name.toLowerCase().contains(q);
        final albumMatch = t.album.name.toLowerCase().contains(q);
        return nameMatch || albumMatch;
      }).toList();
    }, [allTracks, searchQuery.value]);

    final currentTracks = activeTab.value == 0 ? topTracks : filteredAllTracks;
    final isCurrentPlaying = playlist.containsTracks(currentTracks);

    void playPlaylist(
      List<SpotubeFullTrackObject> tracks, {
      SpotubeTrackObject? currentTrack,
      bool shuffle = false,
    }) async {
      final playableTracks = tracks
          .where((t) =>
              t.id != "1" &&
              t.id != FakeData.track.id &&
              t.name != FakeData.track.name)
          .toList();
      if (playableTracks.isEmpty) return;
      isLoading.value = true;

      if (shuffle) {
        playableTracks.shuffle();
      }

      currentTrack ??= playableTracks.first;
      try {
        final isRemoteDevice = await showSelectDeviceDialog(context, ref);

        if (isRemoteDevice == null) return;

        if (isRemoteDevice) {
          final remotePlayback = ref.read(connectProvider.notifier);
          final remotePlaylist = ref.read(queueProvider);

          final isPlaylistPlaying =
              remotePlaylist.containsTracks(playableTracks);

          if (!isPlaylistPlaying) {
            await remotePlayback.load(
              WebSocketLoadEventData.playlist(
                tracks: playableTracks,
                collection: null,
                initialIndex:
                    playableTracks.indexWhere((s) => s.id == currentTrack?.id),
              ),
            );
          } else if (isPlaylistPlaying &&
              currentTrack.id != remotePlaylist.activeTrack?.id) {
            final index = playlist.tracks
                .toList()
                .indexWhere((s) => s.id == currentTrack!.id);
            await remotePlayback.jumpTo(index);
          }
        } else {
          final isPlaying = playlist.containsTracks(playableTracks);
          if (!isPlaying || shuffle) {
            await playlistNotifier.load(
              playableTracks,
              initialIndex:
                  playableTracks.indexWhere((s) => s.id == currentTrack?.id),
              autoPlay: true,
            );
            if (shuffle) {
              await audioPlayer.setShuffle(true);
            }
          } else if (isPlaying && currentTrack.id != playlist.activeTrack?.id) {
            await playlistNotifier.jumpToTrack(currentTrack);
          }
        }
      } finally {
        isLoading.value = false;
      }
    }

    final isAllTracksLoading =
        activeTab.value == 1 && allTracksAsync.isLoading && allTracks.isEmpty;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Tabs(
                  index: activeTab.value,
                  onChanged: (idx) => activeTab.value = idx,
                  children: [
                    TabItem(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          const Icon(SpotubeIcons.personalized, size: 14),
                          Text(context.l10n.top_tracks),
                          SecondaryBadge(child: Text("${topTracks.length}")),
                        ],
                      ),
                    ),
                    TabItem(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          const Icon(SpotubeIcons.music, size: 14),
                          Text(context.l10n.songs),
                          if (allTracksAsync.hasValue)
                            SecondaryBadge(child: Text("${allTracks.length}")),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    IconButton.outline(
                      icon: const Icon(SpotubeIcons.queueAdd),
                      onPressed: () {
                        final tracksToAdd = currentTracks.toList();
                        if (tracksToAdd.isEmpty) return;
                        playlistNotifier.addTracks(tracksToAdd);
                        showToast(
                          context: context,
                          location: ToastLocation.topRight,
                          builder: (context, overlay) {
                            return SurfaceCard(
                              child: Text(
                                context.l10n.added_to_queue(tracksToAdd.length),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    IconButton.secondary(
                      icon: const Icon(SpotubeIcons.shuffle),
                      onPressed: isLoading.value
                          ? null
                          : () => playPlaylist(
                                currentTracks.toList(),
                                shuffle: true,
                              ),
                    ),
                    IconButton.primary(
                      shape: ButtonShape.circle,
                      enabled: !isLoading.value && currentTracks.isNotEmpty,
                      icon: isLoading.value
                          ? CircularProgressIndicator(
                              size: 20 * context.theme.scaling,
                              color: theme.colorScheme.primaryForeground,
                            )
                          : Skeleton.keep(
                              child: Icon(
                                isCurrentPlaying
                                    ? SpotubeIcons.pause
                                    : SpotubeIcons.play,
                              ),
                            ),
                      onPressed: () => playPlaylist(currentTracks.toList()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (activeTab.value == 1)
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        onChanged: (v) => searchQuery.value = v,
                        features: const [
                          InputFeature.leading(
                              Icon(SpotubeIcons.search, size: 16)),
                        ],
                        placeholder: Text(context.l10n.search_tracks),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlineBadge(
                    child: Text(
                      searchQuery.value.isEmpty
                          ? "${allTracks.length} ${context.l10n.summary_songs}"
                          : "${filteredAllTracks.length} / ${allTracks.length}",
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SliverGap(8),
        if (isTopTracksLoading || isAllTracksLoading)
          SliverToBoxAdapter(
            child: Skeletonizer(
              enabled: true,
              child: IgnorePointer(
                child: Column(
                  children: List.generate(
                    8,
                    (index) => TrackTile(
                      index: index,
                      playlist: playlist,
                      track: FakeData.track,
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (currentTracks.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  searchQuery.value.isNotEmpty
                      ? context.l10n.no_tracks
                      : context.l10n.no_tracks_added_yet,
                  style: TextStyle(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: currentTracks.length,
            itemBuilder: (context, index) {
              final track = currentTracks.elementAt(index);
              return TrackTile(
                index: index,
                playlist: playlist,
                track: track,
                onTap: () async {
                  playPlaylist(
                    currentTracks.toList(),
                    currentTrack: track,
                  );
                },
              );
            },
          ),
        if (activeTab.value == 0 && topTracks.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Center(
                child: Button.secondary(
                  leading: const Icon(SpotubeIcons.music, size: 16),
                  onPressed: () => activeTab.value = 1,
                  child: Text(
                    allTracksAsync.hasValue
                        ? "Ver todas las canciones (${allTracks.length} disponibles)"
                        : "Ver todas las canciones del artista",
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
