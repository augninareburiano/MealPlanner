import 'package:flutter/material.dart';

/// FoodGApp branding: an earthy, natural palette — warm cream surfaces, sand
/// tiles, deep pine-green actions, and dark ink text — with soft pill buttons.
/// Applied app-wide from `main`.
class AppTheme {
  const AppTheme._();

  // Brand palette.
  static const Color cream = Color(0xFFF4EFE3); // background / surface
  static const Color sand = Color(0xFFEAE3D3); // cards / tiles
  static const Color pine = Color(0xFF1F4A3D); // primary actions
  static const Color pineDark = Color(0xFF15342A);
  static const Color ink = Color(0xFF201E17); // text
  static const Color terracotta = Color(0xFFBE5B36); // warm accent

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: pine,
      brightness: Brightness.light,
    ).copyWith(
      primary: pine,
      onPrimary: cream,
      primaryContainer: const Color(0xFFCADBCE),
      onPrimaryContainer: pineDark,
      secondary: terracotta,
      onSecondary: cream,
      secondaryContainer: sand,
      onSecondaryContainer: ink,
      surface: cream,
      onSurface: ink,
      onSurfaceVariant: const Color(0xFF5C574B),
      surfaceContainerLowest: const Color(0xFFFBF8F0),
      surfaceContainerLow: const Color(0xFFF0EADC),
      surfaceContainer: sand,
      surfaceContainerHigh: const Color(0xFFE3DBC8),
      surfaceContainerHighest: const Color(0xFFDDD4BF),
      outline: const Color(0xFFB8AE98),
      outlineVariant: const Color(0xFFD8CFBB),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondaryContainer,
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}
