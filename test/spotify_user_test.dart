import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:spotube/services/metadata/metadata.dart';
import 'package:spotube/services/youtube_engine/youtube_explode_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  AppLogger.initialize(true);

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter_timezone'),
    (MethodCall methodCall) async => 'UTC',
  );

  test('Diagnose user endpoints with real session credentials', () async {
    final prefsFile = File('/home/rodrigo47363/.local/share/dev.rodrigo.spectra/shared_preferences.json');
    final pluginBinaryFile = File('/home/rodrigo47363/Projects/spectra-plugin-spotify/build/plugin.out');
    if (!prefsFile.existsSync() || !pluginBinaryFile.existsSync()) {
      print('Skipping local diagnostic test: local environment files not found');
      return;
    }
    final prefsData = json.decode(prefsFile.readAsStringSync()) as Map<String, dynamic>;
    
    // Inject all preferences including credentials
    SharedPreferences.setMockInitialValues({
      for (final entry in prefsData.entries)
        entry.key.replaceFirst('flutter.', ''): entry.value,
    });

    final byteCode = await pluginBinaryFile.readAsBytes();
    final config = PluginConfiguration(
      name: 'Spectra Spotify',
      author: 'Rodrigo',
      description: 'Plugin nativo de Spotify',
      version: '1.0.0',
      entryPoint: 'SpectraSpotifyPlugin',
      pluginApiVersion: '2.0.0',
      apis: [
        PluginApis.webview,
        PluginApis.localstorage,
        PluginApis.timezone,
      ],
      abilities: [
        PluginAbilities.authentication,
        PluginAbilities.metadata,
      ],
    );

    final metadataPlugin = await MetadataPlugin.create(
      YouTubeExplodeEngine(),
      config,
      byteCode,
    );

    print('Waiting 4s for auth credentials to load and token to refresh...');
    await Future.delayed(const Duration(seconds: 4));

    final isAuth = metadataPlugin.auth.isAuthenticated();
    print('isAuthenticated: $isAuth');
    expect(isAuth, true, reason: 'User must be authenticated with existing session');

    print('--- Testing user.me() ---');
    final me = await metadataPlugin.user.me();
    print('me: id=${me.id}, name=${me.name}');
    expect(me.id.isNotEmpty, true);

    final hetu = (metadataPlugin as dynamic).hetu;
    final hetuMetadataUser = ((hetu.fetch("metadataPlugin") as dynamic)).memberGet("user");
    final client = hetuMetadataUser.memberGet("client");
    final user = client.memberGet("user");
    final rawPlaylists = await user.invoke("savedPlaylists", namedArgs: {"offset": 0, "limit": 50});
    print('RAW client.user.savedPlaylists: count=${(rawPlaylists["items"] as List).length}, total=${rawPlaylists["total"]}');
    for (final p in (rawPlaylists["items"] as List)) {
      print('  RAW Playlist: ${p["name"]} (id=${p["id"]})');
    }

    print('--- Testing metadataPlugin.user.savedPlaylists() (used by UI) ---');
    final playlists = await metadataPlugin.user.savedPlaylists(limit: 50);
    print('metadataPlugin.user.savedPlaylists: count=${playlists.items.length}, total=${playlists.total}');
    for (final p in playlists.items) {
      print('  HIGH Playlist: ${p.name} (id=${p.id})');
    }
    expect(playlists.items.isNotEmpty, true, reason: 'Saved playlists should not be empty');

    print('--- Testing metadataPlugin.user.savedTracks() (used by UI) ---');
    final tracks = await metadataPlugin.user.savedTracks();
    print('metadataPlugin.user.savedTracks: count=${tracks.items.length}, total=${tracks.total}');
    for (final t in tracks.items.take(5)) {
      print('  Track: ${t.name} by ${t.artists.map((a) => a.name).join(", ")} (id=${t.id})');
    }
    expect(tracks.items.isNotEmpty, true, reason: 'Saved tracks should not be empty');
  }, timeout: const Timeout(Duration(seconds: 45)));
}
