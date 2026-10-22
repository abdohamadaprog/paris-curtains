import 'package:flutter/material.dart';
import 'package:paris_curtian_app/core/constants/app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryGold,
      primary: AppColors.primaryGold,
      secondary: AppColors.navyDark,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.navyDark,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      elevation: 3,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: AppColors.bgDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryGold,
      primary: AppColors.primaryGold,
      secondary: AppColors.lightGold,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      elevation: 3,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
  );
}
