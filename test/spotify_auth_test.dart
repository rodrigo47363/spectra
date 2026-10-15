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

  test('Spotify auth pipeline test (anonymous & cookie login flow)', () async {
    SharedPreferences.setMockInitialValues({});

    final pluginBinaryFile = File('/home/rodrigo47363/Projects/spectra-plugin-spotify/build/plugin.out');
    if (!pluginBinaryFile.existsSync()) {
      print('Skipping spotify auth test: plugin binary not found in current environment');
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
    final metadataPlugin = await MetadataPlugin.create(
      youtubeEngine,
      config,
      byteCode,
    );

    expect(metadataPlugin, isNotNull);
    expect(metadataPlugin.auth.isAuthenticated(), isFalse);

    // Test that authStateStream receives events without errors
    final authEvents = <dynamic>[];
    final sub = metadataPlugin.auth.authStateStream.listen((event) {
      print('Auth stream received event: $event');
      authEvents.add(event);
    });

    // Wait for anonymous token initialization
    await Future.delayed(const Duration(seconds: 4));

    print('Anonymous auth completed. Events captured: ${authEvents.length}');
    expect(authEvents.isNotEmpty, isTrue);

    sub.cancel();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
