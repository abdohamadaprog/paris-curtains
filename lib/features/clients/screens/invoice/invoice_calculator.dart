// حسابات فواتير باريس للستائر (ستائر الشقة + البلكونة).
// ملف Dart خالص بدون Flutter عشان نقدر نختبره بسهولة.
//
// القواعد المعتمدة:
//  • ويفي عادي: كتان = عرض × 2 • قطيفة = عرض × 3
//  • دابل ويفي: كتان = عرض × 3 • قطيفة = عرض × 3
//  • حلقات كبس: قطيفة = عرض × 2.5 • كتان = عرض × 2
//  • أمتار القماش بتتقرّب لأعلى لأقرب متر كامل في فاتورة الشقة
//  • البلكونة: قماش = إجمالي المقاسات × 1.5 (من غير تقريب)

/// تقريب لأعلى لأقرب متر كامل بعد تنضيف أخطاء الفاصلة العشرية
int ceilMeters(double v) => ((v * 100).round() / 100).ceil();

double roundMoney(double v) => (v * 100).round() / 100;

/// تحويل الأرقام العربي والفاصلة العربية لنص يقدر double.tryParse يقراه
String normalizeDigits(String s) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = arabic.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b
      .toString()
      .replaceAll('،', '.')
      .replaceAll('٫', '.')
      .replaceAll(',', '.')
      .trim();
}

double parseNumber(String s) => double.tryParse(normalizeDigits(s)) ?? 0;

// ============================ الأسعار ============================

class PriceDef {
  final String key;
  final String label;
  final String unit;
  final double value;

  const PriceDef(this.key, this.label, this.unit, this.value);
}

/// الأسعار والثوابت الافتراضية (قابلة للتعديل من إعدادات الأسعار)
const List<PriceDef> kPriceDefs = [
  PriceDef('fabric_linen', 'كتان خفيف', 'متر', 130),
  PriceDef('fabric_velvet', 'قطيفة / قماش ثقيل', 'متر', 150),
  PriceDef('track', 'مسار ويفي معدني', 'متر', 75),
  PriceDef('holder_wave', 'حامل تراك (ويفي)', 'حامل', 40),
  PriceDef('holder_double', 'حامل تراك (دابل ويفي)', 'حامل', 55),
  PriceDef('wave_tape', 'شريط ويفي كبسولة', 'متر', 55),
  PriceDef('wave_prep', 'تجهيز نظام الويفي', 'متر', 20),
  PriceDef('kasrat', 'شريط تجميع كسرات', 'متر', 15),
  PriceDef('pipe_press', 'ماسورة 4G (كبس الشقة)', 'متر', 70),
  PriceDef('cantilever_forgia', 'كابولي فورجية', 'قطعة', 50),
  PriceDef('qamqam_forgia', 'قمقم فورجية', 'قطعة', 45),
  PriceDef('press_tape', 'شريط كبس (الشقة)', 'متر', 15),
  PriceDef('ring_unit', 'الحلقة الواحدة (كيس 350 ÷ 100)', 'حلقة', 3.5),
  PriceDef('press_drill', 'تخريم الحلقة', 'حلقة', 1.5),
  PriceDef('sew_light', 'خياطة خفيف', 'متر', 25),
  PriceDef('sew_heavy', 'خياطة ثقيل', 'متر', 30),
  PriceDef('install_window', 'تركيب الشباك', 'شباك', 100),
  PriceDef('rings_per_m_apartment', 'حلقات كل متر شريط (الشقة)', 'حلقة', 7),
  PriceDef('rings_per_m_balcony', 'حلقات كل متر شريط (البلكونة)', 'حلقة', 6),
  PriceDef('fabric_dak', 'دك بلكونات', 'متر', 100),
  PriceDef('fabric_blackout3d', 'بلاك أوت 3D', 'متر', 110),
  PriceDef('fabric_blackout_sun', 'بلاك أوت عازل للشمس', 'متر', 170),
  PriceDef('balc_pipe', 'ماسورة 4G (بلكونة)', 'متر', 70),
  PriceDef('balc_tape', 'شريط كبس (بلكونة)', 'متر', 15),
  PriceDef('balc_avez', 'أفيز', 'قطعة', 20),
  PriceDef('balc_sew', 'خياطة بلكونة', 'متر', 30),
];

Map<String, double> defaultPrices() => {
  for (final d in kPriceDefs) d.key: d.value,
};

/// أنواع قماش البلكونة (المفتاح = مفتاح السعر)
const Map<String, String> kBalconyFabrics = {
  'fabric_dak': 'دك بلكونات',
  'fabric_blackout3d': 'بلاك أوت 3D',
  'fabric_blackout_sun': 'بلاك أوت عازل للشمس',
};

// ============================ المدخلات ============================

class WindowSpec {
  final double width;
  final String method; // wave | doubleWave | press
  final bool hasLight;

  const WindowSpec(this.width, this.method, this.hasLight);

  static WindowSpec? fromMap(Map<dynamic, dynamic> m) {
    if (m['enabled'] == false) return null;
    final w = (m['width'] as num?)?.toDouble() ?? 0;
    if (w <= 0) return null;
    final light = ((m['light_layers'] as num?)?.toInt() ?? 0) > 0;
    return WindowSpec(w, (m['method'] ?? 'wave').toString(), light);
  }
}

class BalconySpec {
  final List<double> parts;

  const BalconySpec(this.parts);

  static BalconySpec? fromMap(Map<dynamic, dynamic> m) {
    if (m['enabled'] == false) return null;
    final parts = (m['parts'] ?? '')
        .toString()
        .split('+')
        .map(parseNumber)
        .where((v) => v > 0)
        .toList();
    if (parts.isEmpty) return null;
    return BalconySpec(parts);
  }
}

// ============================ المخرجات ============================

class AutoLine {
  final String key;
  final String name;
  final String unit;
  final String note;
  final double qty;
  final String priceKey;

  /// بند بيتكتب يدوي (كوبشة، نقل، تركيب بلكونة): ما بيتعتبرش ناقص لو كميته 1
  final bool manual;

  const AutoLine({
    required this.key,
    required this.name,
    required this.unit,
    required this.qty,
    required this.priceKey,
    this.note = '',
    this.manual = false,
  });
}

class InvoiceAuto {
  final List<AutoLine> fabric;
  final List<AutoLine> accessories;
  final double totalWidth;
  final int windows;

  const InvoiceAuto(
    this.fabric,
    this.accessories,
    this.totalWidth,
    this.windows,
  );
}

// ============================ ستائر الشقة ============================

InvoiceAuto calcApartment(List<WindowSpec> windows, Map<String, double> p) {
  double totalWidth = 0, heavy = 0, light = 0;
  double waveWidth = 0, doubleWidth = 0, trackM = 0, pipeM = 0;
  double waveLight = 0, prepM = 0, pressTape = 0;
  var cantilevers = 0, qamqam = 0;

  for (final w in windows) {
    final x = w.width;
    totalWidth += x;
    final layers = w.hasLight ? 2 : 1;

    if (w.method == 'press') {
      heavy += 2.5 * x;
      final l = w.hasLight ? 2 * x : 0.0;
      light += l;
      pressTape += 2.5 * x + l;
      pipeM += x * layers;
      cantilevers += x > 3 ? 3 : 2;
      qamqam += 2 * layers;
    } else {
      heavy += 3 * x;
      trackM += x * layers;

      if (w.method == 'doubleWave') {
        final l = w.hasLight ? 3 * x : 0.0;
        light += l;
        doubleWidth += x;
        prepM += 3 * x + l; // شريط وتجهيز على الكتان والقطيفة
      } else {
        final l = w.hasLight ? 2 * x : 0.0;
        light += l;
        waveLight += l;
        waveWidth += x;
        prepM += 3 * x; // على القطيفة بس
      }
    }
  }

  final linen = ceilMeters(light).toDouble();
  final velvet = ceilMeters(heavy).toDouble();
  final tapeQty = ceilMeters(pressTape).toDouble();
  final rings = pressTape > 0
      ? ceilMeters(tapeQty * (p['rings_per_m_apartment'] ?? 7)).toDouble()
      : 0.0;

  final fabric = [
    AutoLine(
      key: 'linen',
      name: 'كتان (خفيف)',
      unit: 'متر',
      qty: linen,
      priceKey: 'fabric_linen',
    ),
    AutoLine(
      key: 'velvet',
      name: 'قطيفة / قماش ثقيل',
      unit: 'متر',
      qty: velvet,
      priceKey: 'fabric_velvet',
    ),
  ];

  final acc = <AutoLine>[
    AutoLine(
      key: 'track',
      name: 'مسار ويفي معدني',
      unit: 'متر',
      qty: ceilMeters(trackM).toDouble(),
      priceKey: 'track',
      note: 'قدام وورا',
    ),
    AutoLine(
      key: 'holder_wave',
      name: 'حوامل تراك (ويفي)',
      unit: 'حامل',
      qty: ceilMeters(2 * waveWidth).toDouble(),
      priceKey: 'holder_wave',
      note: 'كل متر = 2 حامل',
    ),
    AutoLine(
      key: 'holder_double',
      name: 'حوامل تراك (دابل ويفي)',
      unit: 'حامل',
      qty: ceilMeters(2 * doubleWidth).toDouble(),
      priceKey: 'holder_double',
      note: 'كل متر = 2 حامل',
    ),
    AutoLine(
      key: 'wave_tape',
      name: 'شريط ويفي كبسولة',
      unit: 'متر',
      qty: ceilMeters(prepM).toDouble(),
      priceKey: 'wave_tape',
    ),
    AutoLine(
      key: 'wave_prep',
      name: 'تجهيز نظام الويفي',
      unit: 'متر',
      qty: ceilMeters(prepM).toDouble(),
      priceKey: 'wave_prep',
    ),
    AutoLine(
      key: 'kasrat',
      name: 'شريط تجميع كسرات',
      unit: 'متر',
      qty: ceilMeters(waveLight).toDouble(),
      priceKey: 'kasrat',
      note: 'على الكتان (ويفي عادي)',
    ),
    AutoLine(
      key: 'pipe_press',
      name: 'ماسورة 4G (كبس)',
      unit: 'متر',
      qty: ceilMeters(pipeM).toDouble(),
      priceKey: 'pipe_press',
      note: 'قدام وورا',
    ),
    AutoLine(
      key: 'cantilever',
      name: 'كابولي فورجية',
      unit: 'قطعة',
      qty: cantilevers.toDouble(),
      priceKey: 'cantilever_forgia',
      note: 'أقل من أو = 3م: 2 • أكتر: 3',
    ),
    AutoLine(
      key: 'qamqam',
      name: 'قمقم فورجية',
      unit: 'قطعة',
      qty: qamqam.toDouble(),
      priceKey: 'qamqam_forgia',
      note: '2 قدام + 2 ورا',
    ),
    AutoLine(
      key: 'press_tape',
      name: 'شريط كبس',
      unit: 'متر',
      qty: tapeQty,
      priceKey: 'press_tape',
      note: 'على الثقيل والخفيف',
    ),
    AutoLine(
      key: 'rings',
      name: 'حلقات كبس',
      unit: 'حلقة',
      qty: rings,
      priceKey: 'ring_unit',
      note: 'كسر الكيس بيتحسب',
    ),
    AutoLine(
      key: 'drill',
      name: 'تخريم وتركيب حلقات',
      unit: 'حلقة',
      qty: rings,
      priceKey: 'press_drill',
    ),
    const AutoLine(
      key: 'kobsha',
      name: 'كوبشة',
      unit: 'قطعة',
      qty: 1,
      priceKey: 'kobsha',
      note: 'السعر يدوي (100 / 200 / 300)',
      manual: true,
    ),
    AutoLine(
      key: 'install',
      name: 'مصنعية التركيب',
      unit: 'شباك',
      qty: windows.length.toDouble(),
      priceKey: 'install_window',
    ),
    AutoLine(
      key: 'sew_light',
      name: 'خياطة خفيف',
      unit: 'متر',
      qty: linen,
      priceKey: 'sew_light',
    ),
    AutoLine(
      key: 'sew_heavy',
      name: 'خياطة تقيل',
      unit: 'متر',
      qty: velvet,
      priceKey: 'sew_heavy',
    ),
    const AutoLine(
      key: 'transport',
      name: 'موصلات ونقل',
      unit: 'مرة',
      qty: 1,
      priceKey: 'transport',
      note: 'حسب الاتفاق',
      manual: true,
    ),
  ];

  return InvoiceAuto(fabric, acc, totalWidth, windows.length);
}

// ============================ البلكونة ============================

InvoiceAuto calcBalcony(
  List<BalconySpec> balconies,
  String fabricKey,
  Map<String, double> p,
) {
  final parts = [for (final b in balconies) ...b.parts];
  final total = parts.fold<double>(0, (a, b) => a + b);
  final fabricQty = roundMoney(total * 1.5);
  final rings = ceilMeters(
    fabricQty * (p['rings_per_m_balcony'] ?? 6),
  ).toDouble();
  final avez = parts.fold<int>(0, (a, x) => a + (x > 3 ? 3 : 2));

  final fabric = [
    AutoLine(
      key: 'balc_fabric',
      name: kBalconyFabrics[fabricKey] ?? 'قماش بلكونة',
      unit: 'متر',
      qty: fabricQty,
      priceKey: fabricKey,
      note: 'المقاسات × 1.5',
    ),
  ];

  final acc = <AutoLine>[
    AutoLine(
      key: 'balc_pipe',
      name: 'ماسورة 4G',
      unit: 'متر',
      qty: roundMoney(total),
      priceKey: 'balc_pipe',
      note: 'على إجمالي المقاسات',
    ),
    AutoLine(
      key: 'balc_tape',
      name: 'شريط كبس',
      unit: 'متر',
      qty: fabricQty,
      priceKey: 'balc_tape',
      note: 'على كمية القماش',
    ),
    AutoLine(
      key: 'balc_rings',
      name: 'حلقات كبس',
      unit: 'حلقة',
      qty: rings,
      priceKey: 'ring_unit',
      note: 'كسر الكيس بيتحسب',
    ),
    AutoLine(
      key: 'balc_drill',
      name: 'تخريم حلقات',
      unit: 'حلقة',
      qty: rings,
      priceKey: 'press_drill',
    ),
    AutoLine(
      key: 'balc_avez',
      name: 'أفيز',
      unit: 'قطعة',
      qty: avez.toDouble(),
      priceKey: 'balc_avez',
      note: 'أقل من أو = 3م: 2 • أكتر: 3',
    ),
    const AutoLine(
      key: 'balc_install',
      name: 'تركيب بلكونة',
      unit: 'بلكونة',
      qty: 1,
      priceKey: 'balc_install',
      note: 'السعر يدوي (100 / 200 / 300)',
      manual: true,
    ),
    AutoLine(
      key: 'balc_sew',
      name: 'خياطة بلكونة',
      unit: 'متر',
      qty: fabricQty,
      priceKey: 'balc_sew',
    ),
  ];

  return InvoiceAuto(fabric, acc, total, balconies.length);
}
