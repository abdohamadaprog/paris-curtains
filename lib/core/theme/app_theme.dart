import 'package:flutter/material.dart';
import 'package:paris_curtains/core/constants/app_colors.dart';

class AppTheme {
  static const _radius = BorderRadius.all(Radius.circular(14));

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color text,
    required Color muted,
    required Color line,
    required Color gold,
    required Color secondary,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGold,
      brightness: brightness,
    ).copyWith(
      primary: gold,
      secondary: secondary,
      surface: surface,
      onSurface: text,
      outline: line,
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      canvasColor: bg,
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: brightness == Brightness.dark ? 0 : 3,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: brightness == Brightness.dark
              ? BorderSide(color: line)
              : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
        border: border(line),
        enabledBorder: border(line),
        focusedBorder: border(gold, 1.6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          color: text,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(iconColor: gold, textColor: text),
    );
  }

  static ThemeData lightTheme = _build(
    brightness: Brightness.light,
    bg: AppColors.background,
    surface: Colors.white,
    text: const Color(0xFF1F2937),
    muted: const Color(0xFF6B7280),
    line: const Color(0xFFE6DDCB),
    gold: const Color(0xFFA67C3A),
    secondary: AppColors.navyDark,
  );

  static ThemeData darkTheme = _build(
    brightness: Brightness.dark,
    bg: AppColors.bgDark,
    surface: AppColors.surfaceDark,
    text: const Color(0xFFF1F5F9),
    muted: const Color(0xFF94A3B8),
    line: const Color(0xFF334155),
    gold: AppColors.primaryGold,
    secondary: AppColors.lightGold,
  );
}
