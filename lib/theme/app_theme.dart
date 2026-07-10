import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF7C4DFF);

  static TextTheme _buildTextTheme(Brightness brightness) {
    var base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    var colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
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

  static ThemeData _buildTheme(Brightness brightness) {
    var colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    var textTheme = _buildTextTheme(brightness);

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
          statusBarIconBrightness: brightness == Brightness.light
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
}
