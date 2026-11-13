// حسابات فواتير باريس للستائر (ستائر الشقة + البلكونة).
// ملف Dart خالص متوافق 100% مع كافة إصدارات Flutter.
//
// القواعد المعتمدة وفقاً لورشة باريس للستائر:
//  • ويفي عادي: كتان خفيف (خلفي) = عرض × 2 • قطيفة ثقيل (أمامي) = عرض × 3
//  • دابل ويفي: كتان خفيف = عرض × 3 • قطيفة ثقيل = عرض × 3
//  • حلقات كبس: قطيفة ثقيل = عرض × 2.5 • كتان خفيف = عرض × 2
//  • حوامل تراك الويفي: حتى 1م = 2 كابولي • حتى 2.5م = 3 كوابيل • أكبر = +1 لكل متر
//  • كابولي مواسير الكبس: أقل من أو = 3م = 2 كابولي • أكبر من 3م = 3 كوابيل
//  • أفيز البلكونة: لكل ضلع أقل من 3م = 2 أفيز • أكبر من أو = 3م = 3 أفيز
//  • شريط وتجهيز الويفي: على قماش الويفي (التقيل في العادي، والطبقتين في الدابل)
//  • شريط تجميع الكسرات: على الكتان الخلفي فقط في الويفي العادي
//  • الكوبشة: بند يدوي بعدد الشبابيك اللي فيها طبقة خلفية (في كل الأنظمة)
//  • تقريب أمتار قماش الشقة لأعلى لأقرب متر كامل
//  • قماش البلكونة = إجمالي المقاسات × 1.5 (بدون تقريب)
//
// استثناءات شائعة (لكل شباك على حدة، مش القاعدة الأساسية):
//  • ويفي/دابل ويفي بنسبة 2.5 بدل 3 — بعض العملاء بيطلبوها.
//  • كبس بنسبة 2 للطبقتين (تقيل وخفيف) بدل 2.5 / 2.
//  • البلاك أوت دايماً × 1 (أو نسبة مخصصة) ومقرّب لأعلى لكل شباك.
//  الاستثناءات بتتحفظ مع المقاس في heavy_ratio / light_ratio / blackout_ratio.

/// تقريب لأعلى لأقرب متر كامل بعد تنظيف أخطاء الفاصلة العشرية
int ceilMeters(dynamic v) {
  if (v == null) return 0;
  final num? n = (v is num) ? v : double.tryParse(normalizeDigits(v));
  if (n == null || n.isNaN || n.isInfinite) return 0;
  return ((n * 100).round() / 100).ceil();
}

/// تقريب المبالغ المالية لأقرب قرشين
double roundMoney(dynamic v) {
  if (v == null) return 0.0;
  final num? n = (v is num) ? v : double.tryParse(normalizeDigits(v));
  if (n == null || n.isNaN || n.isInfinite) return 0.0;
  return ((n * 100).round()) / 100;
}

/// تحويل الأرقام العربي والفاصلة العربية لنص يقدر double.tryParse يقراه بأمان
String normalizeDigits(dynamic val) {
  if (val == null) return '0';
  final s = val.toString().trim();
  if (s.isEmpty) return '0';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final ch = s[i];
    final idx = arabic.indexOf(ch);
    b.write(idx >= 0 ? '$idx' : ch);
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
  if (val is num) {
    if (val.isNaN || val.isInfinite) return 0.0;
    return val.toDouble();
  }
  return double.tryParse(normalizeDigits(val)) ?? 0.0;
}

/// حساب عدد حوامل/كوابيل تراك الويفي للشباك الواحد:
/// • حتى 1.00 م: 2 كابولي (طرف يمين وطرف شمال)
/// • أكبر من 1.00 م حتى 2.50 م: 3 كوابيل (طرفين + كابولي في المنتصف لمنع ترييح المسار)
/// • أكبر من 2.50 م: يزيد كابولي إضافي لكل متر زيادة (مثلاً 3.5 م = 4 كوابيل، 4.5 م = 5 كوابيل)
int calcWaveHoldersForWindow(double width) {
  if (width <= 0) return 0;
  if (width <= 1.0) return 2;
  if (width <= 2.5) return 3;
  return 3 + (width - 2.5).ceil();
}

// ============================ الأسعار الافتراضية ============================

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
  PriceDef('press_drill', 'تخريم وتثبيت الحلقة', 'حلقة', 1.5),
  PriceDef('sew_light', 'خياطة خفيف', 'متر', 25),
  PriceDef('sew_heavy', 'خياطة ثقيل', 'متر', 30),
  PriceDef('sew_blackout', 'خياطة بلاك أوت', 'متر', 25),
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
  PriceDef('kobsha', 'كوبشة', 'قطعة', 50),
  PriceDef('transport', 'موصلات ونقل', 'مرة', 0),
  PriceDef('balc_install', 'تركيب بلكونة', 'بلكونة', 0),
];

/// الأسعار العامة اللي اتعدّلت من صفحة "ثوابت الحساب" (بتتحمّل من Firestore).
/// أي سعر مش موجود هنا بيرجع لقيمته الأصلية في kPriceDefs.
class PriceOverrides {
  PriceOverrides._();

  static Map<String, double> _values = {};

  static Map<String, double> get values => Map.unmodifiable(_values);

  static void set(Map<String, double> overrides) {
    _values = Map<String, double>.from(overrides);
  }

  static void clear() => _values = {};
}

/// الأسعار الافتراضية = الأصلية + أي تعديل عام من صفحة ثوابت الحساب.
Map<String, double> defaultPrices() => {
  for (final d in kPriceDefs) d.key: PriceOverrides._values[d.key] ?? d.value,
};

/// أنواع قماش البلكونة (المفتاح = مفتاح السعر)
const Map<String, String> kBalconyFabrics = {
  'fabric_dak': 'دك بلكونات',
  'fabric_blackout3d': 'بلاك أوت 3D',
  'fabric_blackout_sun': 'بلاك أوت عازل للشمس',
};

// ============================ مواصفات المدخلات ============================

class WindowSpec {
  final String title;
  final double width;
  final double height;
  final String curtainType; // 'wave' | 'double_wave' | 'press'
  final bool hasHeavy;
  final bool hasLight;
  final bool enabled;

  // ===== استثناءات القماش (اختيارية) =====
  // null = القاعدة الافتراضية (عرض الشباك + النسبة حسب الطراز).
  final double? heavyWidth;
  final double? lightWidth;
  final double? heavyRatio;
  final double? lightRatio;

  // بلاك أوت: طبقة إضافية (قماش + خياطة فقط، وبتشارك نفس التراك).
  final bool hasBlackout;
  final String blackoutType; // 'fabric_blackout3d' | 'fabric_blackout_sun'
  final double? blackoutWidth;
  final double? blackoutRatio;

  const WindowSpec({
    this.title = '',
    required this.width,
    this.height = 2.8,
    required this.curtainType,
    this.hasHeavy = true,
    this.hasLight = false,
    this.enabled = true,
    this.heavyWidth,
    this.lightWidth,
    this.heavyRatio,
    this.lightRatio,
    this.hasBlackout = false,
    this.blackoutType = 'fabric_blackout3d',
    this.blackoutWidth,
    this.blackoutRatio,
  });

  double get heavyWidthValue => heavyWidth ?? width;
  double get lightWidthValue => lightWidth ?? width;
  double get blackoutWidthValue => blackoutWidth ?? width;

  bool get heavyActive => hasHeavy && heavyWidthValue > 0;
  bool get lightActive => hasLight && lightWidthValue > 0;
  bool get blackoutActive => hasBlackout && blackoutWidthValue > 0;

  factory WindowSpec.fromMap(Map<dynamic, dynamic> map) {
    final lightLayers = parseNumber(map['light_layers']).toInt();
    double? dbl(dynamic v) => v is num ? v.toDouble() : null;
    return WindowSpec(
      title: (map['title'] ?? '').toString(),
      width: parseNumber(map['width']),
      height: parseNumber(map['height'] ?? 2.8),
      curtainType: (map['curtainType'] ?? map['method'] ?? 'wave').toString(),
      hasHeavy: map['hasHeavy'] != false && map['heavy_enabled'] != false,
      hasLight: map['hasLight'] == true || lightLayers > 0,
      enabled: map['enabled'] != false,
      heavyWidth: dbl(map['heavy_width']),
      lightWidth: dbl(map['light_width']),
      heavyRatio: dbl(map['heavy_ratio']),
      lightRatio: dbl(map['light_ratio']),
      hasBlackout: map['blackout_enabled'] == true,
      blackoutType: (map['blackout_type'] ?? 'fabric_blackout3d').toString(),
      blackoutWidth: dbl(map['blackout_width']),
      blackoutRatio: dbl(map['blackout_ratio']),
    );
  }
}

class BalconySpec {
  final String title;
  final double width;
  final double height;
  final int avezCount;
  final List<double> parts;
  final bool enabled;

  const BalconySpec({
    this.title = 'بلكونة',
    required this.width,
    this.height = 2.5,
    this.avezCount = 0,
    this.parts = const [],
    this.enabled = true,
  });

  factory BalconySpec.fromMap(Map<dynamic, dynamic> m) {
    final rawParts = (m['parts'] ?? '').toString().trim();
    List<double> parts = [];
    if (rawParts.isNotEmpty) {
      parts = rawParts
          .split('+')
          .map((p) => parseNumber(p.trim()))
          .where((v) => v > 0)
          .toList();
    }
    double w = parseNumber(m['width'] ?? m['total_width']);
    if (parts.isNotEmpty && w <= 0) {
      w = parts.fold(0.0, (a, b) => a + b);
    }
    if (parts.isEmpty && w > 0) {
      parts = [w];
    }
    return BalconySpec(
      title: (m['title'] ?? 'بلكونة').toString(),
      width: w,
      height: parseNumber(m['height'] ?? 2.5),
      avezCount: parseNumber(m['avezCount']).round(),
      parts: parts,
      enabled: m['enabled'] != false,
    );
  }
}

// ============================ بنود ومخرجات الفاتورة ============================

class InvoiceLine {
  final String key;
  final String label;
  final String unit;
  final double qty;
  final double unitPrice;
  final String? note;
  final bool isFabric;
  final bool manual;

  const InvoiceLine({
    required this.key,
    required this.label,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    this.note,
    this.isFabric = false,
    this.manual = false,
  });

  double get total => roundMoney(qty * unitPrice);

  InvoiceLine copyWith({double? qty, double? unitPrice, String? note}) {
    return InvoiceLine(
      key: key,
      label: label,
      unit: unit,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      note: note ?? this.note,
      isFabric: isFabric,
      manual: manual,
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

// ============================ محرك حسابات فاتورة الشقة ============================

ApartmentInvoice calculateApartmentInvoice({
  required List<WindowSpec> windows,
  Map<String, double>? customPrices,
}) {
  final prices = defaultPrices();
  if (customPrices != null) prices.addAll(customPrices);

  final active = windows.where((w) => w.enabled && w.width > 0).toList();

  double rawLinen = 0;
  double rawVelvet = 0;
  double rawBlackout3d = 0;
  double rawBlackoutSun = 0;

  // هل فيه استثناء صريح على طبقة معينة؟ (بيظهر كملاحظة في الفاتورة)
  bool heavyException = false;
  bool lightException = false;

  // الكوبشة بتتحسب لكل شباك فيه طبقة خلفية (كتان/خفيف)، في كل الأنظمة.
  int kobshaCount = 0;

  double trackMeters = 0;
  int waveHolders = 0;
  int doubleHolders = 0;
  double waveTapeMeters = 0;
  double kasratMeters = 0;

  double pressPipeMeters = 0;
  int cantilevers = 0;
  int qamqams = 0;
  double pressTapeMeters = 0;

  int windowCount = active.length;

  for (final w in active) {
    final rawType = w.curtainType.trim().toLowerCase();
    final type =
        (rawType == 'press' ||
            rawType == 'ring' ||
            rawType == 'rings' ||
            rawType == 'eyelet' ||
            rawType == 'grommet' ||
            rawType.contains('كبس') ||
            rawType.contains('حلقة') ||
            rawType.contains('حلقات'))
        ? 'press'
        : (rawType == 'double_wave' ||
              rawType == 'double-wave' ||
              rawType == 'doublewave' ||
              rawType.contains('دابل') ||
              rawType.contains('double'))
        ? 'double_wave'
        : 'wave';

    // عروض الطبقات الفعلية بعد الاستثناءات (الافتراضي = عرض الشباك)
    final hw = w.heavyActive ? w.heavyWidthValue : 0.0;
    final lw = w.lightActive ? w.lightWidthValue : 0.0;
    final bw = w.blackoutActive ? w.blackoutWidthValue : 0.0;

    // النسب: استثناء صريح، أو الافتراضي حسب الطراز (نفس القواعد القديمة)
    final heavyRatio = w.heavyRatio ?? (type == 'press' ? 2.5 : 3.0);
    final lightRatio = w.lightRatio ?? (type == 'double_wave' ? 3.0 : 2.0);
    final blackoutRatio = w.blackoutRatio ?? 1.0;

    if (hw > 0 && (w.heavyWidth != null || w.heavyRatio != null)) {
      heavyException = true;
    }
    if (lw > 0 && (w.lightWidth != null || w.lightRatio != null)) {
      lightException = true;
    }

    // طبقة خلفية موجودة → كوبشة للشباك ده (بغض النظر عن النظام)
    if (lw > 0) kobshaCount++;

    // أوسع طبقة شغّالة = مرجع الحوامل/الكوابيل
    double widest = hw;
    if (lw > widest) widest = lw;
    if (bw > widest) widest = bw;

    // التراك/المواسير: مجموع عروض الطبقات اللي ليها تراك.
    // البلاك أوت بيشارك تراك الطبقات التانية، ولوحده بياخد تراك بعرضه.
    final layeredTrack = hw + lw;
    final trackWidth = layeredTrack > 0 ? layeredTrack : bw;

    // بلاك أوت: قماش + خياطة فقط، مقرّب لأعلى لكل شباك على حدة.
    if (bw > 0) {
      final meters = ceilMeters(bw * blackoutRatio).toDouble();
      if (w.blackoutType == 'fabric_blackout_sun') {
        rawBlackoutSun += meters;
      } else {
        rawBlackout3d += meters;
      }
    }

    if (type == 'wave') {
      // ويفي عادي: كتان خفيف (خلفي) = عرض × 2 • قطيفة ثقيل (أمامي) = عرض × 3
      if (lw > 0) rawLinen += lw * lightRatio;
      if (hw > 0) rawVelvet += hw * heavyRatio;

      // المسار: مسار لكل طبقة (مسار ويفي أمامي ومسار كسرات خلفي)
      trackMeters += trackWidth;

      // حوامل الويفي: حتى 1م: 2 • حتى 2.5م: 3 • أكبر: +1 لكل متر
      waveHolders += calcWaveHoldersForWindow(widest);

      // شريط وتجهيز الويفي: يتبع الثقيل، ولو مفيش ثقيل يتبع الخفيف
      if (hw > 0) {
        waveTapeMeters += hw * heavyRatio;
      } else if (lw > 0) {
        waveTapeMeters += lw * lightRatio;
      }

      // شريط تجميع الكسرات: للخفيف الخلفي بس لما يكون فيه ثقيل أمامي
      if (hw > 0 && lw > 0) {
        kasratMeters += lw * lightRatio;
      }
    } else if (type == 'double_wave') {
      // دابل ويفي: كتان خفيف = عرض × 3 • قطيفة ثقيل = عرض × 3
      if (lw > 0) rawLinen += lw * lightRatio;
      if (hw > 0) rawVelvet += hw * heavyRatio;

      trackMeters += trackWidth;

      // حوامل دابل ويفي: حتى 1م: 2 • حتى 2.5م: 3 • أكبر: +1 لكل متر
      doubleHolders += calcWaveHoldersForWindow(widest);

      // شريط وتجهيز الويفي: على التقيل والخفيف كلاهما ويفي
      if (hw > 0) waveTapeMeters += hw * heavyRatio;
      if (lw > 0) waveTapeMeters += lw * lightRatio;
    } else if (type == 'press') {
      // حلقات كبس: قطيفة ثقيل = عرض × 2.5 • كتان خفيف = عرض × 2
      if (lw > 0) rawLinen += lw * lightRatio;
      if (hw > 0) rawVelvet += hw * heavyRatio;

      pressPipeMeters += trackWidth;

      // كابولي فورجية: أقل من أو يساوي 3م = 2 كابولي • أكبر = 3
      cantilevers += widest > 3 ? 3 : 2;
      final pipeCount = (hw > 0 ? 1 : 0) + (lw > 0 ? 1 : 0);
      qamqams += 2 * (pipeCount == 0 ? 1 : pipeCount);

      // شريط الكبس: على قد قماش كل طبقة
      if (hw > 0) pressTapeMeters += hw * heavyRatio;
      if (lw > 0) pressTapeMeters += lw * lightRatio;
    }
  }

  // تقريب أمتار القماش لأعلى لأقرب متر كامل
  final finalLinen = ceilMeters(rawLinen).toDouble();
  final finalVelvet = ceilMeters(rawVelvet).toDouble();

  final ringsPerM = prices['rings_per_m_apartment'] ?? 7;
  final totalRings = ceilMeters(pressTapeMeters * ringsPerM);
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
        note: lightException ? 'استثناء على عرض/نسبة الطبقة الخفيفة' : null,
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
        note: heavyException ? 'استثناء على عرض/نسبة الطبقة الثقيلة' : null,
      ),
    );
  }
  // بلاك أوت: الأمتار متقرّبة لأعلى لكل شباك على حدة، وبنضمها هنا.
  if (rawBlackout3d > 0) {
    fabricLines.add(
      InvoiceLine(
        key: 'fabric_blackout3d',
        label: 'بلاك أوت 3D',
        unit: 'متر',
        qty: rawBlackout3d,
        unitPrice: prices['fabric_blackout3d'] ?? 110,
        isFabric: true,
        note: 'طبقة إضافية (استثناء) — مقرّب لأعلى لمتر كامل',
      ),
    );
  }
  if (rawBlackoutSun > 0) {
    fabricLines.add(
      InvoiceLine(
        key: 'fabric_blackout_sun',
        label: 'بلاك أوت عازل للشمس',
        unit: 'متر',
        qty: rawBlackoutSun,
        unitPrice: prices['fabric_blackout_sun'] ?? 170,
        isFabric: true,
        note: 'طبقة إضافية (استثناء) — مقرّب لأعلى لمتر كامل',
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
        note: 'حتى 1م: 2 • حتى 2.5م: 3',
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
        note: 'حتى 1م: 2 • حتى 2.5م: 3',
      ),
    );
  }
  if (waveTapeMeters > 0) {
    accLines.add(
      InvoiceLine(
        key: 'wave_tape',
        label: 'شريط ويفي كبسولة',
        unit: 'متر',
        qty: ceilMeters(waveTapeMeters).toDouble(),
        unitPrice: prices['wave_tape'] ?? 55,
      ),
    );
    accLines.add(
      InvoiceLine(
        key: 'wave_prep',
        label: 'تجهيز نظام الويفي',
        unit: 'متر',
        qty: ceilMeters(waveTapeMeters).toDouble(),
        unitPrice: prices['wave_prep'] ?? 20,
      ),
    );
  }
  if (kasratMeters > 0) {
    accLines.add(
      InvoiceLine(
        key: 'kasrat',
        label: 'شريط تجميع كسرات',
        unit: 'متر',
        qty: ceilMeters(kasratMeters).toDouble(),
        unitPrice: prices['kasrat'] ?? 15,
        note: 'على الكتان الخلفي',
      ),
    );
  }

  if (pressPipeMeters > 0) {
    accLines.add(
      InvoiceLine(
        key: 'pipe_press',
        label: 'ماسورة 4G (كبس)',
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
        note: 'أقل من أو = 3م: 2 • أكبر: 3',
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
        qty: ceilMeters(pressTapeMeters).toDouble(),
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
        label: 'خياطة خفيف',
        unit: 'متر',
        qty: finalLinen,
        unitPrice: prices['sew_light'] ?? 25,
        note: lightException ? 'استثناء على عرض/نسبة الطبقة الخفيفة' : null,
      ),
    );
  }
  if (finalVelvet > 0) {
    accLines.add(
      InvoiceLine(
        key: 'sew_heavy',
        label: 'خياطة تقيل',
        unit: 'متر',
        qty: finalVelvet,
        unitPrice: prices['sew_heavy'] ?? 30,
        note: heavyException ? 'استثناء على عرض/نسبة الطبقة الثقيلة' : null,
      ),
    );
  }
  // خياطة البلاك أوت: على قد أمتار قماش البلاك أوت بالظبط (من غير تقريب تاني)
  final blackoutMeters = rawBlackout3d + rawBlackoutSun;
  if (blackoutMeters > 0) {
    accLines.add(
      InvoiceLine(
        key: 'sew_blackout',
        label: 'خياطة بلاك أوت',
        unit: 'متر',
        qty: blackoutMeters,
        unitPrice: prices['sew_blackout'] ?? 25,
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

  // بنود يدوية
  // كوبشة: لكل شباك فيه طبقة خلفية — 50ج للمقاس (قابل للتعديل).
  if (kobshaCount > 0) {
    accLines.add(
      InvoiceLine(
        key: 'kobsha',
        label: 'كوبشة',
        unit: 'قطعة',
        qty: kobshaCount.toDouble(),
        unitPrice: prices['kobsha'] ?? 50,
        note: 'لكل شباك فيه طبقة خلفية',
        manual: true,
      ),
    );
  }
  accLines.add(
    InvoiceLine(
      key: 'transport',
      label: 'موصلات ونقل',
      unit: 'مرة',
      qty: 1,
      unitPrice: prices['transport'] ?? 0,
      note: 'حسب الاتفاق',
      manual: true,
    ),
  );

  return ApartmentInvoice(fabricLines: fabricLines, accessoryLines: accLines);
}

// ============================ محرك حسابات فاتورة البلكونة ============================

BalconyInvoice calculateBalconyInvoice({
  required List<BalconySpec> balconies,
  required String fabricKey,
  Map<String, double>? customPrices,
}) {
  final prices = defaultPrices();
  if (customPrices != null) prices.addAll(customPrices);

  final active = balconies.where((b) => b.enabled && b.width > 0).toList();

  double totalWidth = 0;
  int totalAvez = 0;

  for (final b in active) {
    totalWidth += b.width;
    if (b.avezCount > 0) {
      totalAvez += b.avezCount;
    } else if (b.parts.isNotEmpty) {
      // قاعدة الأفيز لكل ضلع: أقل من 3م = 2 أفيز • أكبر من أو يساوي 3م = 3 أفيز
      for (final p in b.parts) {
        if (p > 0) {
          totalAvez += (p >= 3.0 ? 3 : 2);
        }
      }
    } else {
      totalAvez += (b.width >= 3.0 ? 3 : 2);
    }
  }

  // قماش البلكونة = إجمالي المقاسات × 1.5 بدون تقريب
  final fabricMeters = roundMoney(totalWidth * 1.5);

  final fabricLabel = kBalconyFabrics[fabricKey] ?? 'قماش بلكونة';
  final fabricPrice = prices[fabricKey] ?? 100;

  final ringsPerM = prices['rings_per_m_balcony'] ?? 6;
  final totalRings = ceilMeters(fabricMeters * ringsPerM);
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
        note: 'أقل من 3م: 2 • أكبر: 3',
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

  if (active.isNotEmpty) {
    accLines.add(
      InvoiceLine(
        key: 'balc_install',
        label: 'تركيب بلكونة',
        unit: 'بلكونة',
        // التركيب لكل بلكونة شغالة (كان كمية 1 ثابتة مهما كان العدد)
        qty: active.length.toDouble(),
        unitPrice: prices['balc_install'] ?? 0,
        note: 'السعر يدوي',
        manual: true,
      ),
    );
  }

  return BalconyInvoice(fabricLines: fabricLines, accessoryLines: accLines);
}
