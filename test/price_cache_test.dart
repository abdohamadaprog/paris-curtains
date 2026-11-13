// اختبار: أسعار «ثوابت الحساب» لازم تفضل شغالة وإنت أوفلاين.
// الكاش المحلي (SharedPreferences) بيتقرأ قبل السيرفر، فالتطبيق
// مبيرجعش للأسعار الأصلية لو النت قطع.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:paris_curtains/features/clients/invoice/invoice_calculator.dart';
import 'package:paris_curtains/features/clients/invoice/price_settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PricesRepository.resetForTest);
  tearDown(PriceOverrides.clear);

  test('الأسعار المحفوظة على الجهاز بتشتغل من غير سيرفر', () async {
    SharedPreferences.setMockInitialValues({
      'price_overrides_v1': jsonEncode({
        'fabric_linen': 120,
        'kobsha': 60,
      }),
    });

    // مفيش Firebase في الاختبار = مفيش نت، فلازم يكمّل بالكاش المحلي
    await PricesRepository.ensureLoaded();

    expect(defaultPrices()['fabric_linen'], 120);
    expect(defaultPrices()['kobsha'], 60);
    // الباقي بيرجع للقيمة الأصلية
    expect(defaultPrices()['fabric_velvet'], 150);
  });

  test('لو مفيش كاش محلي: بنكمل بالأسعار الأصلية من غير ما نقع', () async {
    SharedPreferences.setMockInitialValues({});

    await PricesRepository.ensureLoaded();

    expect(defaultPrices()['fabric_linen'], 130);
  });

  test('الكاش المحلي بيتجاهل المفاتيح الغريبة والقيم التالفة', () async {
    SharedPreferences.setMockInitialValues({
      'price_overrides_v1': jsonEncode({
        'fabric_linen': 121,
        'unknown_key': 999,
        'kobsha': -5,
      }),
    });

    await PricesRepository.ensureLoaded();

    expect(defaultPrices()['fabric_linen'], 121);
    expect(defaultPrices().containsKey('unknown_key'), isFalse);
    expect(defaultPrices()['kobsha'], 50);
  });
}
