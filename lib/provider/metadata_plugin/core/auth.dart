import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/services/logger/logger.dart';

class MetadataPluginAuthenticatedNotifier extends AsyncNotifier<bool> {
  @override
  FutureOr<bool> build() async {
    final defaultPluginConfig = ref.watch(metadataPluginsProvider);
    if (defaultPluginConfig.asData?.value.defaultMetadataPluginConfig?.abilities
            .contains(PluginAbilities.authentication) !=
        true) {
      return false;
    }

    final defaultPlugin = await ref.watch(metadataPluginProvider.future);
    if (defaultPlugin == null) {
      return false;
    }

    try {
      final sub = defaultPlugin.auth.authStateStream.listen((event) {
        state = AsyncData(defaultPlugin.auth.isAuthenticated());
      });

      ref.onDispose(() {
        sub.cancel();
      });
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }

    try {
      return defaultPlugin.auth.isAuthenticated();
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return false;
    }
  }
}

final metadataPluginAuthenticatedProvider =
    AsyncNotifierProvider<MetadataPluginAuthenticatedNotifier, bool>(
  MetadataPluginAuthenticatedNotifier.new,
);

class AudioSourcePluginAuthenticatedNotifier extends AsyncNotifier<bool> {
  @override
  FutureOr<bool> build() async {
    final defaultPluginConfig = ref.watch(metadataPluginsProvider);
    if (defaultPluginConfig
            .asData?.value.defaultAudioSourcePluginConfig?.abilities
            .contains(PluginAbilities.authentication) !=
        true) {
      return false;
    }

    final defaultPlugin = await ref.watch(audioSourcePluginProvider.future);
    if (defaultPlugin == null) {
      return false;
    }

    try {
      final sub = defaultPlugin.auth.authStateStream.listen((event) {
        state = AsyncData(defaultPlugin.auth.isAuthenticated());
      });

      ref.onDispose(() {
        sub.cancel();
      });
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }

    try {
      return defaultPlugin.auth.isAuthenticated();
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return false;
    }
  }
}

final audioSourcePluginAuthenticatedProvider =
    AsyncNotifierProvider<AudioSourcePluginAuthenticatedNotifier, bool>(
  AudioSourcePluginAuthenticatedNotifier.new,
);
