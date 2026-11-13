// تستات قواعد الحساب الأساسية (مصدر الحقيقة = invoice_calculator.dart).
//
// الهدف: أي تعديل في الأرقام بعد كده يكسر تست، مش يكسر فاتورة عميل.
// كل تست مكتوب فيه القاعدة اللي بيحميها من التعليق في الكود الأصلي.

import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtains/features/clients/invoice/invoice_calculator.dart';

/// كل بنود الفاتورة في خريطة بالمفتاح (فabric + accessories).
Map<String, InvoiceLine> _lines(List<InvoiceLine> fabric, List<InvoiceLine> acc) {
  return {
    for (final l in fabric) l.key: l,
    for (final l in acc) l.key: l,
  };
}

Map<String, InvoiceLine> _apt(ApartmentInvoice inv) =>
    _lines(inv.fabricLines, inv.accessoryLines);

Map<String, InvoiceLine> _balc(BalconyInvoice inv) =>
    _lines(inv.fabricLines, inv.accessoryLines);

double _sum(List<InvoiceLine> lines) =>
    lines.fold(0.0, (total, line) => total + line.total);

WindowSpec _wave(
  double width, {
  bool heavy = true,
  bool light = false,
  double? heavyWidth,
  double? lightWidth,
  double? heavyRatio,
  double? lightRatio,
  bool blackout = false,
  String blackoutType = 'fabric_blackout3d',
}) {
  return WindowSpec(
    width: width,
    curtainType: 'wave',
    hasHeavy: heavy,
    hasLight: light,
    heavyWidth: heavyWidth,
    lightWidth: lightWidth,
    heavyRatio: heavyRatio,
    lightRatio: lightRatio,
    hasBlackout: blackout,
    blackoutType: blackoutType,
  );
}

WindowSpec _press(
  double width, {
  bool heavy = true,
  bool light = false,
}) {
  return WindowSpec(
    width: width,
    curtainType: 'press',
    hasHeavy: heavy,
    hasLight: light,
  );
}

WindowSpec _doubleWave(
  double width, {
  bool heavy = true,
  bool light = false,
}) {
  return WindowSpec(
    width: width,
    curtainType: 'double_wave',
    hasHeavy: heavy,
    hasLight: light,
  );
}

BalconySpec _balcony({
  required double width,
  List<double> parts = const [],
  int avez = 0,
  bool enabled = true,
}) {
  return BalconySpec(
    width: width,
    parts: parts,
    avezCount: avez,
    enabled: enabled,
  );
}

void main() {
  // ==========================================================================
  // أدوات التحويل والأرقام
  // ==========================================================================
  group('تحويل الأرقام والتقريب', () {
    test('الأرقام العربية والفاصلة العربية بتتحول صح', () {
      expect(normalizeDigits('١٢٫٥'), '12.5');
      expect(normalizeDigits('٣،٢'), '3.2');
      expect(parseNumber('١٢٣'), 123);
      expect(parseNumber(null), 0);
      expect(parseNumber('مش رقم'), 0);
    });

    test('ceilMeters بيقرّب لأعلى لمتر كامل وينضف أخطاء الفاصلة', () {
      expect(ceilMeters(2.0), 2);
      expect(ceilMeters(2.01), 3);
      // ٢٫٠٠١ مش ٢٫١: التنضيف بيرجّعها ٢ مش ٣
      expect(ceilMeters(2.001), 2);
      expect(ceilMeters(2.999), 3);
      expect(ceilMeters('٢٫٣'), 3);
      expect(ceilMeters(null), 0);
      expect(ceilMeters(0), 0);
    });

    test('roundMoney بيقرّب لأقرب قرش', () {
      expect(roundMoney(12.344), 12.34);
      expect(roundMoney(12.346), 12.35);
      expect(roundMoney(null), 0);
    });
  });

  // ==========================================================================
  // حوامل تراك الويفي
  // ==========================================================================
  group('عدد حوامل تراك الويفي', () {
    test('حتى 1م = 2 حامل', () {
      expect(calcWaveHoldersForWindow(0.8), 2);
      expect(calcWaveHoldersForWindow(1.0), 2);
    });

    test('أكبر من 1م وحتى 2.5م = 3 حوامل', () {
      expect(calcWaveHoldersForWindow(1.01), 3);
      expect(calcWaveHoldersForWindow(2.5), 3);
    });

    test('أكبر من 2.5م = 3 + حامل لكل متر زيادة', () {
      expect(calcWaveHoldersForWindow(2.51), 4);
      expect(calcWaveHoldersForWindow(3.5), 4);
      expect(calcWaveHoldersForWindow(4.5), 5);
    });

    test('عرض صفر أو سالب = صفر حوامل', () {
      expect(calcWaveHoldersForWindow(0), 0);
      expect(calcWaveHoldersForWindow(-1), 0);
    });
  });

  // ==========================================================================
  // ويفي عادي
  // ==========================================================================
  group('ويفي عادي', () {
    test('ثقيل + خفيف: خفيف ×2 وثقيل ×3 والتراك لكل طبقة', () {
      final inv = calculateApartmentInvoice(
        windows: [_wave(2.0, light: true)],
      );
      final l = _apt(inv);

      expect(l['fabric_linen']!.qty, 4); // 2 × 2
      expect(l['fabric_linen']!.unitPrice, 130);
      expect(l['fabric_velvet']!.qty, 6); // 2 × 3
      expect(l['fabric_velvet']!.unitPrice, 150);

      // مسار لكل طبقة: 2 + 2
      expect(l['track']!.qty, 4);
      expect(l['track']!.unitPrice, 75);

      // الحوامل على أوسع طبقة (2م → 3)
      expect(l['holder_wave']!.qty, 3);

      // شريط + تجهيز الويفي = أمتار قماش الثقيل
      expect(l['wave_tape']!.qty, 6);
      expect(l['wave_prep']!.qty, 6);

      // الكسرات على الكتان الخلفي فقط
      expect(l['kasrat']!.qty, 4);

      // الخياطة على الأمتار المقرّبة
      expect(l['sew_light']!.qty, 4);
      expect(l['sew_heavy']!.qty, 6);

      // تركيب لكل شباك
      expect(l['install_window']!.qty, 1);
    });

    test('خفيف لوحده: الشريط بيتبع الخفيف ومفيش كسرات', () {
      final inv = calculateApartmentInvoice(
        windows: [_wave(2.0, heavy: false, light: true)],
      );
      final l = _apt(inv);

      expect(l.containsKey('fabric_velvet'), isFalse);
      expect(l['fabric_linen']!.qty, 4);
      expect(l['wave_tape']!.qty, 4); // 2 × 2
      expect(l['kasrat'], isNull); // الكسرات بتحتاج ثقيل + خفيف
    });

    test('التقريب مرة واحدة على إجمالي الشقة مش لكل شباك', () {
      final inv = calculateApartmentInvoice(
        windows: [
          _wave(1.6, heavy: false, light: true),
          _wave(1.6, heavy: false, light: true),
        ],
      );
      // 1.6 × 2 × 2 شباك = 6.4 → 7 (لو اتقرّب لكل شباك كان 4+4=8)
      expect(_apt(inv)['fabric_linen']!.qty, 7);
    });

    test('الشباك المتعطّل أو العرض صفر مش داخل في الحساب', () {
      final inv = calculateApartmentInvoice(
        windows: [
          _wave(2.0, heavy: false, light: true),
          WindowSpec(width: 0, curtainType: 'wave'),
          WindowSpec(width: 2.0, curtainType: 'wave', enabled: false),
        ],
      );
      final l = _apt(inv);
      expect(l['install_window']!.qty, 1);
      expect(l['fabric_linen']!.qty, 4);
    });

    test('مثال الـ 6 شبابيك المعتمد = 14925', () {
      final windows = List.generate(
        6,
        (i) => WindowSpec(
          title: 'شباك ${i + 1}',
          width: 1.75,
          height: 2.8,
          curtainType: 'wave',
          hasHeavy: true,
          hasLight: true,
        ),
      );
      final inv = calculateApartmentInvoice(windows: windows);
      expect(inv.grandTotal, 14925);
      expect(_sum(inv.fabricLines), 7530);
    });
  });

  // ==========================================================================
  // دابل ويفي
  // ==========================================================================
  group('دابل ويفي', () {
    test('الطبقتين ×3، الحامل دابل، ومفيش كسرات', () {
      final inv = calculateApartmentInvoice(
        windows: [_doubleWave(2.0, light: true)],
      );
      final l = _apt(inv);

      expect(l['fabric_linen']!.qty, 6); // 2 × 3
      expect(l['fabric_velvet']!.qty, 6);
      expect(l['track']!.qty, 4);
      expect(l['holder_double']!.qty, 3);
      expect(l['holder_double']!.unitPrice, 55);
      expect(l.containsKey('holder_wave'), isFalse);

      // الشريط على الطبقتين: 6 + 6
      expect(l['wave_tape']!.qty, 12);
      expect(l['wave_prep']!.qty, 12);

      // الكسرات خاصة بالويفي العادي بس
      expect(l['kasrat'], isNull);
      expect(l['sew_light']!.qty, 6);
      expect(l['sew_heavy']!.qty, 6);
    });
  });

  // ==========================================================================
  // كبس (حلقات)
  // ==========================================================================
  group('كبس', () {
    test('ثقيل لوحده: ×2.5 وماسورة وكابولي وقمقم وحلقات', () {
      final inv = calculateApartmentInvoice(windows: [_press(3.2)]);
      final l = _apt(inv);

      expect(l['fabric_velvet']!.qty, 8); // 3.2 × 2.5
      expect(l['pipe_press']!.qty, 3.2);

      // أوسع من 3م → 3 كوابيل
      expect(l['cantilever_forgia']!.qty, 3);
      // ماسورة واحدة → 2 قمقم
      expect(l['qamqam_forgia']!.qty, 2);

      // شريط الكبس = أمتار القماش
      expect(l['press_tape']!.qty, 8);
      // حلقات = ceil(أمتار الشريط × 7)
      expect(l['ring_unit']!.qty, 56);
      expect(l['press_drill']!.qty, 56);

      expect(l['sew_heavy']!.qty, 8);
      expect(l.containsKey('wave_tape'), isFalse);
      expect(l.containsKey('track'), isFalse);
    });

    test('3م بالظبط = 2 كابولي (الحد شامل)', () {
      final inv = calculateApartmentInvoice(windows: [_press(3.0)]);
      expect(_apt(inv)['cantilever_forgia']!.qty, 2);
    });

    test('أكبر من 3م بشوية = 3 كوابيل', () {
      final inv = calculateApartmentInvoice(windows: [_press(3.01)]);
      expect(_apt(inv)['cantilever_forgia']!.qty, 3);
    });

    test('ثقيل + خفيف: ماسورتين وقمقم 4 والشريط على الطبقتين', () {
      final inv = calculateApartmentInvoice(
        windows: [_press(2.0, light: true)],
      );
      final l = _apt(inv);

      expect(l['fabric_linen']!.qty, 4); // 2 × 2
      expect(l['fabric_velvet']!.qty, 5); // 2 × 2.5
      expect(l['pipe_press']!.qty, 4); // ماسورة لكل طبقة
      expect(l['qamqam_forgia']!.qty, 4); // 2 لكل ماسورة
      // ملاحظة: الكابولي للشباك ككل مش لكل ماسورة (سلوك حالي)
      expect(l['cantilever_forgia']!.qty, 2);
      expect(l['press_tape']!.qty, 9); // 5 + 4
      expect(l['ring_unit']!.qty, 63); // ceil(9 × 7)
    });

    test('الحلقات بتتقرّب لأعلى بعد الضرب في 7', () {
      final inv = calculateApartmentInvoice(windows: [_press(1.0)]);
      // شريط الكبس = 1 × 2.5 = 2.5م → الحلقات = ceil(2.5 × 7) = 18
      expect(_apt(inv)['press_tape']!.qty, 3);
      expect(_apt(inv)['ring_unit']!.qty, 18);
    });
  });

  // ==========================================================================
  // الاستثناءات (عرض أو نسبة مخصّصة)
  // ==========================================================================
  group('استثناءات القماش', () {
    test('عرض ونسبة مخصّصين بيغيّروا الأمتار ويظهر تعليق استثناء', () {
      final inv = calculateApartmentInvoice(
        windows: [
          WindowSpec(
            width: 3.0,
            curtainType: 'wave',
            hasHeavy: true,
            hasLight: false,
            heavyWidth: 2.0,
            heavyRatio: 1.5,
          ),
        ],
      );
      final line = _apt(inv)['fabric_velvet']!;
      expect(line.qty, 3); // 2 × 1.5
      expect(line.note, contains('استثناء'));
    });

    test('الثقيل متعطّل: مفيش بند قطيفة خالص', () {
      final inv = calculateApartmentInvoice(
        windows: [
          WindowSpec(
            width: 2.0,
            curtainType: 'wave',
            hasHeavy: false,
            hasLight: true,
          ),
        ],
      );
      final l = _apt(inv);
      expect(l.containsKey('fabric_velvet'), isFalse);
      expect(l.containsKey('sew_heavy'), isFalse);
      expect(l['fabric_linen']!.qty, 4);
    });
  });

  // ==========================================================================
  // بلاك أوت
  // ==========================================================================
  group('بلاك أوت', () {
    test('طبقة إضافية بتشارك التراك وبتتقاس لوحدها', () {
      final inv = calculateApartmentInvoice(
        windows: [_wave(1.5, blackout: true)],
      );
      final l = _apt(inv);

      expect(l['fabric_blackout3d']!.qty, 2); // ceil(1.5 × 1)
      expect(l['fabric_blackout3d']!.unitPrice, 110);
      expect(l['track']!.qty, 1.5); // التراك على الطبقات اللي ليها تراك
      expect(l['sew_blackout']!.qty, 2);
      expect(l['sew_blackout']!.unitPrice, 25);
    });

    test('بلاك أوت لوحده بياخد تراك بعرضه', () {
      final inv = calculateApartmentInvoice(
        windows: [
          WindowSpec(
            width: 2.0,
            curtainType: 'wave',
            hasHeavy: false,
            hasLight: false,
            hasBlackout: true,
          ),
        ],
      );
      final l = _apt(inv);

      expect(l['track']!.qty, 2);
      expect(l['fabric_blackout3d']!.qty, 2);
      // سلوك حالي: الحوامل بتتحسب على أوسع طبقة حتى لو مفيش قماش ويفي
      expect(l['holder_wave']!.qty, 3);
      expect(l.containsKey('wave_tape'), isFalse);
      expect(l.containsKey('fabric_linen'), isFalse);
    });

    test('بلاك أوت عازل للشمس ليه سعره وبنده المختلف', () {
      final inv = calculateApartmentInvoice(
        windows: [
          _wave(1.5, blackout: true, blackoutType: 'fabric_blackout_sun'),
        ],
      );
      final l = _apt(inv);
      expect(l['fabric_blackout_sun']!.unitPrice, 170);
      expect(l.containsKey('fabric_blackout3d'), isFalse);
    });
  });

  // ==========================================================================
  // الأسعار
  // ==========================================================================
  group('الأسعار', () {
    tearDown(PriceOverrides.clear);

    test('السعر المخصّص للفاتورة بيغطي الافتراضي', () {
      final inv = calculateApartmentInvoice(
        windows: [_wave(2.0, light: true)],
        customPrices: {'fabric_velvet': 200, 'track': 90},
      );
      final l = _apt(inv);
      expect(l['fabric_velvet']!.unitPrice, 200);
      expect(l['track']!.unitPrice, 90);
      expect(l['fabric_linen']!.unitPrice, 130); // الباقي زي ما هو
    });

    test('الثوابت العامة بتتطبق على كل الفواتير', () {
      PriceOverrides.set({'fabric_linen': 160});
      final inv = calculateApartmentInvoice(
        windows: [_wave(2.0, light: true)],
      );
      expect(_apt(inv)['fabric_linen']!.unitPrice, 160);
      expect(defaultPrices()['fabric_linen'], 160);
    });

    test('السعر المخصّص للفاتورة أقوى من الثوابت العامة', () {
      PriceOverrides.set({'fabric_linen': 160});
      final inv = calculateApartmentInvoice(
        windows: [_wave(2.0, light: true)],
        customPrices: {'fabric_linen': 99},
      );
      expect(_apt(inv)['fabric_linen']!.unitPrice, 99);
    });

    test('بنود يدوية: النقل دايماً موجود والكوبشة بـ50ج للشباك الخلفي', () {
      final inv = calculateApartmentInvoice(
        windows: [_wave(2.0, light: true)],
      );
      final l = _apt(inv);
      expect(l['kobsha']!.qty, 1);
      expect(l['kobsha']!.unitPrice, 50);
      expect(l['kobsha']!.total, 50);
      expect(l['transport']!.qty, 1);
      expect(l['transport']!.unitPrice, 0);
    });

    test('الكوبشة = عدد الشبابيك اللي فيها طبقة خلفية في كل الأنظمة', () {
      final inv = calculateApartmentInvoice(
        windows: [
          _wave(2.0, light: true), // خلفية → كوبشة
          _wave(2.0), // ثقيل لوحده → مفيش
          _doubleWave(2.0, light: true), // خلفية → كوبشة
          _press(2.0, light: true), // خلفية → كوبشة
          _press(2.0), // ثقيل لوحده → مفيش
        ],
      );
      expect(_apt(inv)['kobsha']!.qty, 3);
    });

    test('مفيش طبقة خلفية خالص = مفيش بند كوبشة', () {
      final inv = calculateApartmentInvoice(windows: [_press(2.0)]);
      expect(_apt(inv).containsKey('kobsha'), isFalse);
    });

    test('إجمالي الفاتورة = مجموع البنود مقرّب', () {
      final inv = calculateApartmentInvoice(
        windows: [_wave(2.0, light: true)],
      );
      expect(
        inv.grandTotal,
        _sum(inv.fabricLines) + _sum(inv.accessoryLines),
      );
    });
  });

  // ==========================================================================
  // البلكونة
  // ==========================================================================
  group('البلكونة', () {
    test('القماش = إجمالي العرض × 1.5 والماسورة = العرض والشريط = القماش', () {
      final inv = calculateBalconyInvoice(
        balconies: [_balcony(width: 5.0, parts: [3.0, 2.0])],
        fabricKey: 'fabric_dak',
      );
      final l = _balc(inv);

      expect(l['fabric_dak']!.qty, 7.5);
      expect(l['fabric_dak']!.unitPrice, 100);
      expect(l['balc_pipe']!.qty, 5.0);
      expect(l['balc_tape']!.qty, 7.5);
      expect(l['balc_sew']!.qty, 7.5);
    });

    test('الأفيز لكل ضلع: أقل من 3م = 2 و3م أو أكتر = 3', () {
      final inv = calculateBalconyInvoice(
        balconies: [
          _balcony(width: 5.0, parts: [3.0, 2.0]),
        ],
        fabricKey: 'fabric_dak',
      );
      expect(_balc(inv)['balc_avez']!.qty, 5); // 3 + 2
    });

    test('الرقم اليدوي للأفيز بيغطي الحساب التلقائي', () {
      final inv = calculateBalconyInvoice(
        balconies: [_balcony(width: 5.0, parts: [3.0, 2.0], avez: 7)],
        fabricKey: 'fabric_dak',
      );
      expect(_balc(inv)['balc_avez']!.qty, 7);
    });

    test('حلقات البلكونة = ceil(أمتار القماش × 6)', () {
      final inv = calculateBalconyInvoice(
        balconies: [_balcony(width: 5.0, parts: [3.0, 2.0])],
        fabricKey: 'fabric_dak',
      );
      // 7.5 × 6 = 45
      expect(_balc(inv)['ring_unit']!.qty, 45);
      expect(_balc(inv)['press_drill']!.qty, 45);
    });

    test('أكتر من بلكونة: الأمتار والقماش بيتجمعوا', () {
      final inv = calculateBalconyInvoice(
        balconies: [_balcony(width: 3.0), _balcony(width: 3.0)],
        fabricKey: 'fabric_dak',
      );
      final l = _balc(inv);
      expect(l['fabric_dak']!.qty, 9); // (3+3) × 1.5
      expect(l['balc_pipe']!.qty, 6);
    });

    test('تركيب البلكونة بعدد البلكونات الشغالة', () {
      final inv = calculateBalconyInvoice(
        balconies: [_balcony(width: 3.0), _balcony(width: 3.0)],
        fabricKey: 'fabric_dak',
      );
      // السعر الافتراضي 0، فالكمية بس هي اللي بتتأكد هنا
      expect(_balc(inv)['balc_install']!.qty, 2);
    });

    test('البلكونة المتعطّلة مش بتتحسب', () {
      final inv = calculateBalconyInvoice(
        balconies: [
          _balcony(width: 3.0),
          _balcony(width: 3.0, enabled: false),
        ],
        fabricKey: 'fabric_dak',
      );
      expect(_balc(inv)['fabric_dak']!.qty, 4.5);
    });

    test('نوع القماش بيغيّر السعر والاسم', () {
      final inv = calculateBalconyInvoice(
        balconies: [_balcony(width: 2.0)],
        fabricKey: 'fabric_blackout_sun',
      );
      final line = _balc(inv)['fabric_blackout_sun']!;
      expect(line.unitPrice, 170);
      expect(line.label, 'بلاك أوت عازل للشمس');
    });

    test('fromMap بيقرا الأضلاع من النص ويجمع العرض', () {
      final spec = BalconySpec.fromMap({'parts': '3+2.5', 'height': 2.8});
      expect(spec.parts, [3.0, 2.5]);
      expect(spec.width, 5.5);

      final inv = calculateBalconyInvoice(
        balconies: [spec],
        fabricKey: 'fabric_dak',
      );
      expect(_balc(inv)['fabric_dak']!.qty, 8.25);
    });

    test('من غير أضلاع: العرض هو الضلع الوحيد', () {
      final spec = BalconySpec.fromMap({'width': 4.0});
      expect(spec.parts, [4.0]);
      expect(spec.width, 4.0);
    });
  });
}
