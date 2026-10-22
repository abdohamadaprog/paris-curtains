import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- الهوية الأساسية (المرجع الوحيد لكل الصفحات) ---
  static const Color primaryGold = Color(0xFFC7A064);
  static const Color lightGold = Color(0xFFEBC98E);
  static const Color navyDark = Color(0xFF1A237E);
  static const Color darkText = Color(0xFF333333);

  // --- الخلفيات ---
  static const Color background = Color(0xFFFDFCF8);
  static const Color cardBlue = Color(0xFFE0F7FA);
  static const Color teal = Color(0xFF3D6B6B);
  static const Color bgCreamy = Color(0xFFF4EFE6);
  static const Color bgDark = Color(0xFF101018);
  static const Color surfaceDark = Color(0xFF1A1B23);
  static const Color surfaceDark2 = Color(0xFF24252E);

  // --- حالات ---
  static const Color success = Color(0xFF72C69A);
  static const Color danger = Color(0xFFE57373);
  static const Color saveBtn = primaryGold;

  // أسماء قديمة متوافقة مع الكود الحالي، كلها تتبع ستايل الذهب
  static const Color neonGold = lightGold;
  static const Color neonCyan = lightGold;
  static const Color neonOrange = primaryGold;
  static const Color neonGreen = success;
  static const Color neonRed = danger;
  static const Color neonPurple = primaryGold;

  // --- تدرج الذهب الفاخر (للعناوين والأزرار والإطارات) ---
  static const Color goldDeep = Color(0xFF9A7338);
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightGold, primaryGold, goldDeep],
  );

  static const Color glassWhite = Color(0x14FFFFFF);
  static const Color glassDark = Color(0x99000000);
}
