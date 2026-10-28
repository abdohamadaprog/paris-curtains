part of '../paris_client_measurements_page.dart';

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

  _Calculation get calculation {
    final w = toDouble(width.text);
    final h = toDouble(height.text);

    // مضاعفات القماش المعتمدة:
    // الويفي العادي: ثقيل (قطيفة) = عرض × 3 ، خفيف (كتان) = عرض × 2
    // دابل ويفي: ثقيل وخفيف كلاهما 3 أضعاف (عرض × 3)
    // حلقات كبس: ثقيل = عرض × 2.5 ، خفيف = عرض × 2
    final heavyMultiplier = method == _WorkMethod.press ? 2.5 : 3.0;
    final lightMultiplier = method == _WorkMethod.doubleWave ? 3.0 : 2.0;

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
    double heavyMeters;

    if (isWave) {
      if (w > 0) {
        heavySides = _sidesForWidth(w);
        final auto = heavySides == 2
            ? 2 * wheelsForSide(w / 2)
            : wheelsForSide(w);
        final manual = manualWheels;
        if (manual != null) {
          // الرقم اليدوي لازم يبقى زوجي، ولو جنبين لازم يتقسم على 2 زوجي
          final step = heavySides == 2 ? 4 : 2;
          heavyWheels = ((manual + step - 1) ~/ step) * step;
        } else {
          heavyWheels = auto;
        }
      }
      heavyMeters = w > 0 ? (w * heavyMultiplier) : 0;
    } else {
      heavyWheels = 0; // الحلقات (كبس) مفيهاش عجل
      heavyMeters = w > 0 ? (w * heavyMultiplier) : 0;
    }

    final lightWheels = (lightLayers > 0 && w > 0) ? heavyWheels : 0;
    final heavyTape = w > 0 ? (w * 1.33) : 0.0;
    final lightTape = (lightLayers > 0 && w > 0) ? heavyTape : 0.0;

    return _Calculation(
      heavyMeters: heavyMeters,
      lightMeters: (lightLayers > 0 && w > 0) ? (w * lightMultiplier) : 0,
      heavyHeight: h > 0 ? (h + heavyOffset) : 0,
      lightHeight: (lightLayers > 0 && h > 0) ? (h + lightOffset) : 0,
      heavyWheels: heavyWheels,
      lightWheels: lightWheels,
      heavySides: heavySides,
      wheelsFabricMeters: heavyWheels * _fabricPerWheel,
      heavyTapeMeters: heavyTape,
      lightTapeMeters: lightTape,
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
    required this.heavyHeight,
    required this.lightHeight,
    required this.heavyWheels,
    required this.lightWheels,
    required this.heavySides,
    required this.wheelsFabricMeters,
    required this.heavyTapeMeters,
    required this.lightTapeMeters,
  });

  final double heavyMeters;
  final double lightMeters;
  final double heavyHeight;
  final double lightHeight;
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
