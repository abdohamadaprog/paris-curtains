import 'package:flutter/material.dart';

class AppTheme {
  static const Color teal = Color(0xFF20B7B0);
  static const Color navy = Color(0xFF101827);
  static const Color gold = Color(0xFFC9A45C);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF7F7F5),
    colorScheme: ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF7F7F5),
      foregroundColor: navy,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(elevation: 1, margin: EdgeInsets.zero),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF101116),
    colorScheme: ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF101116),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(elevation: 1, margin: EdgeInsets.zero),
  );
}
