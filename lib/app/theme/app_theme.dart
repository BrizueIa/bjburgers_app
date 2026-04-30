import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1F1A14),
    onPrimary: Color(0xFFFFFBF6),
    secondary: Color(0xFFC98B2E),
    onSecondary: Color(0xFF201405),
    error: Color(0xFFB3261E),
    onError: Colors.white,
    surface: Color(0xFFF5F1EA),
    onSurface: Color(0xFF171411),
    primaryContainer: Color(0xFFEEE7DC),
    onPrimaryContainer: Color(0xFF1F1A14),
    secondaryContainer: Color(0xFFF2DFC0),
    onSecondaryContainer: Color(0xFF2F1B04),
    tertiary: Color(0xFF6D4C25),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFE5D4C0),
    onTertiaryContainer: Color(0xFF2D0D02),
    surfaceContainerHighest: Color(0xFFE7E1D8),
    onSurfaceVariant: Color(0xFF5C554D),
    outline: Color(0xFF8B8277),
    outlineVariant: Color(0xFFD9D1C6),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF241F19),
    onInverseSurface: Color(0xFFF9F5EF),
    inversePrimary: Color(0xFFF0D7A5),
    surfaceTint: Color(0xFF1F1A14),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8),
      displayMedium: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
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
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 15, height: 1.22),
      bodyMedium: TextStyle(fontSize: 14, height: 1.22),
      bodySmall: TextStyle(fontSize: 12, height: 1.2),
      labelLarge: TextStyle(fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Color(0xFFF5F1EA),
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Color(0xFF171411),
      toolbarHeight: 56,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF171411),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFFFFFCF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4DDD3)),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFFFFCF8),
      indicatorColor: const Color(0xFFEEE7DC),
      height: 68,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? const Color(0xFF171411)
              : const Color(0xFF6C645B),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? const Color(0xFF171411)
              : const Color(0xFF6C645B),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1F1A14),
        foregroundColor: const Color(0xFFFFFBF6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1F1A14),
        side: const BorderSide(color: Color(0xFFD8D0C4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF1F1A14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFFCF8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD9D1C6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1F1A14), width: 1.4),
      ),
      floatingLabelStyle: const TextStyle(color: Color(0xFF1F1A14)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: const Color(0xFFEEE7DC),
      labelStyle: const TextStyle(
        color: Color(0xFF1F1A14),
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
    listTileTheme: const ListTileThemeData(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFFFFFCF8),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFDAD2C7)),
  );
}
