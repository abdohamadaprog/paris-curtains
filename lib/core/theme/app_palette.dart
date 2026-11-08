import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// لوحة الألوان الموحدة للتطبيق (لايت + دارك).
///
/// كل الصفحات تقرأ منها بدل ما تكتب ألوان ثابتة، فالتطبيق كله
/// بيتحول مرة واحدة مع الثيم من غير ما حاجة تفضل بلون قديم.
class AppPalette {
  AppPalette._();

  static bool _dark = true;

  /// بيتحدّث تلقائيًا من MaterialApp.builder (شوف app.dart).
  static void setBrightness(Brightness b) => _dark = b == Brightness.dark;

  static bool get isDark => _dark;

  // --- الأسطح ---
  static Color get bg => _dark ? const Color(0xFF0F172A) : AppColors.background;
  static Color get panel => _dark ? const Color(0xFF1E293B) : Colors.white;
  static Color get panel2 =>
      _dark ? const Color(0xFF273449) : AppColors.bgCreamy;
  static Color get line =>
      _dark ? const Color(0xFF334155) : const Color(0xFFE6DDCB);

  // --- النصوص ---
  static Color get text =>
      _dark ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
  static Color get muted =>
      _dark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

  /// لون النص/الأيقونة فوق خلفية ملونة (ذهبي/أخضر/أحمر) — أبيض في الوضعين.
  static const Color onAccent = Colors.white;

  // --- الهوية والحالات ---
  static Color get gold =>
      _dark ? AppColors.primaryGold : const Color(0xFFA67C3A);
  static Color get goldLight => _dark ? AppColors.lightGold : AppColors.goldDeep;
  static Color get green =>
      _dark ? const Color(0xFF10B981) : const Color(0xFF0E9F6E);
  static Color get red =>
      _dark ? const Color(0xFFE57373) : const Color(0xFFD64545);
  static Color get orange =>
      _dark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  static Color get sky =>
      _dark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
  static Color get violet =>
      _dark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);

  // --- ألوان كارت المقاسات (أزرق/أصفر/نعناع) بنسخة لكل ثيم ---
  static Color get cyan =>
      _dark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490);
  static Color get cyanDeep =>
      _dark ? const Color(0xFF06B6D4) : const Color(0xFF0891B2);
  static Color get cyanLight =>
      _dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490);
  static Color get amber =>
      _dark ? const Color(0xFFFFD45A) : const Color(0xFFB45309);
  static Color get amberSoft =>
      _dark ? const Color(0xFFFFE082) : const Color(0xFF92400E);
  static Color get skyLight =>
      _dark ? const Color(0xFF70D6FF) : const Color(0xFF0369A1);
  static Color get mint =>
      _dark ? const Color(0xFF8AE9C1) : const Color(0xFF047857);
  static Color get mintSoft =>
      _dark ? const Color(0xFF98E2A8) : const Color(0xFF166534);
  static Color get redStrong =>
      _dark ? const Color(0xFFFF5252) : const Color(0xFFC62828);
  static Color get amberStrong =>
      _dark ? const Color(0xFFFFC107) : const Color(0xFFB45309);

  /// خلفيات داخلية (حقول، رسمة البلكونة، أسطح متداخلة).
  static Color get inset =>
      _dark ? const Color(0xFF080B12) : const Color(0xFFF3EEE2);
  static Color get insetAlt =>
      _dark ? const Color(0xFF161E2E) : const Color(0xFFF7F2E7);
  static Color get insetChip =>
      _dark ? const Color(0xFF131826) : const Color(0xFFEFE8D8);
  static Color get cardTop =>
      _dark ? const Color(0xFF26354B) : const Color(0xFFFFFFFF);
  static Color get successBg =>
      _dark ? const Color(0xFF163820) : const Color(0xFFE3F4E8);
  static Color get scrim =>
      _dark ? const Color(0x99111827) : const Color(0xCCFFFFFF);

  /// نص ثانوي / كريمي على الأسطح.
  static Color get textSoft =>
      _dark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563);
  static Color get cream =>
      _dark ? const Color(0xFFF1E6D2) : const Color(0xFF1F2937);
}
