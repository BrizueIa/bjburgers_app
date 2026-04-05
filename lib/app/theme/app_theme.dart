import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const baseScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF9F3516),
    onPrimary: Colors.white,
    secondary: Color(0xFFEDB458),
    onSecondary: Color(0xFF32200F),
    error: Color(0xFFB3261E),
    onError: Colors.white,
    surface: Color(0xFFFFFBF6),
    onSurface: Color(0xFF231710),
    primaryContainer: Color(0xFFF7D2B7),
    onPrimaryContainer: Color(0xFF3A1306),
    secondaryContainer: Color(0xFFFFE2AE),
    onSecondaryContainer: Color(0xFF38290A),
    tertiary: Color(0xFF45624E),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFC7E8D0),
    onTertiaryContainer: Color(0xFF102017),
    surfaceContainerHighest: Color(0xFFECE2D8),
    onSurfaceVariant: Color(0xFF54433A),
    outline: Color(0xFF85736A),
    outlineVariant: Color(0xFFD8C2B5),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF382D26),
    onInverseSurface: Color(0xFFFFEEE2),
    inversePrimary: Color(0xFFFFB68C),
    surfaceTint: Color(0xFF9F3516),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: baseScheme,
    scaffoldBackgroundColor: baseScheme.surface,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Color(0xFF231710),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: baseScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: baseScheme.primary, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
