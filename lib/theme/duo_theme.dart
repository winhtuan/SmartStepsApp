import 'package:flutter/material.dart';

class DuoColors {
  const DuoColors._();

  static const primaryYellow = Color(0xFFFFC928);
  static const darkYellow = Color(0xFFE5A900);
  static const background = Color(0xFFFFF8E1);
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2D2D2D);
  static const textSecondary = Color(0xFF777777);
  static const success = Color(0xFF58CC02);
  static const lockedGray = Color(0xFFD9D9D9);
  static const softYellow = Color(0xFFFFF0A8);
  static const border = Color(0xFFFFE082);
}

class DuoTheme {
  const DuoTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: DuoColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DuoColors.primaryYellow,
        brightness: Brightness.light,
        primary: DuoColors.primaryYellow,
        secondary: DuoColors.success,
        surface: DuoColors.card,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(
          color: DuoColors.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          height: 1.05,
        ),
        titleLarge: const TextStyle(
          color: DuoColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          height: 1.08,
        ),
        titleMedium: const TextStyle(
          color: DuoColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
        bodyMedium: const TextStyle(
          color: DuoColors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: DuoColors.primaryYellow,
          foregroundColor: DuoColors.textPrimary,
          disabledBackgroundColor: DuoColors.lockedGray,
          disabledForegroundColor: DuoColors.textSecondary,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
