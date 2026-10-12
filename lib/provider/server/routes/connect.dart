import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:spotube/collections/routes.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/models/connect/connect.dart';
import 'package:spotube/models/metadata/metadata.dart';

import 'package:spotube/provider/history/history.dart';
import 'package:spotube/provider/audio_player/audio_player.dart';
import 'package:spotube/provider/volume_provider.dart';
import 'package:spotube/services/audio_player/audio_player.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

extension _WebsocketSinkExts on WebSocketSink {
  void addEvent(WebSocketEvent event) {
    add(event.toJson());
  }
}

class ServerConnectRoutes {
  final Ref ref;
  final StreamController<String> _connectClientStreamController;
  ServerConnectRoutes(this.ref)
      : _connectClientStreamController = StreamController<String>.broadcast() {
    ref.onDispose(() {
      _connectClientStreamController.close();
    });
  }

  AudioPlayerNotifier get audioPlayerNotifier =>
      ref.read(audioPlayerProvider.notifier);
  PlaybackHistoryActions get historyNotifier =>
      ref.read(playbackHistoryActionsProvider);
  Stream<String> get connectClientStream =>
      _connectClientStreamController.stream;

  final List<String> _allowedConnections = [];

  FutureOr<Response> websocket(Request req) {
    return webSocketHandler(
      (
        WebSocketChannel channel,
        String? protocol,
      ) async {
        final context =
            (req.context["shelf.io.connection_info"] as HttpConnectionInfo?);
        final clientHost = context?.remoteAddress.address ?? "unknown";
        final origin = "${context?.remoteAddress.host ?? clientHost}:${context?.remotePort ?? 0}";
        _connectClientStreamController.add(origin);

        // Confirm whether user allows to connect (by client host)
        if (rootNavigatorKey.currentContext?.mounted == true &&
            _allowedConnections.contains(clientHost) == false) {
          final confirmed = await showDialog<bool>(
                context: rootNavigatorKey.currentContext!,
                builder: (context) {
                  return AlertDialog(
                    title: Text(context.l10n.connect),
                    content: Text(
                      context.l10n.connect_request(origin),
                    ),
                    actions: [
                      Button.secondary(
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                        child: Text(context.l10n.decline),
                      ),
                      Button.primary(
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                        child: Text(context.l10n.accept),
                      ),
                    ],
                  );
                },
              ) ??
              false;

          if (confirmed) {
            _allowedConnections.add(clientHost);
          } else {
            channel.sink.addEvent(
              WebSocketErrorEvent("Connection denied"),
            );
            await channel.sink.close();
            return;
          }
        }

        final clientSubscriptions = <StreamSubscription>[];
        var isClosed = false;

        void safeSend(WebSocketEvent event) {
          if (!isClosed) {
            try {
              channel.sink.addEvent(event);
            } catch (_) {}
          }
        }

        final audioPlayerSub = ref.listen(
          audioPlayerProvider,
          (previous, next) {
            safeSend(WebSocketQueueEvent(next));
          },
          fireImmediately: true,
        );

        // because audioPlayer events doesn't fireImmediately
        safeSend(WebSocketPlayingEvent(audioPlayer.isPlaying));
        safeSend(WebSocketPositionEvent(audioPlayer.position));
        safeSend(WebSocketDurationEvent(audioPlayer.duration));
        safeSend(WebSocketShuffleEvent(audioPlayer.isShuffled));
        safeSend(WebSocketLoopEvent(audioPlayer.loopMode));
        safeSend(WebSocketVolumeEvent(audioPlayer.volume));

        Future<void> cleanup() async {
          if (isClosed) return;
          isClosed = true;
          audioPlayerSub.close();
          for (final sub in clientSubscriptions) {
            await sub.cancel();
          }
          clientSubscriptions.clear();
        }

        clientSubscriptions.addAll([
          audioPlayer.positionStream.listen(
            (position) {
              safeSend(WebSocketPositionEvent(position));
            },
          ),
          audioPlayer.playingStream.listen(
            (playing) {
              safeSend(WebSocketPlayingEvent(playing));
            },
          ),
          audioPlayer.durationStream.listen(
            (duration) {
              safeSend(WebSocketDurationEvent(duration));
            },
          ),
          audioPlayer.shuffledStream.listen(
            (shuffled) {
              safeSend(WebSocketShuffleEvent(shuffled));
            },
          ),
          audioPlayer.loopModeStream.listen(
            (loopMode) {
              safeSend(WebSocketLoopEvent(loopMode));
            },
          ),
          audioPlayer.volumeStream.listen(
            (volume) {
              safeSend(WebSocketVolumeEvent(volume));
            },
          ),
          channel.stream.listen(
            (message) async {
              try {
                final event = WebSocketEvent.fromJson(
                  jsonDecode(message),
                  (data) => data,
                );

                event.onLoad((event) async {
                  await audioPlayerNotifier.load(
                    event.data.tracks.cast<SpotubeFullTrackObject>().toList(),
                    autoPlay: true,
                    initialIndex: event.data.initialIndex ?? 0,
                  );

                  if (event.data.collectionId == null) return;
                  audioPlayerNotifier.addCollection(event.data.collectionId!);
                  if (event.data.collection is SpotubeSimpleAlbumObject) {
                    historyNotifier.addAlbums(
                        [event.data.collection as SpotubeSimpleAlbumObject]);
                  } else if (event.data.collection is SpotubeSimplePlaylistObject) {
                    historyNotifier.addPlaylists(
                        [event.data.collection as SpotubeSimplePlaylistObject]);
                  }
                });

                event.onPause((event) async {
                  await audioPlayer.pause();
                });

                event.onResume((event) async {
                  await audioPlayer.resume();
                });

                event.onStop((event) async {
                  await ref.read(audioPlayerProvider.notifier).stop();
                });

                event.onNext((event) async {
                  await audioPlayer.skipToNext();
                });

                event.onPrevious((event) async {
                  await audioPlayer.skipToPrevious();
                });

                event.onJump((event) async {
                  await audioPlayer.jumpTo(event.data);
                });

                event.onSeek((event) async {
                  await audioPlayer.seek(event.data);
                });

                event.onShuffle((event) async {
                  await audioPlayer.setShuffle(event.data);
                });

                event.onLoop((event) async {
                  await audioPlayer.setLoopMode(event.data);
                });

                event.onAddTrack((event) async {
                  await audioPlayerNotifier.addTrack(event.data);
                });

                event.onRemoveTrack((event) async {
                  await audioPlayerNotifier.removeTrack(event.data);
                });

                event.onReorder((event) async {
                  await audioPlayerNotifier.moveTrack(
                    event.data.oldIndex,
                    event.data.newIndex,
                  );
                });

                event.onVolume((event) async {
                  ref.read(volumeProvider.notifier).setVolume(event.data);
                });
              } catch (e, stackTrace) {
                AppLogger.reportError(e, stackTrace);
                safeSend(WebSocketErrorEvent(e.toString()));
              }
            },
            onDone: () async {
              AppLogger.log.i('Connection closed');
              await cleanup();
            },
            onError: (e, stackTrace) async {
              AppLogger.reportError(e, stackTrace);
              await cleanup();
            },
          ),
        ]);
      },
    )(req);
  }
}

final serverConnectRoutesProvider = Provider((ref) => ServerConnectRoutes(ref));
