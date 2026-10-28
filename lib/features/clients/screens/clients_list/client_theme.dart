part of '../clients_list_page.dart';

const Color _gold = AppColors.primaryGold;

// مراحل الشغل (لون نيون لكل مرحلة)
const Map<int, Color> _stageColors = {
  1: Color(0xFFFF4D5E), // أحمر: بدأنا الشغل
  2: Color(0xFFFFD43B), // أصفر: جاري التحضير
  3: Color(0xFF38BDF8), // أزرق: تم التخريم وموافقين على التركيب
  4: Color(0xFF22E58B), // أخضر: تمت
};

const Map<int, String> _stageLabels = {
  1: 'بدأنا الشغل',
  2: 'جاري التحضير',
  3: 'تم التخريم وجاهز للتركيب',
  4: 'تمت وتم التركيب',
};

int _stageOf(Map<String, dynamic> data) {
  final raw = data['work_stage'];
  if (raw is num) return raw.toInt().clamp(1, 4);
  return data['installation_done'] == true ? 4 : 1;
}
