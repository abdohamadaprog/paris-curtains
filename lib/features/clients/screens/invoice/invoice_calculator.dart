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
/// تقبل dynamic بأمان تام لتفادي أي Type Cast Exception لو القيمة null أو double
String normalizeDigits(dynamic val) {
  if (val == null) return '0';
  final s = val.toString();
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

/// قراءة الأرقام بأمان من أي نوع (double, int, String, null)
double parseNumber(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  return double.tryParse(normalizeDigits(val)) ?? 0.0;
}

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
  final String title;
  final double width;
  final double height;
  final String curtainType; // 'wave' | 'double_wave' | 'press'
  final bool hasHeavy;
  final bool hasLight;
  final bool enabled;

  const WindowSpec({
    required this.title,
    required this.width,
    required this.height,
    required this.curtainType,
    required this.hasHeavy,
    required this.hasLight,
    this.enabled = true,
  });

  factory WindowSpec.fromMap(Map<String, dynamic> map) {
    return WindowSpec(
      title: (map['title'] ?? '').toString(),
      width: parseNumber(map['width']),
      height: parseNumber(map['height']),
      curtainType: (map['curtainType'] ?? 'wave').toString(),
      hasHeavy: map['hasHeavy'] != false,
      hasLight: map['hasLight'] != false,
      enabled: map['enabled'] != false,
    );
  }
}

class BalconySpec {
  final String title;
  final double width;
  final double height;
  final int avezCount;
  final bool enabled;

  const BalconySpec({
    required this.title,
    required this.width,
    required this.height,
    required this.avezCount,
    this.enabled = true,
  });

  factory BalconySpec.fromMap(Map<String, dynamic> m) {
    return BalconySpec(
      title: (m['title'] ?? '').toString(),
      width: parseNumber(m['width']),
      height: parseNumber(m['height']),
      avezCount: parseNumber(m['avezCount']).round(),
      enabled: m['enabled'] != false,
    );
  }
}

// ============================ بنود الفاتورة ============================

class InvoiceLine {
  final String key;
  final String label;
  final String unit;
  final double qty;
  final double unitPrice;
  final String? note;
  final bool isFabric;

  const InvoiceLine({
    required this.key,
    required this.label,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    this.note,
    this.isFabric = false,
  });

  double get total => roundMoney(qty * unitPrice);

  InvoiceLine copyWith({double? qty, double? unitPrice}) {
    return InvoiceLine(
      key: key,
      label: label,
      unit: unit,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      note: note,
      isFabric: isFabric,
    );
  }
}

class ApartmentInvoice {
  final List<InvoiceLine> fabricLines;
  final List<InvoiceLine> accessoryLines;

  const ApartmentInvoice({
    required this.fabricLines,
    required this.accessoryLines,
  });

  double get fabricTotal => fabricLines.fold(0.0, (s, l) => s + l.total);
  double get accessoryTotal => accessoryLines.fold(0.0, (s, l) => s + l.total);
  double get grandTotal => roundMoney(fabricTotal + accessoryTotal);
}

class BalconyInvoice {
  final List<InvoiceLine> fabricLines;
  final List<InvoiceLine> accessoryLines;

  const BalconyInvoice({
    required this.fabricLines,
    required this.accessoryLines,
  });

  double get fabricTotal => fabricLines.fold(0.0, (s, l) => s + l.total);
  double get accessoryTotal => accessoryLines.fold(0.0, (s, l) => s + l.total);
  double get grandTotal => roundMoney(fabricTotal + accessoryTotal);
}

// ============================ محرك الحسابات ============================

ApartmentInvoice calculateApartmentInvoice({
  required List<WindowSpec> windows,
  Map<String, double>? customPrices,
}) {
  final prices = defaultPrices();
  if (customPrices != null) prices.addAll(customPrices);

  final active = windows.where((w) => w.enabled && w.width > 0).toList();

  double rawLinen = 0;
  double rawVelvet = 0;

  double trackMeters = 0;
  int waveHolders = 0;
  int doubleHolders = 0;
  double waveTapeMeters = 0;

  double pressPipeMeters = 0;
  int cantilevers = 0;
  int qamqams = 0;
  double pressTapeMeters = 0;

  int windowCount = active.length;

  for (final w in active) {
    final type = w.curtainType;
    final wM = w.width;

    if (type == 'wave') {
      if (w.hasLight) rawLinen += wM * 2.0;
      if (w.hasHeavy) rawVelvet += wM * 3.0;

      final trackCount = (w.hasLight && w.hasHeavy) ? 2 : 1;
      final m = wM * trackCount;
      trackMeters += m;
      waveHolders += (wM * 2 * trackCount).round();
      waveTapeMeters += m;
    } else if (type == 'double_wave') {
      if (w.hasLight) rawLinen += wM * 3.0;
      if (w.hasHeavy) rawVelvet += wM * 3.0;

      final trackCount = (w.hasLight && w.hasHeavy) ? 2 : 1;
      final m = wM * trackCount;
      trackMeters += m;
      doubleHolders += (wM * 2 * trackCount).round();
      waveTapeMeters += m;
    } else if (type == 'press') {
      if (w.hasLight) rawLinen += wM * 2.0;
      if (w.hasHeavy) rawVelvet += wM * 2.5;

      final pipeCount = (w.hasLight && w.hasHeavy) ? 2 : 1;
      pressPipeMeters += wM * pipeCount;
      cantilevers += 2 * pipeCount;
      qamqams += 2 * pipeCount;
      pressTapeMeters += wM * pipeCount;
    }
  }

  final finalLinen = ceilMeters(rawLinen).toDouble();
  final finalVelvet = ceilMeters(rawVelvet).toDouble();

  final ringsPerM = prices['rings_per_m_apartment'] ?? 7;
  final totalRings = (pressTapeMeters * ringsPerM).round();
  final singleRingPrice = prices['ring_unit'] ?? 3.5;
  final ringDrillPrice = prices['press_drill'] ?? 1.5;

  final fabricLines = <InvoiceLine>[];
  if (finalLinen > 0) {
    fabricLines.add(
      InvoiceLine(
        key: 'fabric_linen',
        label: 'كتان خفيف',
        unit: 'متر',
        qty: finalLinen,
        unitPrice: prices['fabric_linen'] ?? 130,
        isFabric: true,
      ),
    );
  }
  if (finalVelvet > 0) {
    fabricLines.add(
      InvoiceLine(
        key: 'fabric_velvet',
        label: 'قطيفة / قماش ثقيل',
        unit: 'متر',
        qty: finalVelvet,
        unitPrice: prices['fabric_velvet'] ?? 150,
        isFabric: true,
      ),
    );
  }

  final accLines = <InvoiceLine>[];

  if (trackMeters > 0) {
    accLines.add(
      InvoiceLine(
        key: 'track',
        label: 'مسار ويفي معدني',
        unit: 'متر',
        qty: roundMoney(trackMeters),
        unitPrice: prices['track'] ?? 75,
      ),
    );
  }
  if (waveHolders > 0) {
    accLines.add(
      InvoiceLine(
        key: 'holder_wave',
        label: 'حامل تراك (ويفي)',
        unit: 'حامل',
        qty: waveHolders.toDouble(),
        unitPrice: prices['holder_wave'] ?? 40,
      ),
    );
  }
  if (doubleHolders > 0) {
    accLines.add(
      InvoiceLine(
        key: 'holder_double',
        label: 'حامل تراك (دابل ويفي)',
        unit: 'حامل',
        qty: doubleHolders.toDouble(),
        unitPrice: prices['holder_double'] ?? 55,
      ),
    );
  }
  if (waveTapeMeters > 0) {
    accLines.add(
      InvoiceLine(
        key: 'wave_tape',
        label: 'شريط ويفي كبسولة',
        unit: 'متر',
        qty: roundMoney(waveTapeMeters),
        unitPrice: prices['wave_tape'] ?? 55,
      ),
    );
    accLines.add(
      InvoiceLine(
        key: 'wave_prep',
        label: 'تجهيز نظام الويفي',
        unit: 'متر',
        qty: roundMoney(waveTapeMeters),
        unitPrice: prices['wave_prep'] ?? 20,
      ),
    );
    accLines.add(
      InvoiceLine(
        key: 'kasrat',
        label: 'شريط تجميع كسرات',
        unit: 'متر',
        qty: roundMoney(waveTapeMeters),
        unitPrice: prices['kasrat'] ?? 15,
      ),
    );
  }

  if (pressPipeMeters > 0) {
    accLines.add(
      InvoiceLine(
        key: 'pipe_press',
        label: 'ماسورة 4G',
        unit: 'متر',
        qty: roundMoney(pressPipeMeters),
        unitPrice: prices['pipe_press'] ?? 70,
      ),
    );
    accLines.add(
      InvoiceLine(
        key: 'cantilever_forgia',
        label: 'كابولي فورجية',
        unit: 'قطعة',
        qty: cantilevers.toDouble(),
        unitPrice: prices['cantilever_forgia'] ?? 50,
      ),
    );
    accLines.add(
      InvoiceLine(
        key: 'qamqam_forgia',
        label: 'قمقم فورجية',
        unit: 'قطعة',
        qty: qamqams.toDouble(),
        unitPrice: prices['qamqam_forgia'] ?? 45,
      ),
    );
    accLines.add(
      InvoiceLine(
        key: 'press_tape',
        label: 'شريط كبس',
        unit: 'متر',
        qty: roundMoney(pressTapeMeters),
        unitPrice: prices['press_tape'] ?? 15,
      ),
    );
    if (totalRings > 0) {
      accLines.add(
        InvoiceLine(
          key: 'ring_unit',
          label: 'حلقات كبس',
          unit: 'حلقة',
          qty: totalRings.toDouble(),
          unitPrice: singleRingPrice,
        ),
      );
      accLines.add(
        InvoiceLine(
          key: 'press_drill',
          label: 'تخريم وتثبيت الحلقات',
          unit: 'حلقة',
          qty: totalRings.toDouble(),
          unitPrice: ringDrillPrice,
        ),
      );
    }
  }

  if (finalLinen > 0) {
    accLines.add(
      InvoiceLine(
        key: 'sew_light',
        label: 'خياطة قماش خفيف',
        unit: 'متر',
        qty: finalLinen,
        unitPrice: prices['sew_light'] ?? 25,
      ),
    );
  }
  if (finalVelvet > 0) {
    accLines.add(
      InvoiceLine(
        key: 'sew_heavy',
        label: 'خياطة قماش ثقيل',
        unit: 'متر',
        qty: finalVelvet,
        unitPrice: prices['sew_heavy'] ?? 30,
      ),
    );
  }

  if (windowCount > 0) {
    accLines.add(
      InvoiceLine(
        key: 'install_window',
        label: 'مصنعية وتركيب الشبابيك',
        unit: 'شباك',
        qty: windowCount.toDouble(),
        unitPrice: prices['install_window'] ?? 100,
      ),
    );
  }

  return ApartmentInvoice(fabricLines: fabricLines, accessoryLines: accLines);
}

BalconyInvoice calculateBalconyInvoice({
  required List<BalconySpec> balconies,
  required String fabricKey,
  Map<String, double>? customPrices,
}) {
  final prices = defaultPrices();
  if (customPrices != null) prices.addAll(customPrices);

  final active = balconies.where((b) => b.enabled && b.width > 0).toList();

  final totalWidth = active.fold(0.0, (s, b) => s + b.width);
  final totalAvez = active.fold(0, (s, b) => s + b.avezCount);

  final fabricMeters = roundMoney(totalWidth * 1.5);

  final fabricLabel = kBalconyFabrics[fabricKey] ?? 'قماش بلكونة';
  final fabricPrice = prices[fabricKey] ?? 100;

  final ringsPerM = prices['rings_per_m_balcony'] ?? 6;
  final totalRings = (fabricMeters * ringsPerM).round();
  final singleRingPrice = prices['ring_unit'] ?? 3.5;
  final ringDrillPrice = prices['press_drill'] ?? 1.5;

  final fabricLines = <InvoiceLine>[];
  if (fabricMeters > 0) {
    fabricLines.add(
      InvoiceLine(
        key: fabricKey,
        label: fabricLabel,
        unit: 'متر',
        qty: fabricMeters,
        unitPrice: fabricPrice,
        isFabric: true,
      ),
    );
  }

  final accLines = <InvoiceLine>[];
  if (totalWidth > 0) {
    accLines.add(
      InvoiceLine(
        key: 'balc_pipe',
        label: 'ماسورة 4G (بلكونة)',
        unit: 'متر',
        qty: roundMoney(totalWidth),
        unitPrice: prices['balc_pipe'] ?? 70,
      ),
    );
    accLines.add(
      InvoiceLine(
        key: 'balc_tape',
        label: 'شريط كبس (بلكونة)',
        unit: 'متر',
        qty: fabricMeters,
        unitPrice: prices['balc_tape'] ?? 15,
      ),
    );
    if (totalRings > 0) {
      accLines.add(
        InvoiceLine(
          key: 'ring_unit',
          label: 'حلقات كبس',
          unit: 'حلقة',
          qty: totalRings.toDouble(),
          unitPrice: singleRingPrice,
        ),
      );
      accLines.add(
        InvoiceLine(
          key: 'press_drill',
          label: 'تخريم وتثبيت الحلقات',
          unit: 'حلقة',
          qty: totalRings.toDouble(),
          unitPrice: ringDrillPrice,
        ),
      );
    }
  }

  if (totalAvez > 0) {
    accLines.add(
      InvoiceLine(
        key: 'balc_avez',
        label: 'أفيز بلكونة',
        unit: 'قطعة',
        qty: totalAvez.toDouble(),
        unitPrice: prices['balc_avez'] ?? 20,
      ),
    );
  }

  if (fabricMeters > 0) {
    accLines.add(
      InvoiceLine(
        key: 'balc_sew',
        label: 'خياطة قماش البلكونة',
        unit: 'متر',
        qty: fabricMeters,
        unitPrice: prices['balc_sew'] ?? 30,
      ),
    );
  }

  return BalconyInvoice(fabricLines: fabricLines, accessoryLines: accLines);
}
