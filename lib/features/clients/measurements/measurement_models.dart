part of 'paris_client_measurements_page.dart';

// ============================================================================
// دوال التنسيق والأرقام العربية
// ============================================================================
String _toArabic(dynamic value) {
  if (value == null) return '';
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var result = value.toString();
  for (int i = 0; i < 10; i++) {
    result = result.replaceAll(english[i], arabic[i]);
  }
  return result;
}

String _fmt(double val) {
  if (val == val.roundToDouble()) return val.toInt().toString();
  return val
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

String _fmtAr(double val) => _toArabic(_fmt(val));

/// تقريب أمتار القماش لأعلى لأقرب متر كامل (نفس قاعدة الفاتورة).
int _ceilMeters(double v) {
  if (v <= 0 || v.isNaN || v.isInfinite) return 0;
  return ((v * 100).round() / 100).ceil();
}

// ============================================================================
// نماذج البيانات والحسابات الهندسية الدقيقة
// ============================================================================

class _Measurement {
  static int _counter = 0;
  final int id = ++_counter;

  final TextEditingController name = TextEditingController(text: 'شباك');
  final TextEditingController width = TextEditingController(text: '3.00');
  final TextEditingController height = TextEditingController(text: '2.95');
  final TextEditingController wheels = TextEditingController();

  _WorkMethod method = _WorkMethod.wave;
  _CeilingType ceiling = _CeilingType.kaboli;
  int velvetSides = 2;
  int lightLayers = 1;
  int lightSides = 2;
  bool enabled = true;

  // ===== استثناءات القماش (اختيارية) =====
  // كل قيمة null = القاعدة الافتراضية (عرض الشباك + النسبة حسب الطراز).
  // أي قيمة مش null = استثناء صريح بيتحفظ ويتنقل للفاتورة وصورة المقاسات.
  bool heavyEnabled = true;
  double? heavyWidthOverride;
  double? heavyRatioOverride;
  double? lightWidthOverride;
  double? lightRatioOverride;
  bool blackoutEnabled = false;
  String blackoutType = 'fabric_blackout3d';
  double? blackoutWidthOverride;
  double? blackoutRatioOverride;

  double get baseWidth => toDouble(width.text);
  bool get hasLight => lightLayers > 0;

  double get heavyWidth => heavyWidthOverride ?? baseWidth;
  double get lightWidth => lightWidthOverride ?? baseWidth;
  double get blackoutWidth => blackoutWidthOverride ?? baseWidth;

  double get defaultHeavyRatio => method == _WorkMethod.press ? 2.5 : 3.0;
  double get defaultLightRatio => method == _WorkMethod.doubleWave ? 3.0 : 2.0;

  double get heavyRatio => heavyRatioOverride ?? defaultHeavyRatio;
  double get lightRatio => lightRatioOverride ?? defaultLightRatio;
  double get blackoutRatio => blackoutRatioOverride ?? 1.0;

  /// ملخص مقروء للاستثناءات (بيظهر في صورة المقاسات والكارت).
  String get exceptionSummary {
    final parts = <String>[];
    if (!heavyEnabled) parts.add('بدون ثقيل');
    if (heavyEnabled &&
        (heavyWidthOverride != null || heavyRatioOverride != null)) {
      parts.add('ثقيل ${_fmtAr(heavyWidth)}×${_fmtAr(heavyRatio)}');
    }
    if (hasLight &&
        (lightWidthOverride != null || lightRatioOverride != null)) {
      parts.add('خفيف ${_fmtAr(lightWidth)}×${_fmtAr(lightRatio)}');
    }
    if (blackoutEnabled) {
      parts.add('بلاك أوت ${_fmtAr(blackoutWidth)}×${_fmtAr(blackoutRatio)}');
    }
    return parts.isEmpty ? '' : 'استثناء: ${parts.join(' • ')}';
  }

  /// هل فيه أي استثناء شغّال على المقاس ده؟
  bool get hasException =>
      !heavyEnabled ||
      blackoutEnabled ||
      heavyWidthOverride != null ||
      lightWidthOverride != null ||
      blackoutWidthOverride != null ||
      heavyRatioOverride != null ||
      lightRatioOverride != null ||
      blackoutRatioOverride != null;

  _Calculation get calculation {
    final h = toDouble(height.text);

    // عرض كل طبقة: الافتراضي = عرض الشباك، أو الاستثناء لو موجود.
    final hw = heavyEnabled ? heavyWidth : 0.0;
    final lw = hasLight ? lightWidth : 0.0;
    final bw = blackoutEnabled ? blackoutWidth : 0.0;

    // خصومات الارتفاع بالسنتيمتر بناءً على السقف ونوع التعليق
    double heavyOffset = 0;
    double lightOffset = 0;

    if (method == _WorkMethod.press) {
      heavyOffset = .03; // +3 سم
      lightOffset = .02; // +2 سم
    } else if (method == _WorkMethod.wave && ceiling == _CeilingType.kaboli) {
      heavyOffset = -.01; // -1 سم
      lightOffset = -.04; // -4 سم
    } else if (method == _WorkMethod.wave &&
        ceiling == _CeilingType.curtainBox) {
      heavyOffset = 0;
      lightOffset = -.04; // -4 سم
    } else if (method == _WorkMethod.doubleWave &&
        ceiling == _CeilingType.kaboli) {
      heavyOffset = -.01; // -1 سم
      lightOffset = -.02; // -2 سم
    } else if (method == _WorkMethod.doubleWave &&
        ceiling == _CeilingType.curtainBox) {
      heavyOffset = .01; // +1 سم
      lightOffset = 0;
    }

    // ===== حساب العجل والقماش (ويفي / دابل ويفي) =====
    final isWave = method != _WorkMethod.press;
    var heavySides = 1;
    var heavyWheels = 0;
    var lightWheels = 0;

    if (isWave) {
      final manual = manualWheels;

      // العجل التلقائي لعرض معين (نفس القاعدة القديمة بالحرف)
      int autoWheelsFor(double width) {
        final sides = _sidesForWidth(width);
        return sides == 2 ? 2 * wheelsForSide(width / 2) : wheelsForSide(width);
      }

      // الرقم اليدوي لازم يبقى زوجي، ولو جنبين لازم يتقسم على 2 زوجي
      int manualWheelsFor(double width) {
        final step = _sidesForWidth(width) == 2 ? 4 : 2;
        return ((manual! + step - 1) ~/ step) * step;
      }

      if (hw > 0) {
        heavySides = _sidesForWidth(hw);
        heavyWheels = manual != null ? manualWheelsFor(hw) : autoWheelsFor(hw);
      }
      if (lw > 0) {
        if (manual != null && !heavyEnabled) {
          // الثقيل متلغي: الرقم اليدوي بيتطبق على الخفيف
          lightWheels = manualWheelsFor(lw);
        } else if (manual != null && (lw - hw).abs() < 0.001) {
          lightWheels = heavyWheels;
        } else {
          lightWheels = autoWheelsFor(lw);
        }
      }
    }

    // القماش: عرض الطبقة × نسبتها (النسبة الافتراضية حسب الطراز).
    final heavyMeters = hw > 0 ? (hw * heavyRatio) : 0.0;
    final lightMeters = lw > 0 ? (lw * lightRatio) : 0.0;
    // البلاك أوت: عرض × 1 (أو نسبة مخصصة) مقرّب لأعلى لكل شباك على حدة.
    final blackoutMeters = bw > 0
        ? _ceilMeters(bw * blackoutRatio).toDouble()
        : 0.0;

    // شريط العجل: عرض × ١٫٣٣ — حساب ورشة (تنبيه للمقاس) فقط،
    // ومش داخل في الفاتورة خالص. الفاتورة بتحسب "شريط ويفي" = أمتار القماش.
    final heavyTape = hw > 0 ? (hw * 1.33) : 0.0;
    final lightTape = lw > 0 ? (lw * 1.33) : 0.0;

    return _Calculation(
      heavyMeters: heavyMeters,
      lightMeters: lightMeters,
      blackoutMeters: blackoutMeters,
      heavyHeight: h > 0 ? (h + heavyOffset) : 0,
      lightHeight: (lw > 0 && h > 0) ? (h + lightOffset) : 0,
      blackoutHeight: (bw > 0 && h > 0)
          ? (h + (lw > 0 ? lightOffset : heavyOffset))
          : 0,
      heavyWheels: heavyWheels,
      lightWheels: lightWheels,
      heavySides: heavySides,
      wheelsFabricMeters:
          (heavyEnabled ? heavyWheels : lightWheels) * _fabricPerWheel,
      heavyTapeMeters: heavyTape,
      lightTapeMeters: lightTape,
      heavyWidth: hw,
      lightWidth: lw,
      blackoutWidth: bw,
      heavyRatio: heavyRatio,
      lightRatio: lightRatio,
      blackoutRatio: blackoutRatio,
      hasBlackout: bw > 0,
      heavyEnabled: heavyEnabled,
      lightEnabled: lw > 0,
    );
  }

  // متر القماش لكل عجلة (سر المهنة: بيظهر في سطر العجل بس)
  static const double _fabricPerWheel = 0.148;

  // العدد اليدوي للعجل (لو الحقل فاضي أو غلط بيرجع null ويشتغل الحساب التلقائي)
  int? get manualWheels {
    final v = int.tryParse(_normalizeDigits(wheels.text));
    return (v != null && v > 0) ? v : null;
  }

  // المقاس من 2 متر فما فوق بيتقسم جنبين
  static int _sidesForWidth(double w) => (w * 100).round() >= 200 ? 2 : 1;

  // جدول العجل لجنب واحد: حتى 1.00م = 18، حتى 1.20م = 20، وبعد كده +2 عجلة كل 10 سم
  static int wheelsForSide(double side) {
    final cm = (side * 100).round();
    if (cm <= 100) return 18;
    if (cm <= 120) return 20;
    return 20 + 2 * ((cm - 120 + 9) ~/ 10);
  }

  static String _normalizeDigits(String val) => val
      .replaceAll('٠', '0')
      .replaceAll('١', '1')
      .replaceAll('٢', '2')
      .replaceAll('٣', '3')
      .replaceAll('٤', '4')
      .replaceAll('٥', '5')
      .replaceAll('٦', '6')
      .replaceAll('٧', '7')
      .replaceAll('٨', '8')
      .replaceAll('٩', '9')
      .trim();

  static double toDouble(String val) {
    var clean = val
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('،', '.')
        .replaceAll('٫', '.')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(clean) ?? 0.0;
  }

  void dispose() {
    name.dispose();
    width.dispose();
    height.dispose();
    wheels.dispose();
  }
}

// ============================================================================
// نموذج كارت البلكونة المطور
// ============================================================================

class _Balcony {
  static int _counter = 0;
  final int id = ++_counter;

  final TextEditingController name = TextEditingController(text: 'بلكونة');
  final TextEditingController parts = TextEditingController(text: '3.00');
  final TextEditingController height = TextEditingController(text: '2.80');
  int? customAvez;
  bool enabled = true;

  // حالة الكارت (مفتوح/مطوي) — للعرض فقط ومش بتتحفظ
  bool isExpanded = true;

  // عدد الأضلاع (من 1 لـ 4) وحقول إدخال كل ضلع
  int sidesCount = 1;
  final TextEditingController side1 = TextEditingController(text: '3.00');
  final TextEditingController side2 = TextEditingController();
  final TextEditingController side3 = TextEditingController();
  final TextEditingController side4 = TextEditingController();

  double get side1Val => _Measurement.toDouble(side1.text);
  double get side2Val => _Measurement.toDouble(side2.text);
  double get side3Val => _Measurement.toDouble(side3.text);
  double get side4Val => _Measurement.toDouble(side4.text);

  // يجمع الأضلاع الظاهرة في النص المحفوظ (parts) مثل: 3+2.5+1.2
  void syncPartsFromSides() {
    final vals = <double>[side1Val, side2Val, side3Val, side4Val];
    final visible = vals
        .take(sidesCount.clamp(1, 4).toInt())
        .where((v) => v > 0);
    parts.text = visible.map(_fmt).join('+');
  }

  // العكس: يملأ حقول الأضلاع من النص المحفوظ (parts) عند التحميل أو النسخ
  void syncSidesFromParts() {
    final list = sideList;
    sidesCount = list.isEmpty ? 1 : list.length.clamp(1, 4).toInt();
    final controllers = [side1, side2, side3, side4];
    for (var i = 0; i < controllers.length; i++) {
      controllers[i].text = i < list.length ? _fmt(list[i]) : '';
    }
  }

  // استخراج قائمة أطوال الأضلاع كمصفوفة أرقام
  List<double> get sideList {
    final clean = parts.text
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('،', '.')
        .replaceAll('٫', '.')
        .replaceAll(',', '.');
    return clean
        .split('+')
        .map((p) => double.tryParse(p.trim()) ?? 0.0)
        .where((w) => w > 0)
        .toList();
  }

  // إجمالي عرض البلكونة الصافي (مجموع الأضلاع)
  double get totalWidth {
    final list = sideList;
    if (list.isEmpty) return 0.0;
    return list.fold<double>(0.0, (accumulated, item) => accumulated + item);
  }

  // قاعدة الأفيز الدقيقة:
  // لكل ضلع أو ماسورة: لو أقل من 3.00 متر بياخد 2 أفيز، لو 3.00 متر فما فوق بياخد 3 أفيز
  int get calculatedAvez {
    final list = sideList;
    if (list.isEmpty) return 0;
    int count = 0;
    for (final side in list) {
      count += (side >= 3.0 ? 3 : 2);
    }
    return count;
  }

  // عدد الأفيز الفعلي (اليدوي إن وُجد وإلا التلقائي الهندسي)
  int get avezCount => customAvez ?? calculatedAvez;

  // الاسم اللي بيستخدمه كارت البلكونة
  int get totalAvez => avezCount;

  // قماش البلكونة = إجمالي المقاسات المفرودة × 1.5
  double get fabricMeters => ((totalWidth * 1.5 * 100).round() / 100);

  // شريط الكبس للبلكونة = نفس أمتار قماش البلكونة
  double get tapeMeters => fabricMeters;

  // عدد حلقات الكبس للبلكونة = أمتار القماش × 6 حلقات لكل متر
  int get ringsCount => (fabricMeters * 6).round();

  void dispose() {
    name.dispose();
    parts.dispose();
    height.dispose();
    side1.dispose();
    side2.dispose();
    side3.dispose();
    side4.dispose();
  }
}

class _Calculation {
  const _Calculation({
    required this.heavyMeters,
    required this.lightMeters,
    required this.blackoutMeters,
    required this.heavyHeight,
    required this.lightHeight,
    required this.blackoutHeight,
    required this.heavyWheels,
    required this.lightWheels,
    required this.heavySides,
    required this.wheelsFabricMeters,
    required this.heavyTapeMeters,
    required this.lightTapeMeters,
    required this.heavyWidth,
    required this.lightWidth,
    required this.blackoutWidth,
    required this.heavyRatio,
    required this.lightRatio,
    required this.blackoutRatio,
    required this.hasBlackout,
    required this.heavyEnabled,
    required this.lightEnabled,
  });

  final double heavyMeters;
  final double lightMeters;
  final double blackoutMeters;
  final double heavyHeight;
  final double lightHeight;
  final double blackoutHeight;
  final int heavyWheels;
  final int lightWheels;
  final int heavySides;

  // قماش العجل (عدد العجل × 0.148): معلومة للشغل بتتكتب تحت الكارت
  final double wheelsFabricMeters;

  // 18 + 18 لو جنبين، أو الرقم الواحد لو جنب واحد
  String get heavyWheelsLabel {
    if (heavySides == 2) {
      final half = _toArabic(heavyWheels ~/ 2);
      return '$half+$half';
    }
    return _toArabic(heavyWheels);
  }

  final double heavyTapeMeters;
  final double lightTapeMeters;

  // بيانات العرض: عروض الطبقات والنسب الفعلية بعد الاستثناءات
  final double heavyWidth;
  final double lightWidth;
  final double blackoutWidth;
  final double heavyRatio;
  final double lightRatio;
  final double blackoutRatio;
  final bool hasBlackout;
  final bool heavyEnabled;
  final bool lightEnabled;
}

class _DeletedCard {
  _DeletedCard({
    required this.isBalcony,
    required this.name,
    this.width = '3.00',
    this.height = '2.95',
    this.method = 'wave',
    this.ceiling = 'kaboli',
    this.velvetSides = 2,
    this.lightLayers = 1,
    this.lightSides = 2,
    this.wheels = '',
    this.parts = '',
    this.customAvez,
    this.enabled = true,
    this.heavyEnabled = true,
    this.heavyWidth,
    this.heavyRatio,
    this.lightWidth,
    this.lightRatio,
    this.blackoutEnabled = false,
    this.blackoutType = 'fabric_blackout3d',
    this.blackoutWidth,
    this.blackoutRatio,
  });

  factory _DeletedCard.measurement(_Measurement m) => _DeletedCard(
    isBalcony: false,
    name: m.name.text,
    width: m.width.text,
    height: m.height.text,
    method: m.method.name,
    ceiling: m.ceiling.name,
    velvetSides: m.velvetSides,
    lightLayers: m.lightLayers,
    lightSides: m.lightSides,
    wheels: m.wheels.text,
    enabled: m.enabled,
    heavyEnabled: m.heavyEnabled,
    heavyWidth: m.heavyWidthOverride,
    heavyRatio: m.heavyRatioOverride,
    lightWidth: m.lightWidthOverride,
    lightRatio: m.lightRatioOverride,
    blackoutEnabled: m.blackoutEnabled,
    blackoutType: m.blackoutType,
    blackoutWidth: m.blackoutWidthOverride,
    blackoutRatio: m.blackoutRatioOverride,
  );

  factory _DeletedCard.balcony(_Balcony b) => _DeletedCard(
    isBalcony: true,
    name: b.name.text,
    parts: b.parts.text,
    height: b.height.text,
    customAvez: b.customAvez,
    enabled: b.enabled,
  );

  factory _DeletedCard.fromMap(Map<String, dynamic> map) => _DeletedCard(
    isBalcony: map['is_balcony'] == true || map['type'] == 'balcony',
    name: (map['name'] ?? '').toString(),
    width: (map['width'] ?? '3.00').toString(),
    height: (map['height'] ?? '2.95').toString(),
    method: (map['method'] ?? 'wave').toString(),
    ceiling: (map['ceiling'] ?? 'kaboli').toString(),
    velvetSides: (map['velvet_sides'] as num?)?.toInt() ?? 2,
    lightLayers: (map['light_layers'] as num?)?.toInt() ?? 1,
    lightSides: (map['light_sides'] as num?)?.toInt() ?? 2,
    wheels: (map['wheels'] ?? '').toString(),
    parts: (map['parts'] ?? '').toString(),
    customAvez: (map['custom_avez'] as num?)?.toInt(),
    enabled: map['enabled'] != false,
    heavyEnabled: map['heavy_enabled'] != false,
    heavyWidth: (map['heavy_width'] as num?)?.toDouble(),
    heavyRatio: (map['heavy_ratio'] as num?)?.toDouble(),
    lightWidth: (map['light_width'] as num?)?.toDouble(),
    lightRatio: (map['light_ratio'] as num?)?.toDouble(),
    blackoutEnabled: map['blackout_enabled'] == true,
    blackoutType: (map['blackout_type'] ?? 'fabric_blackout3d').toString(),
    blackoutWidth: (map['blackout_width'] as num?)?.toDouble(),
    blackoutRatio: (map['blackout_ratio'] as num?)?.toDouble(),
  );

  final bool isBalcony;
  final String name;
  final String width;
  final String height;
  final String method;
  final String ceiling;
  final int velvetSides;
  final int lightLayers;
  final int lightSides;
  final String wheels;
  final String parts;
  final int? customAvez;
  final bool enabled;
  final bool heavyEnabled;
  final double? heavyWidth;
  final double? heavyRatio;
  final double? lightWidth;
  final double? lightRatio;
  final bool blackoutEnabled;
  final String blackoutType;
  final double? blackoutWidth;
  final double? blackoutRatio;

  Map<String, dynamic> toMap() => {
    'is_balcony': isBalcony,
    'name': name,
    'width': width,
    'height': height,
    'method': method,
    'ceiling': ceiling,
    'velvet_sides': velvetSides,
    'light_layers': lightLayers,
    'light_sides': lightSides,
    'wheels': wheels,
    'parts': parts,
    'custom_avez': customAvez,
    'enabled': enabled,
    'heavy_enabled': heavyEnabled,
    'heavy_width': heavyWidth,
    'heavy_ratio': heavyRatio,
    'light_width': lightWidth,
    'light_ratio': lightRatio,
    'blackout_enabled': blackoutEnabled,
    'blackout_type': blackoutType,
    'blackout_width': blackoutWidth,
    'blackout_ratio': blackoutRatio,
  };

  _Measurement toMeasurement() {
    final m = _Measurement();
    m.name.text = name;
    m.width.text = width;
    m.height.text = height;
    m.method = _WorkMethod.values.firstWhere(
      (v) => v.name == method,
      orElse: () => _WorkMethod.wave,
    );
    m.ceiling = _CeilingType.values.firstWhere(
      (v) => v.name == ceiling,
      orElse: () => _CeilingType.kaboli,
    );
    m.velvetSides = velvetSides;
    m.lightLayers = lightLayers;
    m.lightSides = lightSides;
    m.wheels.text = wheels;
    m.enabled = enabled;
    m.heavyEnabled = heavyEnabled;
    m.heavyWidthOverride = heavyWidth;
    m.heavyRatioOverride = heavyRatio;
    m.lightWidthOverride = lightWidth;
    m.lightRatioOverride = lightRatio;
    m.blackoutEnabled = blackoutEnabled;
    m.blackoutType = blackoutType;
    m.blackoutWidthOverride = blackoutWidth;
    m.blackoutRatioOverride = blackoutRatio;
    return m;
  }

  _Balcony toBalcony() {
    final b = _Balcony();
    b.name.text = name;
    b.parts.text = parts;
    b.syncSidesFromParts();
    b.height.text = height;
    b.customAvez = customAvez;
    b.enabled = enabled;
    return b;
  }
}

enum _WorkMethod {
  wave('ويفي'),
  press('حلقات كبس'),
  doubleWave('دابل ويفي');

  const _WorkMethod(this.label);
  final String label;
}

enum _CeilingType {
  kaboli('كابولي'),
  curtainBox('بيت ستارة');

  const _CeilingType(this.label);
  final String label;
}

// ألوان وثوابت صفحة المقاسات المشتركة بين كل الملفات
// ألوان وهوية ستائر باريس الملكية مع ثوابت آمنة متوافقة
Color get _gold => AppPalette.gold;

Color get _neon => AppPalette.goldLight;

Color get _bg => AppPalette.bg;

Color get _panel => AppPalette.panel;

// ألوان إضافية مطابقة لصفحة الفاتورة
Color get _line => AppPalette.line;

Color get _muted => AppPalette.muted;

// ============================================================================
// كارت المقاس: مصغّر في القائمة، وبلمسة واحدة نفس الكارت يكبر (Pop-up)
// ويظهر معاه التعديل، ولما تقفله بيصغر ويرجع مكانه.
// ============================================================================
const double _compactZoom = 0.80;

// ============================================================================
// قوالب المقاسات: إعدادات جاهزة بتتضاف بضغطة (بتتحفظ على الجهاز)
// ============================================================================
class _MeasurementTemplate {
  const _MeasurementTemplate({
    required this.name,
    required this.width,
    required this.height,
    required this.method,
    required this.ceiling,
    required this.velvetSides,
    required this.lightLayers,
    required this.lightSides,
    this.heavyEnabled = true,
    this.heavyWidth,
    this.heavyRatio,
    this.lightWidth,
    this.lightRatio,
    this.blackoutEnabled = false,
    this.blackoutType = 'fabric_blackout3d',
    this.blackoutWidth,
    this.blackoutRatio,
  });

  final String name;
  final String width;
  final String height;
  final _WorkMethod method;
  final _CeilingType ceiling;
  final int velvetSides;
  final int lightLayers;
  final int lightSides;
  final bool heavyEnabled;
  final double? heavyWidth;
  final double? heavyRatio;
  final double? lightWidth;
  final double? lightRatio;
  final bool blackoutEnabled;
  final String blackoutType;
  final double? blackoutWidth;
  final double? blackoutRatio;

  factory _MeasurementTemplate.fromItem(_Measurement m, String name) =>
      _MeasurementTemplate(
        name: name,
        width: m.width.text,
        height: m.height.text,
        method: m.method,
        ceiling: m.ceiling,
        velvetSides: m.velvetSides,
        lightLayers: m.lightLayers,
        lightSides: m.lightSides,
        heavyEnabled: m.heavyEnabled,
        heavyWidth: m.heavyWidthOverride,
        heavyRatio: m.heavyRatioOverride,
        lightWidth: m.lightWidthOverride,
        lightRatio: m.lightRatioOverride,
        blackoutEnabled: m.blackoutEnabled,
        blackoutType: m.blackoutType,
        blackoutWidth: m.blackoutWidthOverride,
        blackoutRatio: m.blackoutRatioOverride,
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    'width': width,
    'height': height,
    'method': method.name,
    'ceiling': ceiling.name,
    'velvet_sides': velvetSides,
    'light_layers': lightLayers,
    'light_sides': lightSides,
    'heavy_enabled': heavyEnabled,
    'heavy_width': heavyWidth,
    'heavy_ratio': heavyRatio,
    'light_width': lightWidth,
    'light_ratio': lightRatio,
    'blackout_enabled': blackoutEnabled,
    'blackout_type': blackoutType,
    'blackout_width': blackoutWidth,
    'blackout_ratio': blackoutRatio,
  };

  static _MeasurementTemplate? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final name = (raw['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    int intOf(dynamic v, int fallback) => v is num ? v.toInt() : fallback;
    double? dblOf(dynamic v) => v is num ? v.toDouble() : null;
    return _MeasurementTemplate(
      name: name,
      width: (raw['width'] ?? '3.00').toString(),
      height: (raw['height'] ?? '2.95').toString(),
      method: _WorkMethod.values.firstWhere(
        (v) => v.name == raw['method'],
        orElse: () => _WorkMethod.wave,
      ),
      ceiling: _CeilingType.values.firstWhere(
        (v) => v.name == raw['ceiling'],
        orElse: () => _CeilingType.kaboli,
      ),
      velvetSides: intOf(raw['velvet_sides'], 2).clamp(1, 2).toInt(),
      lightLayers: intOf(raw['light_layers'], 1).clamp(0, 1).toInt(),
      lightSides: intOf(raw['light_sides'], 2).clamp(1, 2).toInt(),
      heavyEnabled: raw['heavy_enabled'] != false,
      heavyWidth: dblOf(raw['heavy_width']),
      heavyRatio: dblOf(raw['heavy_ratio']),
      lightWidth: dblOf(raw['light_width']),
      lightRatio: dblOf(raw['light_ratio']),
      blackoutEnabled: raw['blackout_enabled'] == true,
      blackoutType: (raw['blackout_type'] ?? 'fabric_blackout3d').toString(),
      blackoutWidth: dblOf(raw['blackout_width']),
      blackoutRatio: dblOf(raw['blackout_ratio']),
    );
  }

  void applyTo(_Measurement m) {
    m.name.text = name;
    m.width.text = width;
    m.height.text = height;
    m.method = method;
    m.ceiling = ceiling;
    m.velvetSides = velvetSides;
    m.lightLayers = lightLayers;
    m.lightSides = lightSides;
    m.heavyEnabled = heavyEnabled;
    m.heavyWidthOverride = heavyWidth;
    m.heavyRatioOverride = heavyRatio;
    m.lightWidthOverride = lightWidth;
    m.lightRatioOverride = lightRatio;
    m.blackoutEnabled = blackoutEnabled;
    m.blackoutType = blackoutType;
    m.blackoutWidthOverride = blackoutWidth;
    m.blackoutRatioOverride = blackoutRatio;
  }
}

class _TemplateStore {
  _TemplateStore._();

  static const String _key = 'measurement_templates_v1';

  static Future<List<_MeasurementTemplate>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map(_MeasurementTemplate.fromMap)
          .whereType<_MeasurementTemplate>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<_MeasurementTemplate> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(list.map((t) => t.toMap()).toList()),
      );
    } catch (_) {}
  }
}
