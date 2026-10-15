import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // منع إنشاء Instances

  // --- الهوية الأساسية ---
  static const Color primaryGold = Color(0xFFC7A064);
  static const Color lightGold = Color(0xFFEBC98E);
  static const Color navyDark = Color(0xFF1A237E);
  static const Color darkText = Color(0xFF333333);

  // --- الخلفيات ---
  static const Color background = Color(0xFFFDFCF8); // (bgOffWhite) وحدنا الاسم
  static const Color cardBlue = Color(0xFFE0F7FA);
  static const Color teal = Colors.teal;
  static const Color bgCreamy = Color(0xFFF4EFE6);
  static const Color bgDark = Color(0xFF101018);

  // --- ألوان النيون (للأدمن) ---
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonOrange = Color(0xFFFF9100);
  static const Color neonGold = Color(0xFFFFD700);
  static const Color neonGreen = Color(0xFF00E676);
  static const Color neonRed = Color(0xFFFF1744);
  static const Color neonPurple = Color(0xFFD500F9);
  static const Color saveBtn = Color(0xFFD4AF37);

  // --- شفافيات (تم تحويلها لـ const لأداء أفضل) ---
  // 0.08 opacity = 14 Hex | 0.6 opacity = 99 Hex
  static const Color glassWhite = Color(0x14FFFFFF);
  static const Color glassDark = Color(0x99000000);
}
