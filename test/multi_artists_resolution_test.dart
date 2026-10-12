import 'package:flutter_test/flutter_test.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:spotube/services/metadata/endpoints/artist.dart';

void main() {
  group('Multi-Artist Comprehensive Track Resolution Tests', () {
    late MetadataPluginArtistEndpoint endpoint;

    setUp(() {
      final hetu = Hetu();
      endpoint = MetadataPluginArtistEndpoint(hetu);
    });

    final testArtists = [
      'Ado',
      'Queen',
      'Taylor Swift',
      'Rosalía',
      'Eminem',
      'Metallica',
      'Hans Zimmer',
      'YOASOBI',
      'Bad Bunny',
    ];

    for (final artistName in testArtists) {
      test('resolveArtistOnlineTracks returns rich catalog (>= 25 tracks) for "$artistName"', () async {
        final tracks = await endpoint.resolveArtistOnlineTracks(artistName, limit: 50);
        expect(
          tracks.length,
          greaterThanOrEqualTo(25),
          reason: 'Artist "$artistName" must return at least 25 songs',
        );

        // Validar integridad de cada pista
        for (final track in tracks.take(5)) {
          expect(track.id.isNotEmpty, isTrue);
          expect(track.name.trim().isNotEmpty, isTrue);
          expect(track.durationMs, greaterThan(0));
          expect(track.album.name.isNotEmpty, isTrue);
          expect(track.artists.isNotEmpty, isTrue);
        }
      });
    }
  });
}
