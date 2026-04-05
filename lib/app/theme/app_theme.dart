import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFF28C00),
    onPrimary: Color(0xFF1A1208),
    secondary: Color(0xFFFFB62E),
    onSecondary: Color(0xFF201405),
    error: Color(0xFFB3261E),
    onError: Colors.white,
    surface: Color(0xFFF6EFE5),
    onSurface: Color(0xFF18120D),
    primaryContainer: Color(0xFFFFD27A),
    onPrimaryContainer: Color(0xFF2B1800),
    secondaryContainer: Color(0xFFFFE2A3),
    onSecondaryContainer: Color(0xFF2F1B04),
    tertiary: Color(0xFF7A2E12),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFF0C4AF),
    onTertiaryContainer: Color(0xFF2D0D02),
    surfaceContainerHighest: Color(0xFFE5D6C3),
    onSurfaceVariant: Color(0xFF544539),
    outline: Color(0xFF7E6A59),
    outlineVariant: Color(0xFFD6C0AB),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF21160F),
    onInverseSurface: Color(0xFFFDF0E2),
    inversePrimary: Color(0xFFFFC14D),
    surfaceTint: Color(0xFFF28C00),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -1.0,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(height: 1.3),
      bodyMedium: TextStyle(height: 1.3),
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Color(0xFF18120D),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.88),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0x1AF28C00)),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF15110D),
      indicatorColor: const Color(0xFFF28C00),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? const Color(0xFF1A1208)
              : const Color(0xFFF8E9D2),
          fontWeight: FontWeight.w700,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? const Color(0xFF1A1208)
              : const Color(0xFFF8E9D2),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF28C00),
        foregroundColor: const Color(0xFF1A1208),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF7A2E12),
        side: const BorderSide(color: Color(0xFFCF6B15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE1C8AA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFF28C00), width: 1.6),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: const Color(0xFFFFE2A3),
      labelStyle: const TextStyle(
        color: Color(0xFF2A1705),
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      side: BorderSide.none,
    ),
    dividerTheme: const DividerThemeData(color: Color(0x22A6641A)),
  );
}
