import 'package:flutter/material.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: brightness,
      primary: AppColors.orange,
      surface: dark ? const Color(0xFF1B1B1B) : AppColors.surface,
    );
    return ThemeData(
      useMaterial3: true,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF111111)
          : AppColors.background,
      fontFamily: 'Arial',
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        fontFamily: 'Arial',
        bodyColor: dark ? Colors.white : AppColors.ink,
        displayColor: dark ? Colors.white : AppColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTypography.title.copyWith(
          color: dark ? Colors.white : AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF1B1B1B) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: dark ? Colors.white12 : AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? Colors.white.withValues(alpha: .06) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(
            color: dark ? Colors.white12 : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF181818) : Colors.white,
        indicatorColor: AppColors.orange.withValues(alpha: .14),
        height: 70,
        labelTextStyle: WidgetStatePropertyAll(AppTypography.meta),
      ),
      dividerColor: dark ? Colors.white12 : AppColors.border,
    );
  }
}
