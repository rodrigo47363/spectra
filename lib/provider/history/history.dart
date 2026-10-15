import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/collections/fake.dart';
import 'package:spotube/models/database/database.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/database/database.dart';

class PlaybackHistoryActions {
  final Ref ref;
  AppDatabase get _db => ref.read(databaseProvider);

  PlaybackHistoryActions(this.ref);

  Future<void> _batchInsertHistoryEntries(
      List<HistoryTableCompanion> entries) async {
    await _db.batch((batch) {
      batch.insertAll(_db.historyTable, entries);
    });
  }

  Future<void> addPlaylists(List<SpotubeSimplePlaylistObject> playlists) async {
    final cleanPlaylists = playlists
        .where((p) => p.id != "1" && p.name != FakeData.playlistSimple.name)
        .toList();
    if (cleanPlaylists.isEmpty) return;
    await _batchInsertHistoryEntries([
      for (final playlist in cleanPlaylists)
        HistoryTableCompanion.insert(
          type: HistoryEntryType.playlist,
          itemId: playlist.id,
          data: playlist.toJson(),
        ),
    ]);
  }

  Future<void> addAlbums(List<SpotubeSimpleAlbumObject> albums) async {
    final cleanAlbums = albums
        .where((a) => a.id != "1" && a.name != FakeData.albumSimple.name)
        .toList();
    if (cleanAlbums.isEmpty) return;
    await _batchInsertHistoryEntries([
      for (final album in cleanAlbums)
        HistoryTableCompanion.insert(
          type: HistoryEntryType.album,
          itemId: album.id,
          data: album.toJson(),
        ),
    ]);
  }

  Future<void> addTracks(List<SpotubeTrackObject> tracks) async {
    final cleanTracks = tracks
        .where((t) =>
            t.id != "1" &&
            t.id != FakeData.track.id &&
            t.name != FakeData.track.name)
        .toList();
    if (cleanTracks.isEmpty) return;
    await _batchInsertHistoryEntries([
      for (final track in cleanTracks)
        HistoryTableCompanion.insert(
          type: HistoryEntryType.track,
          itemId: track.id,
          data: track.toJson(),
        ),
    ]);
  }

  Future<void> addTrack(SpotubeTrackObject track) async {
    if (track.id == "1" ||
        track.id == FakeData.track.id ||
        track.name == FakeData.track.name) {
      return;
    }
    await _db.into(_db.historyTable).insert(
          HistoryTableCompanion.insert(
            type: HistoryEntryType.track,
            itemId: track.id,
            data: track.toJson(),
          ),
        );
  }

  Future<void> clear() async {
    await _db.delete(_db.historyTable).go();
  }
}

final playbackHistoryActionsProvider =
    Provider((ref) => PlaybackHistoryActions(ref));
