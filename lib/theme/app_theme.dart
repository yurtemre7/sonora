import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sonora/models/song.dart';

class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF7C4DFF);

  static final Map<int, ThemeData> _lightThemeCache = {};
  static final Map<int, ThemeData> _darkThemeCache = {};

  /// Retrieves the cached [ThemeData] for [seedColor] and [brightness], or
  /// builds it on demand.
  static ThemeData getTheme(
    Brightness brightness, {
    Color seedColor = _seedColor,
    bool amoledDark = false,
  }) {
    var cache = brightness == Brightness.light
        ? _lightThemeCache
        : _darkThemeCache;
    // factor amoled into cache key by bitwise flipping or shifting if dark
    var key = seedColor.toARGB32();
    if (brightness == Brightness.dark && amoledDark) {
      key = key ^ 0xFFFFFFFF; // Simple way to differentiate amoled key
    }
    return cache.putIfAbsent(
      key,
      () =>
          buildTheme(brightness, seedColor: seedColor, amoledDark: amoledDark),
    );
  }

  /// Pre-computes and caches Light/Dark [ThemeData] for all unique dominant colors in the song list.
  /// Returns the count of truly unique generated [ColorScheme]s.
  static int precomputeThemes(List<Song> songs) {
    var uniqueColors = <int>{};
    for (var song in songs) {
      if (song.dominantColor != null) {
        uniqueColors.add(song.dominantColor!);
      }
    }
    // Also include default seed color
    uniqueColors.add(_seedColor.toARGB32());

    var buckets = <String>{};

    for (var colorValue in uniqueColors) {
      var color = Color(colorValue);
      var hsl = HSLColor.fromColor(color);

      // Group low saturation/grayscale, and extremely dark or light colors into a neutral theme bucket
      if (hsl.saturation < 0.15 ||
          hsl.lightness < 0.15 ||
          hsl.lightness > 0.85) {
        buckets.add('neutral');
      } else {
        // Group similar hues by rounding the hue angle to the nearest 30 degrees (12 segments on the color wheel)
        var hueSector = ((hsl.hue / 30).round() * 30) % 360;
        buckets.add('hue_$hueSector');
      }
    }

    return buckets.length;
  }

  static TextTheme _buildTextTheme(Brightness brightness, Color seedColor) {
    var base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    var colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    var outfitTextTheme = GoogleFonts.outfitTextTheme(base).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
    var interTextTheme = GoogleFonts.interTextTheme(base).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return TextTheme(
      displayLarge: outfitTextTheme.displayLarge,
      displayMedium: outfitTextTheme.displayMedium,
      displaySmall: outfitTextTheme.displaySmall,
      headlineLarge: outfitTextTheme.headlineLarge,
      headlineMedium: outfitTextTheme.headlineMedium,
      headlineSmall: outfitTextTheme.headlineSmall,
      titleLarge: outfitTextTheme.titleLarge,
      titleMedium: outfitTextTheme.titleMedium,
      titleSmall: outfitTextTheme.titleSmall,
      bodyLarge: interTextTheme.bodyLarge,
      bodyMedium: interTextTheme.bodyMedium,
      bodySmall: interTextTheme.bodySmall,
      labelLarge: interTextTheme.labelLarge,
      labelMedium: interTextTheme.labelMedium,
      labelSmall: interTextTheme.labelSmall,
    );
  }

  static ThemeData buildTheme(
    Brightness brightness, {
    Color seedColor = _seedColor,
    bool amoledDark = false,
  }) {
    var colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    if (brightness == Brightness.dark && amoledDark) {
      colorScheme = colorScheme.copyWith(
        surface: const Color(0xFF000000),
        surfaceContainerLowest: const Color(0xFF000000),
        surfaceContainerLow: const Color(0xFF050505),
        surfaceContainer: const Color(0xFF0A0A0A),
        surfaceContainerHigh: const Color(0xFF101010),
        surfaceContainerHighest: const Color(0xFF151515),
      );
    }

    var textTheme = _buildTextTheme(brightness, seedColor);

    var outfitTitleStyle = GoogleFonts.outfit(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: outfitTitleStyle.copyWith(fontSize: 22),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarIconBrightness: brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
          statusBarBrightness: brightness == Brightness.light
              ? Brightness.light
              : Brightness.dark, // iOS
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.12),
        thumbColor: colorScheme.primary,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: colorScheme.onSurface),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        thickness: 0.5,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: Colors.transparent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(8.0),
        radius: const Radius.circular(8.0),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged) ||
              states.contains(WidgetState.hovered)) {
            return colorScheme.primary;
          }
          return colorScheme.primary.withValues(alpha: 0.5);
        }),
        interactive: true,
      ),
    );
  }

  static ThemeData get darkTheme => getTheme(Brightness.dark);

  static ThemeData get lightTheme => getTheme(Brightness.light);
}
