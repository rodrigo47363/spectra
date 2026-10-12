import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:spotube/collections/fake.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/dialogs/select_device_dialog.dart';
import 'package:spotube/components/image/universal_image.dart';
import 'package:spotube/extensions/constrains.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/models/connect/connect.dart';
import 'package:spotube/models/database/database.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/audio_player/audio_player.dart';
import 'package:spotube/provider/blacklist_provider.dart';
import 'package:spotube/provider/connect/connect.dart';
import 'package:spotube/provider/metadata_plugin/artist/artist.dart';
import 'package:spotube/provider/metadata_plugin/artist/top_tracks.dart';
import 'package:spotube/provider/metadata_plugin/artist/wikipedia.dart';
import 'package:spotube/provider/metadata_plugin/core/auth.dart';
import 'package:spotube/provider/metadata_plugin/library/artists.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/services/audio_player/audio_player.dart';
import 'package:spotube/utils/primitive_utils.dart';

class ArtistPageHeader extends HookConsumerWidget {
  final String artistId;
  const ArtistPageHeader({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, ref) {
    final artistQuery = ref.watch(metadataPluginArtistProvider(artistId));
    final artist = artistQuery.asData?.value ?? FakeData.artist;

    final theme = Theme.of(context);
    final ThemeData(:typography) = theme;

    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);
    ref.watch(blacklistProvider);
    final blacklistNotifier = ref.watch(blacklistProvider.notifier);
    final isBlackListed = blacklistNotifier.containsArtist(artist.id);

    String image = artist.images.asUrlString(
      placeholder: ImagePlaceholder.artist,
    );

    if ((image.isEmpty || image.startsWith('assets/')) &&
        artistId.contains('::img:')) {
      final parts = artistId.split('::img:');
      if (parts.length > 1) {
        final raw = parts[1].split('::')[0];
        if (raw.isNotEmpty) {
          try {
            image = Uri.decodeComponent(raw);
          } catch (_) {
            image = raw;
          }
        }
      }
    }

    if (image.isEmpty || image.startsWith('assets/')) {
      final summary = ref.watch(artistWikipediaSummaryProvider(artist));
      final wikiImg = summary.asData?.value?.thumbnail?.source_ ??
          summary.asData?.value?.originalimage?.source_;
      if (wikiImg != null && wikiImg.isNotEmpty) {
        image = wikiImg;
      }
    }

    final topTracksQuery =
        ref.watch(metadataPluginArtistTopTracksProvider(artistId));
    final topTracks =
        topTracksQuery.asData?.value.items ?? <SpotubeFullTrackObject>[];
    final playlist = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
    final isPlayingStream =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;
    final isArtistTracksPlaying =
        topTracks.isNotEmpty && playlist.containsTracks(topTracks);
    final isCurrentArtistPlaying = isArtistTracksPlaying && isPlayingStream;
    final isActionLoading = useState(false);

    void playArtist({bool shuffle = false}) async {
      if (topTracks.isEmpty) return;
      isActionLoading.value = true;
      try {
        final isRemoteDevice = await showSelectDeviceDialog(context, ref);
        if (isRemoteDevice == null) return;

        if (isRemoteDevice) {
          final remotePlayback = ref.read(connectProvider.notifier);
          final remotePlaylist = ref.read(queueProvider);
          final isRemotePlaying = remotePlaylist.containsTracks(topTracks);
          if (!isRemotePlaying) {
            await remotePlayback.load(
              WebSocketLoadEventData.playlist(
                tracks: topTracks.toList(),
                collection: null,
                initialIndex: 0,
              ),
            );
          } else {
            await remotePlayback.resume();
          }
        } else {
          if (isArtistTracksPlaying) {
            if (shuffle) {
              await audioPlayer.setShuffle(true);
            } else {
              isPlayingStream
                  ? await audioPlayer.pause()
                  : await audioPlayer.resume();
            }
          } else {
            await playlistNotifier.load(
              topTracks.toList(),
              initialIndex: 0,
              autoPlay: true,
            );
            if (shuffle) {
              await audioPlayer.setShuffle(true);
            }
          }
        }
      } finally {
        isActionLoading.value = false;
      }
    }

    void startArtistRadio() async {
      if (topTracks.isEmpty) return;
      final seedTrack = topTracks.first;
      isActionLoading.value = true;
      try {
        final metadataPlugin = await ref.read(metadataPluginProvider.future);
        if (metadataPlugin == null) return;
        final radioTracks = await metadataPlugin.track.radio(seedTrack.id);
        if (radioTracks.isEmpty) return;
        await playlistNotifier.stop();
        await playlistNotifier
            .load([seedTrack, ...radioTracks], autoPlay: true);
        if (context.mounted) {
          showToast(
            context: context,
            location: ToastLocation.topRight,
            builder: (context, overlay) => SurfaceCard(
              child: Text(context.l10n.start_a_radio),
            ),
          );
        }
      } finally {
        isActionLoading.value = false;
      }
    }

    final actions = Skeleton.keep(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Button.primary(
            leading: isActionLoading.value
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primaryForeground,
                    ),
                  )
                : Icon(
                    isCurrentArtistPlaying
                        ? SpotubeIcons.pause
                        : SpotubeIcons.play,
                    size: 16,
                  ),
            onPressed: topTracks.isEmpty && topTracksQuery.isLoading
                ? null
                : () => playArtist(),
            child: Text(
              isCurrentArtistPlaying ? context.l10n.pause : context.l10n.play,
            ),
          ),
          Tooltip(
            tooltip: TooltipContainer(
              child: Text(context.l10n.shuffle_playlist),
            ).call,
            child: IconButton.secondary(
              icon: const Icon(SpotubeIcons.shuffle, size: 16),
              onPressed: topTracks.isEmpty && topTracksQuery.isLoading
                  ? null
                  : () => playArtist(shuffle: true),
            ),
          ),
          Tooltip(
            tooltip: TooltipContainer(
              child: Text(context.l10n.start_a_radio),
            ).call,
            child: IconButton.secondary(
              icon: const Icon(SpotubeIcons.radio, size: 16),
              onPressed: topTracks.isEmpty && topTracksQuery.isLoading
                  ? null
                  : startArtistRadio,
            ),
          ),
          if (authenticated.asData?.value == true)
            Consumer(
              builder: (context, ref, _) {
                final isFollowingQuery = ref.watch(
                  metadataPluginIsSavedArtistProvider(artist.id),
                );
                final followingArtistNotifier =
                    ref.watch(metadataPluginSavedArtistsProvider.notifier);

                return switch (isFollowingQuery) {
                  AsyncData(value: final following) => Builder(
                      builder: (context) {
                        if (following) {
                          return Button.outline(
                            onPressed: () async {
                              await followingArtistNotifier
                                  .removeFavorite([artist]);
                            },
                            child: Text(context.l10n.following),
                          );
                        }

                        return Button.outline(
                          onPressed: () async {
                            await followingArtistNotifier.addFavorite([artist]);
                          },
                          child: Text(context.l10n.follow),
                        );
                      },
                    ),
                  AsyncError() => const SizedBox(),
                  _ => const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(),
                    )
                };
              },
            ),
          Tooltip(
            tooltip: TooltipContainer(
              child: Text(context.l10n.add_artist_to_blacklist),
            ).call,
            child: IconButton(
              icon: Icon(
                SpotubeIcons.userRemove,
                color: !isBlackListed ? Colors.red[400] : null,
              ),
              variance: isBlackListed
                  ? ButtonVariance.destructive
                  : ButtonVariance.ghost,
              onPressed: () async {
                if (isBlackListed) {
                  await ref.read(blacklistProvider.notifier).remove(artist.id);
                } else {
                  await ref.read(blacklistProvider.notifier).add(
                        BlacklistTableCompanion.insert(
                          name: artist.name,
                          elementId: artist.id,
                          elementType: BlacklistedType.artist,
                        ),
                      );
                }
              },
            ),
          ),
          IconButton.ghost(
            icon: const Icon(SpotubeIcons.share),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: artist.externalUri,
                ),
              );

              if (!context.mounted) return;

              showToast(
                context: context,
                location: ToastLocation.topRight,
                dismissible: true,
                builder: (context, overlay) {
                  return SurfaceCard(
                    child: Text(
                      context.l10n.artist_url_copied,
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              );
            },
          )
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constrains) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: theme.borderRadiusXl,
                      child: UniversalImage(
                        path: image,
                        width: constrains.mdAndUp ? 200 : 120,
                        height: constrains.mdAndUp ? 200 : 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const Gap(20),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlineBadge(
                                child:
                                    Text(context.l10n.artist).small().muted(),
                              ),
                              if (isBlackListed) ...[
                                const Gap(5),
                                DestructiveBadge(
                                  child: Text(context.l10n.blacklisted).small(),
                                ),
                              ]
                            ],
                          ),
                          const Gap(10),
                          Flexible(
                            child: AutoSizeText(
                              artist.name,
                              style: constrains.smAndDown
                                  ? typography.h4
                                  : typography.h3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              minFontSize: 14,
                            ),
                          ),
                          if (artist.followers != null &&
                              artist.followers! > 0 &&
                              !artist.followers!.toDouble().isInfinite) ...[
                            const Gap(5),
                            Flexible(
                              child: AutoSizeText(
                                context.l10n.followers(
                                  PrimitiveUtils.toReadableNumber(
                                    artist.followers!.toDouble(),
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                minFontSize: 12,
                              ).muted(),
                            ),
                          ],
                          if (constrains.mdAndUp) ...[
                            const Gap(20),
                            actions,
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
                if (constrains.smAndDown) ...[
                  const Gap(20),
                  actions,
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}
