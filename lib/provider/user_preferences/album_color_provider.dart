import 'package:flutter/material.dart' hide ColorScheme, ThemeData;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:spotube/components/image/universal_image.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/audio_player/audio_player.dart';
import 'package:spotube/provider/user_preferences/user_preferences_provider.dart';

final _paletteCache = <String, Color>{};

Color _adjustForDarkTheme(Color color) {
  final hsl = HSLColor.fromColor(color);
  if (hsl.lightness < 0.40) {
    return hsl.withLightness(0.50).toColor();
  } else if (hsl.lightness > 0.85) {
    return hsl.withLightness(0.65).toColor();
  }
  return color;
}

Color _adjustForLightTheme(Color color) {
  final hsl = HSLColor.fromColor(color);
  if (hsl.lightness > 0.55) {
    return hsl.withLightness(0.40).toColor();
  } else if (hsl.lightness < 0.15) {
    return hsl.withLightness(0.35).toColor();
  }
  return color;
}

shadcn.ColorScheme applyDynamicAlbumColor(
  shadcn.ColorScheme base,
  Color dynamicColor,
  Brightness brightness,
) {
  final adjustedColor = brightness == Brightness.dark
      ? _adjustForDarkTheme(dynamicColor)
      : _adjustForLightTheme(dynamicColor);

  final fgColor = adjustedColor.computeLuminance() > 0.5
      ? const Color(0xFF09090B)
      : const Color(0xFFFFFFFF);

  final accentBg = brightness == Brightness.dark
      ? adjustedColor.withValues(alpha: 0.18)
      : adjustedColor.withValues(alpha: 0.12);

  return base.copyWith(
    primary: () => adjustedColor,
    primaryForeground: () => fgColor,
    ring: () => adjustedColor,
    chart1: () => adjustedColor,
    sidebarPrimary: () => adjustedColor,
    sidebarPrimaryForeground: () => fgColor,
    sidebarRing: () => adjustedColor,
    accent: () => accentBg,
    sidebarAccent: () => accentBg,
  );
}

final albumDynamicColorProvider = FutureProvider<Color?>((ref) async {
  final albumColorSync = ref.watch(
    userPreferencesProvider.select((s) => s.albumColorSync),
  );
  if (!albumColorSync) return null;

  final activeTrack = ref.watch(
    audioPlayerProvider.select((s) => s.activeTrack),
  );
  if (activeTrack == null) return null;

  final artworkUrl = activeTrack.album.images.isNotEmpty
      ? activeTrack.album.images.asUrlString(
          placeholder: ImagePlaceholder.albumArt,
        )
      : null;

  if (artworkUrl == null ||
      artworkUrl.isEmpty ||
      artworkUrl.startsWith('assets/')) {
    return null;
  }

  if (_paletteCache.containsKey(artworkUrl)) {
    return _paletteCache[artworkUrl];
  }

  try {
    final imageProvider = UniversalImage.imageProvider(
      artworkUrl,
      height: 64,
      width: 64,
    );
    final palette = await PaletteGenerator.fromImageProvider(
      imageProvider,
      maximumColorCount: 16,
    ).timeout(const Duration(seconds: 2));

    final selectedColor = palette.vibrantColor?.color ??
        palette.dominantColor?.color ??
        palette.lightVibrantColor?.color ??
        palette.darkVibrantColor?.color ??
        palette.mutedColor?.color;

    if (selectedColor != null) {
      if (_paletteCache.length > 50) {
        _paletteCache.remove(_paletteCache.keys.first);
      }
      _paletteCache[artworkUrl] = selectedColor;
    }

    return selectedColor;
  } catch (_) {
    return null;
  }
});
