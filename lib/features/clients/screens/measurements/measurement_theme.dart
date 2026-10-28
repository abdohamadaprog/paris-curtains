part of '../paris_client_measurements_page.dart';

// ألوان وثوابت صفحة المقاسات المشتركة بين كل الملفات
// ألوان وهوية ستائر باريس الملكية مع ثوابت آمنة متوافقة
const Color _gold = AppColors.primaryGold;

const Color _neon = AppColors.lightGold;

const Color _bg = Color(0xFF0F172A);

const Color _panel = Color(0xFF1E293B);

// ألوان إضافية مطابقة لصفحة الفاتورة
const Color _line = Color(0xFF334155);

const Color _muted = Color(0xFF94A3B8);

// ============================================================================
// كارت المقاس: مصغّر في القائمة، وبلمسة واحدة نفس الكارت يكبر (Pop-up)
// ويظهر معاه التعديل، ولما تقفله بيصغر ويرجع مكانه.
// ============================================================================
const double _compactZoom = 0.76;
