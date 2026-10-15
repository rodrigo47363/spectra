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
  AppLogger.initialize(false);

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter_timezone'),
    (MethodCall methodCall) async => 'UTC',
  );

  test('Spotify custom plugin compiles and loads into MetadataPlugin runtime', () async {
    SharedPreferences.setMockInitialValues({});

    final pluginBinaryFile = File('/home/rodrigo47363/Projects/spectra-plugin-spotify/build/plugin.out');
    if (!pluginBinaryFile.existsSync()) {
      print('Skipping spotify plugin load test: plugin binary not found in current environment');
      return;
    }

    final byteCode = await pluginBinaryFile.readAsBytes();
    final config = PluginConfiguration(
      name: 'Spectra Spotify',
      author: 'Rodrigo',
      description: 'Plugin nativo de Spotify con soporte de login híbrido y GraphQL para Spectra',
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

    final youtubeEngine = YouTubeExplodeEngine();

    print('Creating MetadataPlugin...');
    final metadataPlugin = await MetadataPlugin.create(
      youtubeEngine,
      config,
      byteCode,
    );

    print('MetadataPlugin created successfully!');
    expect(metadataPlugin, isNotNull);

    print('Checking isAuthenticated()...');
    final isAuth = metadataPlugin.auth.isAuthenticated();
    print('isAuthenticated: $isAuth');
    expect(isAuth, isFalse);

    print('Waiting 3s for anonymous token initialization...');
    await Future.delayed(const Duration(seconds: 3));

    print('Testing search.all("Daft Punk")...');
    try {
      final searchResults = await metadataPlugin.search.all('Daft Punk');
      print('Search results received: tracks=${searchResults.tracks.length}, artists=${searchResults.artists.length}, albums=${searchResults.albums.length}');
      if (searchResults.tracks.isNotEmpty) {
        print('First track: "${searchResults.tracks.first.name}" by ${searchResults.tracks.first.artists.map((a) => a.name).join(", ")}');
      }
    } catch (e, st) {
      print('Search exception: $e\n$st');
    }
    print('Testing track.getTrack("4cOdK2wGLETKBW3PvgPWqT")...');
    try {
      final singleTrack = await metadataPlugin.track.getTrack('4cOdK2wGLETKBW3PvgPWqT');
      print('getTrack success: "${singleTrack.name}" by ${singleTrack.artists.map((a) => a.name).join(", ")} (album: ${singleTrack.album.name})');
    } catch (e, st) {
      print('getTrack EXCEPTION: $e\n$st');
    }

    print('Testing track.radio("4cOdK2wGLETKBW3PvgPWqT")...');
    try {
      final radioTracks = await metadataPlugin.track.radio('4cOdK2wGLETKBW3PvgPWqT');
      print('Radio tracks count: ${radioTracks.length}');
      if (radioTracks.isNotEmpty) {
        print('First radio track: "${radioTracks.first.name}"');
      }
    } catch (e, st) {
      print('Radio exception: $e\n$st');
    }

    print('Testing browse.sections()...');
    try {
      final browseSections = await metadataPlugin.browse.sections();
      print('Sections count: ${browseSections.items.length}');
      if (browseSections.items.isNotEmpty) {
        print('First section title: ${browseSections.items.first.title}');
      }
    } catch (e, st) {
      print('Browse sections exception: $e\n$st');
    }
  }, timeout: const Timeout(Duration(seconds: 45)));
}
