import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2E5D3C);
  static const Color primaryDark = Color(0xFF1F4128);
  static const Color primaryContainer = Color(0xFFD5E8D4);
  static const Color accent = Color(0xFFA47148);

  static const Color surface = Color(0xFFFAF7F2);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFE4DCCC);

  static const Color textPrimary = Color(0xFF1F2A24);
  static const Color textSecondary = Color(0xFF5C6A60);
  static const Color textMuted = Color(0xFF94A095);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFC9851A);
  static const Color danger = Color(0xFFB3261E);
}

class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEFE2D2),
      onSecondaryContainer: Color(0xFF5C3D1F),
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceElevated,
      outline: AppColors.outline,
      outlineVariant: Color(0xFFEFE9DC),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: TextStyle(fontSize: 17, color: AppColors.textPrimary, height: 1.4),
        bodyMedium: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
