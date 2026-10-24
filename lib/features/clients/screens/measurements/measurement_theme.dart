part of '../paris_client_measurements_page.dart';

// ألوان وثوابت صفحة المقاسات المشتركة بين كل الملفات
// ألوان وهوية ستائر باريس الملكية مع ثوابت آمنة متوافقة
const Color _gold = AppColors.primaryGold;

const Color _neon = AppColors.lightGold;

const Color _bg = Color(0xFF0C0E14);

const Color _panel = Color(0xFF161622);

// ============================================================================
// كارت المقاس: مصغّر في القائمة، وبلمسة واحدة نفس الكارت يكبر (Pop-up)
// ويظهر معاه التعديل، ولما تقفله بيصغر ويرجع مكانه.
// ============================================================================
const double _compactZoom = 0.76;
