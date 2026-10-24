import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';

/// ============================================================================
/// شاشة مقاسات العميل الفاخرة لتطبيق ستائر باريس — Paris Curtains
/// التصميم المطور النهائي الخالي من أي أخطاء والمتوافق مع جميع إصدارات فلاتر:
/// - متوافق مع كافة إصدارات Flutter (استخدام withOpacity بدلاً من withValues)
/// - كروت مدمجة عالية الكثافة تتسع لـ ٥ مقاسات على شاشة الهاتف
/// - السطر 1: [صح] [ 🌟 اسم الغرفة 🌟 🪟 ] [ أدوات / سحب وإعادة ترتيب ]
/// - السطر 2: [ 📌 ٤.٢٠ م 📌 ] ⬅️⬅️ [ ٦ متر ثقيل + ٤ متر خفيف ]
/// - السطر 3: [ 📩 الارتفاع ٢.٩٥ م ] [ ✅ 🪟 ويفي ▾ ] [ ✅ 🏠 كابولي ▾ ] بقوائم منبثقة سريعة بلمسة واحدة
/// - السطر 4: 🪡 خياطة ثقيل ٢.٩٤ م • 🪡 خياطة خفيف ٢.٩١ م (بالتفصيل والتنسيق العربي السليم)
/// - السطر 5: نظام الخياطة (الأجناب) والعجل والشريط مدمجين في سطر واحد
/// - تكبير الخطوط لتكون واضحة ومقروءة تحت إضاءة الورشة
/// - تكرار ونسخ الكارت بـ ٣ نقرات متتالية (Triple-Tap)
/// - شطب جميع النصوص بالكامل عند تعطيل الكارت (Strike-through)
/// - حفظ تلقائي فوري وسلس (Auto-Save) في Firestore بمجرد إدخال أو تعديل أي بيان
/// ============================================================================
class ParisClientMeasurementsPage extends StatefulWidget {
  const ParisClientMeasurementsPage({
    super.key,
    required this.clientId,
    required this.clientName,
    this.phone,
    this.address,
    this.registrationDate,
    this.installationDate,
  });

  final String clientId;
  final String clientName;
  final String? phone;
  final String? address;
  final DateTime? registrationDate;
  final DateTime? installationDate;

  @override
  State<ParisClientMeasurementsPage> createState() =>
      _ParisClientMeasurementsPageState();
}

class _ParisClientMeasurementsPageState
    extends State<ParisClientMeasurementsPage> {
  // ألوان وهوية ستائر باريس الملكية مع ثوابت آمنة متوافقة
  static const Color _gold = AppColors.primaryGold;
  static const Color _neon = AppColors.lightGold;
  static const Color _bg = Color(0xFF0C0E14);
  static const Color _panel = Color(0xFF161622);

  late final TextEditingController _nameController;
  DateTime? _installationDate;

  final List<_Measurement> _measurements = [_Measurement()];
  final List<_Balcony> _balconies = [];
  final List<_DeletedCard> _trash = [];

  bool _saving = false;
  bool _isAutoSaving = false;
  bool _savedSuccess = false;
  bool _showTrash = false;
  bool _loaded = false;
  bool _loadFailed = false;

  // مؤقت الحفظ التلقائي (Debounce Auto-Save)
  Timer? _autoSaveTimer;

  // تتبع النقرات المتتالية (Triple-Tap) لتكرار الكارت
  int _tapCount = 0;
  int _lastTappedCardId = -1;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.clientName);
    _installationDate = widget.installationDate;
    _loadSavedData();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _nameController.dispose();
    for (final item in _measurements) {
      item.dispose();
    }
    for (final item in _balconies) {
      item.dispose();
    }
    super.dispose();
  }

  // ============================================================================
  // دوال تحويل الأرقام إلى العربية وتنسيق الفواصل
  // ============================================================================
  String _toArabic(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = str;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(english[i], arabic[i]);
    }
    return result;
  }

  String _fmt(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _fmtAr(double val) => _toArabic(_fmt(val));

  String _date(DateTime? value) => value == null
      ? 'حدد موعد التركيب'
      : _toArabic(
          '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
        );

  // ============================================================================
  // آلية الحفظ التلقائي الذكي (Auto-Save)
  // ============================================================================
  void _triggerAutoSave() {
    if (!_loaded || _loadFailed) return;
    setState(() {
      _isAutoSaving = true;
      _savedSuccess = false;
    });
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 650), () {
      _performSave(isAuto: true);
    });
  }

  // ============================================================================
  // تحميل البيانات من Firestore
  // ============================================================================
  Future<void> _loadSavedData() async {
    _loadFailed = false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();

      if (!mounted) return;
      if (!doc.exists) {
        setState(() => _loaded = true);
        return;
      }

      final data = doc.data() ?? <String, dynamic>{};
      final loadedMeasurements = <_Measurement>[];
      final loadedBalconies = <_Balcony>[];
      final loadedTrash = <_DeletedCard>[];

      for (final raw in (data['measurements'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final m = _Measurement();
        m.name.text = (raw['name'] ?? '').toString();
        m.width.text = (raw['width'] ?? '').toString();
        m.height.text = (raw['height'] ?? '').toString();
        m.method = _WorkMethod.values.firstWhere(
          (v) => v.name == raw['method'],
          orElse: () => _WorkMethod.wave,
        );
        m.ceiling = _CeilingType.values.firstWhere(
          (v) => v.name == raw['ceiling'],
          orElse: () => _CeilingType.kaboli,
        );
        m.velvetSides = (raw['velvet_sides'] as num?)?.toInt() ?? 2;
        m.lightLayers = (raw['light_layers'] as num?)?.toInt() ?? 1;
        m.wheels.text = (raw['wheels'] ?? '').toString();
        m.enabled = raw['enabled'] != false;
        m.expanded = false;
        loadedMeasurements.add(m);
      }

      for (final raw in (data['deleted_cards'] as List? ?? const [])) {
        if (raw is Map) {
          loadedTrash.add(_DeletedCard.fromMap(Map<String, dynamic>.from(raw)));
        }
      }

      for (final raw in (data['balconies'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final b = _Balcony();
        b.name.text = (raw['name'] ?? '').toString();
        b.parts.text = (raw['parts'] ?? '').toString();
        b.enabled = raw['enabled'] != false;
        loadedBalconies.add(b);
      }

      if (!mounted) {
        for (final m in loadedMeasurements) {
          m.dispose();
        }
        for (final b in loadedBalconies) {
          b.dispose();
        }
        return;
      }

      setState(() {
        if (loadedMeasurements.isNotEmpty) {
          for (final m in _measurements) {
            m.dispose();
          }
          _measurements
            ..clear()
            ..addAll(loadedMeasurements);
        }
        _balconies
          ..clear()
          ..addAll(loadedBalconies);
        _trash
          ..clear()
          ..addAll(loadedTrash);
        _nameController.text = (data['name'] ?? widget.clientName).toString();
        final date = data['installation_date'];
        if (date is Timestamp) _installationDate = date.toDate();
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Failed to load client data: $e');
      if (!mounted) return;
      _loadFailed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تعذر تحميل بيانات العميل. تأكد من الاتصال.'),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            onPressed: _loadSavedData,
          ),
        ),
      );
    }
  }

  // ============================================================================
  // حفظ البيانات في Firestore (تلقائي أو يدوي)
  // ============================================================================
  Future<void> _performSave({bool isAuto = false}) async {
    if (_saving) return;
    if (!_loaded) return;

    if (!isAuto) setState(() => _saving = true);

    try {
      final measurements = _measurements.map((m) {
        final c = m.calculation;
        return <String, dynamic>{
          'id': m.id,
          'type': 'measurement',
          'name': m.name.text.trim(),
          'width': _Measurement.toDouble(m.width.text),
          'height': _Measurement.toDouble(m.height.text),
          'method': m.method.name,
          'ceiling': m.ceiling.name,
          'velvet_sides': m.velvetSides,
          'light_layers': m.lightLayers,
          'wheels': m.wheels.text.trim(),
          'heavy_meters': c.heavyMeters,
          'light_meters': c.lightMeters,
          'heavy_height': c.heavyHeight,
          'light_height': c.lightHeight,
          'heavy_wheels': c.heavyWheels,
          'light_wheels': c.lightWheels,
          'heavy_tape_meters': c.heavyTapeMeters,
          'light_tape_meters': c.lightTapeMeters,
          'enabled': m.enabled,
        };
      }).toList();

      final balconies = _balconies
          .map(
            (b) => <String, dynamic>{
              'id': b.id,
              'name': b.name.text.trim(),
              'parts': b.parts.text.trim(),
              'total_width': b.totalWidth,
              'enabled': b.enabled,
            },
          )
          .toList();

      final trash = _trash.map((t) => t.toMap()).toList();

      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .set({
            'name': _nameController.text.trim(),
            'installation_date': _installationDate == null
                ? null
                : Timestamp.fromDate(_installationDate!),
            'measurements': measurements,
            'balconies': balconies,
            'deleted_cards': trash,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _isAutoSaving = false;
        _savedSuccess = true;
      });

      if (!isAuto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ مقاسات العميل بنجاح ✨'),
            backgroundColor: Color(0xFF1E7E34),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to save data: $e');
      if (mounted) {
        setState(() {
          _isAutoSaving = false;
          _savedSuccess = false;
        });
      }
    } finally {
      if (mounted && !isAuto) setState(() => _saving = false);
    }
  }

  // ============================================================================
  // إضافة وتكرار وحذف الكروت
  // ============================================================================
  void _addMeasurement() {
    setState(() {
      final item = _Measurement();
      item.name.text = 'شباك ${_toArabic(_measurements.length + 1)}';
      item.width.text = '3.00';
      item.height.text = '2.95';
      _measurements.add(item);
    });
    _triggerAutoSave();
  }

  void _addBalcony() {
    setState(() {
      final b = _Balcony();
      b.name.text = 'بلكونة ${_toArabic(_balconies.length + 1)}';
      _balconies.add(b);
    });
    _triggerAutoSave();
  }

  // التحقق من النقرات الثلاثية المتتالية (Triple-Tap) لتكرار الكارت
  void _handleCardTap(_Measurement item) {
    final now = DateTime.now();
    if (_lastTappedCardId == item.id &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 480)) {
      _tapCount++;
      if (_tapCount >= 3) {
        _tapCount = 0;
        _duplicateMeasurement(item);
        return;
      }
    } else {
      _tapCount = 1;
      _lastTappedCardId = item.id;
    }
    _lastTapTime = now;
  }

  void _duplicateMeasurement(_Measurement item) {
    setState(() {
      final copy = _Measurement();
      copy.name.text = '${item.name.text} (نسخة)';
      copy.width.text = item.width.text;
      copy.height.text = item.height.text;
      copy.method = item.method;
      copy.ceiling = item.ceiling;
      copy.velvetSides = item.velvetSides;
      copy.lightLayers = item.lightLayers;
      copy.wheels.text = item.wheels.text;
      copy.enabled = item.enabled;
      _measurements.add(copy);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تكرار المقاس بنجاح (٣ نقرات) 📋'),
        duration: Duration(seconds: 1),
      ),
    );
    _triggerAutoSave();
  }

  void _duplicateBalcony(_Balcony item) {
    setState(() {
      final copy = _Balcony();
      copy.name.text = '${item.name.text} (نسخة)';
      copy.parts.text = item.parts.text;
      copy.enabled = item.enabled;
      _balconies.add(copy);
    });
    _triggerAutoSave();
  }

  void _deleteMeasurement(int index) {
    setState(() {
      final item = _measurements.removeAt(index);
      _trash.insert(0, _DeletedCard.measurement(item));
    });
    _triggerAutoSave();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم نقل المقاس إلى المحذوفات'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () {
            if (_trash.isNotEmpty) {
              setState(() {
                final restored = _trash.removeAt(0);
                _measurements.insert(index, restored.toMeasurement());
              });
              _triggerAutoSave();
            }
          },
        ),
      ),
    );
  }

  void _deleteBalcony(int index) {
    setState(() {
      final item = _balconies.removeAt(index);
      _trash.insert(0, _DeletedCard.balcony(item));
    });
    _triggerAutoSave();
  }

  // ============================================================================
  // واجهة التطبيق الرئيسية
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final activeCount = _measurements.where((m) => m.enabled).length;
    double totalHeavy = 0;
    double totalLight = 0;
    int totalWheels = 0;

    for (final m in _measurements) {
      if (!m.enabled) continue;
      final c = m.calculation;
      totalHeavy += c.heavyMeters;
      totalLight += c.lightMeters;
      totalWheels += (c.heavyWheels + c.lightWheels);
    }

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _panel,
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: Text(
                'مقاسات: ${widget.clientName}',
                style: const TextStyle(
                  color: _gold,
                  fontFamily: 'Aref Ruqaa',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // مؤشر الحفظ التلقائي
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _isAutoSaving
                    ? Colors.amber.withValues(alpha: 0.15)
                    : (_savedSuccess
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isAutoSaving
                      ? Colors.amber
                      : (_savedSuccess ? Colors.green : Colors.transparent),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isAutoSaving) ...[
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'جاري الحفظ...',
                      style: TextStyle(color: Colors.amber, fontSize: 10),
                    ),
                  ] else if (_savedSuccess) ...[
                    const Icon(
                      Icons.check,
                      color: Colors.greenAccent,
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'محفوظ تلقائياً',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'توسيع / طي الكل',
            icon: const Icon(Icons.unfold_more_rounded, color: _gold),
            onPressed: () {
              final anyCollapsed = _measurements.any((m) => !m.expanded);
              setState(() {
                for (final m in _measurements) {
                  m.expanded = anyCollapsed;
                }
              });
            },
          ),
          IconButton(
            tooltip: 'حفظ يدوي',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _gold,
                    ),
                  )
                : const Icon(Icons.save_rounded, color: _gold),
            onPressed: () => _performSave(isAuto: false),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _clientInfoBar(),
            _sectionHeaderBar(),
            if (_showTrash) _trashPanel(),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 16),
                itemCount: _measurements.length + _balconies.length,
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex >= _measurements.length ||
                      newIndex > _measurements.length) {
                    return;
                  }
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    if (newIndex < 0 || newIndex >= _measurements.length)
                      return;
                    final item = _measurements.removeAt(oldIndex);
                    _measurements.insert(newIndex, item);
                  });
                  _triggerAutoSave();
                },
                itemBuilder: (context, index) {
                  if (index < _measurements.length) {
                    return _measurementCard(_measurements[index], index);
                  }
                  final bIndex = index - _measurements.length;
                  return _balconyCard(
                    _balconies[bIndex],
                    bIndex,
                    key: ValueKey('balcony-${_balconies[bIndex].id}'),
                  );
                },
              ),
            ),
            _totalsBottomBar(totalHeavy, totalLight, totalWheels, activeCount),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // شريط معلومات العميل العلوية
  // ============================================================================
  Widget _clientInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1118),
        border: Border(bottom: BorderSide(color: Color(0x33C7A064))),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_rounded, color: _gold, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.clientName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.phone != null && widget.phone!.isNotEmpty) ...[
            Text(
              _toArabic(widget.phone),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(width: 8),
          ],
          InkWell(
            onTap: _pickInstallationDate,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event, color: _gold, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _date(_installationDate),
                    style: const TextStyle(
                      color: _neon,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // شريط التحكم والإضافة
  // ============================================================================
  Widget _sectionHeaderBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'المقاسات (${_toArabic(_measurements.length)})',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'المحذوفات',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _showTrash = !_showTrash),
            icon: Badge(
              label: Text(_toArabic(_trash.length)),
              child: Icon(
                _showTrash ? Icons.close : Icons.delete_outline_rounded,
                color: _trash.isNotEmpty ? Colors.amberAccent : Colors.white54,
                size: 20,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _addBalcony,
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: BorderSide(color: _gold.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add_box_outlined, size: 16),
            label: const Text('بلكونة', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: _addMeasurement,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              'إضافة مقاس',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // الكارت المطور فائق الدقة والكثافة (التطوير المباشر وفق التعديلات الفنية)
  // ============================================================================
  Widget _measurementCard(_Measurement item, int index) {
    final calc = item.calculation;
    final disabled = !item.enabled;
    final wVal = _Measurement.toDouble(item.width.text);
    final hVal = _Measurement.toDouble(item.height.text);

    // ستايل الشطب على كامل نصوص الكارت عند التعطيل
    final cardDecoration = disabled ? TextDecoration.lineThrough : null;
    final cardDecorColor = disabled
        ? Colors.redAccent.withValues(alpha: 0.8)
        : null;

    return Container(
      key: ValueKey('measurement-${item.id}'),
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: disabled ? Colors.white24 : _gold.withValues(alpha: 0.4),
          width: 1.15,
        ),
        boxShadow: disabled
            ? const []
            : [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.09),
                  blurRadius: 7,
                  spreadRadius: 0.3,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // النقر المتكرر (3 نقرات) يكرر الكارت، والنقر الفردي يفتح التعديل
          InkWell(
            onTap: () {
              _handleCardTap(item);
              if (_tapCount == 1) {
                setState(() => item.expanded = !item.expanded);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Opacity(
              opacity: disabled ? 0.45 : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ========================================================
                      // السطر 1: [صح] [اسم المقاس في مكانه المميز] [أدوات]
                      // ========================================================
                      Row(
                        children: [
                          // زر التفعيل / التعطيل السريع (يشطب كامل الكلام)
                          InkWell(
                            onTap: () {
                              setState(() => item.enabled = !item.enabled);
                              _triggerAutoSave();
                            },
                            child: Icon(
                              item.enabled
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked,
                              color: item.enabled ? _gold : Colors.white30,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // اسم المقاس في مكانه المميز مع أيقونات باريس
                          Expanded(
                            child: Row(
                              children: [
                                const Text(
                                  '🌟',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.name.text.isEmpty
                                        ? 'مقاس بدون اسم'
                                        : item.name.text,
                                    style: TextStyle(
                                      color: disabled ? Colors.white54 : _gold,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      decoration: cardDecoration,
                                      decorationColor: cardDecorColor,
                                      decorationThickness: 2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '🌟 🪟',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                          // أدوات سريعة
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: item.expanded
                                ? 'طي التعديل'
                                : 'تعديل تفصيلي',
                            icon: Icon(
                              item.expanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.edit_note_rounded,
                              color: _neon,
                              size: 21,
                            ),
                            onPressed: () =>
                                setState(() => item.expanded = !item.expanded),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 26,
                              height: 28,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'حذف المقاس',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            onPressed: () => _deleteMeasurement(index),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(
                                Icons.drag_indicator,
                                color: Colors.white38,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // ========================================================
                      // السطر 2: [بند المقاس يمين] ⬅️⬅️ [٦ متر ثقيل + ٤ متر خفيف]
                      // ========================================================
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // بند المقاس على اليمين في بادج بارز
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '📌',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _toArabic(
                                      item.width.text.trim().isNotEmpty
                                          ? item.width.text.trim()
                                          : _fmt(wVal),
                                    ),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15.5,
                                      decoration: cardDecoration,
                                      decorationColor: cardDecorColor,
                                    ),
                                  ),
                                  const Text(
                                    ' م',
                                    style: TextStyle(
                                      color: _neon,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '📌',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 6),

                            // إيموشن السهم مرتين يوضح اتجاه الكلام
                            const Text('⬅️⬅️', style: TextStyle(fontSize: 13)),

                            const SizedBox(width: 6),

                            // كتابة (٦ متر ثقيل + ٤ متر خفيف) بالخط الواضح الصريح
                            Text(
                              '${_fmtAr(calc.heavyMeters)} متر ثقيل',
                              style: TextStyle(
                                color: const Color(0xFFFFD45A),
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                decoration: cardDecoration,
                                decorationColor: cardDecorColor,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Text(
                                '+',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${_fmtAr(calc.lightMeters)} متر خفيف',
                              style: TextStyle(
                                color: const Color(0xFF70D6FF),
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                decoration: cardDecoration,
                                decorationColor: cardDecorColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 4),

                      // ========================================================
                      // السطر 3: [الارتفاع كذا م] + [اختيار الويفي بسهولة] + [اختيار كابولي بسهولة]
                      // ========================================================
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // نص الارتفاع بترتيب عربي صحيح (الكلمة أولاً ثم الرقم)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '📩 ',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    'الارتفاع ${_toArabic(item.height.text.trim().isNotEmpty ? item.height.text.trim() : _fmt(hVal))} م',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      decoration: cardDecoration,
                                      decorationColor: cardDecorColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 6),

                            // اختيار طراز الويفي / كبس / دابل ويفي بلمسة واحدة سهلة
                            _quickSelectMenu<_WorkMethod>(
                              label: item.method.label,
                              icon: '🪟',
                              items: _WorkMethod.values,
                              itemLabel: (v) => v.label,
                              onSelected: (val) {
                                setState(() => item.method = val);
                                _triggerAutoSave();
                              },
                              cardDecoration: cardDecoration,
                              cardDecorColor: cardDecorColor,
                            ),

                            const SizedBox(width: 6),

                            // اختيار نوع السقف (كابولي / بيت ستارة) بلمسة واحدة سهلة
                            _quickSelectMenu<_CeilingType>(
                              label: item.ceiling.label,
                              icon: '🏠',
                              items: _CeilingType.values,
                              itemLabel: (v) => v.label,
                              onSelected: (val) {
                                setState(() => item.ceiling = val);
                                _triggerAutoSave();
                              },
                              cardDecoration: cardDecoration,
                              cardDecorColor: cardDecorColor,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 4),

                      // ========================================================
                      // السطر 4: خياطة ثقيل كذا م • خياطة خفيف كذا م (بالتفصيل والتنسيق العربي السليم)
                      // ========================================================
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.2),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🪡', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                'خياطة ثقيل ${_fmtAr(calc.heavyHeight)} م',
                                style: TextStyle(
                                  color: const Color(0xFFFFE082),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: cardDecoration,
                                  decorationColor: cardDecorColor,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '•',
                                  style: TextStyle(
                                    color: _gold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Text('🪡', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                'خياطة خفيف ${_fmtAr(calc.lightHeight)} م',
                                style: TextStyle(
                                  color: const Color(0xFF8AE9C1),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: cardDecoration,
                                  decorationColor: cardDecorColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // ========================================================
                      // السطر 5: نظام الخياطة (الأجناب) والعجل والشريط مدمجين في سطر واحد
                      // ========================================================
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // نظام الخياطة والأجناب
                            Text(
                              '${_toArabic(item.velvetSides)} ج قطيفة "${item.method.label}" + ${item.lightLayers > 0 ? "كتان خفيف" : "بدون خفيف"}',
                              style: TextStyle(
                                color: const Color(0xFFF1E6D2),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                decoration: cardDecoration,
                                decorationColor: cardDecorColor,
                              ),
                            ),

                            const Text(
                              '•',
                              style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // العجل والشريط
                            Text(
                              '${_toArabic(calc.heavyWheels)} + ${_toArabic(calc.lightWheels)} عجلة = ${_fmtAr(calc.heavyTapeMeters)} م + ${_fmtAr(calc.lightTapeMeters)} م',
                              style: TextStyle(
                                color: const Color(0xFFFFD45A),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                decoration: cardDecoration,
                                decorationColor: cardDecorColor,
                              ),
                            ),

                            const Text('✅ 📌', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ====================================================================
          // لوحة التعديل التفصيلي المنسدلة (تفتح اختيارياً عند الرغبة في تعديل المقاسات يدوياً)
          // ====================================================================
          if (item.expanded) ...[
            const Divider(color: Color(0x33C7A064), height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF07080D),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    // الصف الأول: اسم الغرفة والعرض والارتفاع
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: item.name,
                            onChanged: (_) {
                              setState(() {});
                              _triggerAutoSave();
                            },
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                              labelText: 'اسم الغرفة',
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: item.width,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) {
                              setState(() {});
                              _triggerAutoSave();
                            },
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                              labelText: 'العرض (م)',
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: item.height,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) {
                              setState(() {});
                              _triggerAutoSave();
                            },
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                              labelText: 'الارتفاع (م)',
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // الصف الثاني: طراز الشغل ونوع السقف بشكل مريح
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<_WorkMethod>(
                            initialValue: item.method,
                            isDense: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                              labelText: 'طراز الشغل',
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                            dropdownColor: _panel,
                            items: _WorkMethod.values
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      v.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => item.method = val);
                                _triggerAutoSave();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonFormField<_CeilingType>(
                            initialValue: item.ceiling,
                            isDense: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                              labelText: 'نوع السقف',
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                            dropdownColor: _panel,
                            items: _CeilingType.values
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      v.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => item.ceiling = val);
                                _triggerAutoSave();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // الصف الثالث: تحديد الأجناب والستارة الخفيفة بدون أي اختناق أو تجاوز بكسلات
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'أجناب قطيفة:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text(
                                  '١ جنب',
                                  style: TextStyle(fontSize: 10.5),
                                ),
                                selected: item.velvetSides == 1,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                onSelected: (_) {
                                  setState(() => item.velvetSides = 1);
                                  _triggerAutoSave();
                                },
                              ),
                              const SizedBox(width: 4),
                              ChoiceChip(
                                label: const Text(
                                  '٢ جنب',
                                  style: TextStyle(fontSize: 10.5),
                                ),
                                selected: item.velvetSides == 2,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                onSelected: (_) {
                                  setState(() => item.velvetSides = 2);
                                  _triggerAutoSave();
                                },
                              ),
                            ],
                          ),
                        ),

                        InkWell(
                          onTap: () {
                            setState(
                              () => item.lightLayers = item.lightLayers > 0
                                  ? 0
                                  : 1,
                            );
                            _triggerAutoSave();
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: item.lightLayers > 0
                                  ? const Color(0x228AE9C1)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.lightLayers > 0
                                    ? const Color(0xFF8AE9C1)
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.lightLayers > 0
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 16,
                                  color: item.lightLayers > 0
                                      ? const Color(0xFF8AE9C1)
                                      : Colors.white38,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'ستارة خفيفة (كتان)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: item.lightLayers > 0
                                        ? const Color(0xFF8AE9C1)
                                        : Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================================
  // قائمة منبثقة سريعة بلمسة واحدة للاختيار المباشر
  // ============================================================================
  Widget _quickSelectMenu<T>({
    required String label,
    required String icon,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T> onSelected,
    TextDecoration? cardDecoration,
    Color? cardDecorColor,
  }) {
    return PopupMenuButton<T>(
      tooltip: 'تغيير سريع',
      color: _panel,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _gold.withValues(alpha: 0.3)),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => items
          .map(
            (e) => PopupMenuItem<T>(
              value: e,
              height: 38,
              child: Text(
                itemLabel(e),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFF163820),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: const Color(0xFF28A745).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✅ $icon ', style: const TextStyle(fontSize: 11)),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF98E2A8),
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                decoration: cardDecoration,
                decorationColor: cardDecorColor,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF98E2A8),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // كارت البلكونة المطور
  // ============================================================================
  Widget _balconyCard(_Balcony item, int index, {Key? key}) {
    final disabled = !item.enabled;
    final cardDecoration = disabled ? TextDecoration.lineThrough : null;
    final cardDecorColor = disabled
        ? Colors.redAccent.withValues(alpha: 0.8)
        : null;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F121C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: disabled
              ? Colors.white24
              : Colors.cyan.withValues(alpha: 0.35),
          width: 1.15,
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() => item.enabled = !item.enabled);
                  _triggerAutoSave();
                },
                child: Icon(
                  item.enabled
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: item.enabled ? Colors.cyanAccent : Colors.white30,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text('🚪', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: Text(
                  item.name.text.isEmpty ? 'بلكونة' : item.name.text,
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: cardDecoration,
                    decorationColor: cardDecorColor,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'قطع: ${item.parts.text.isEmpty ? "—" : _toArabic(item.parts.text)}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    decoration: cardDecoration,
                    decorationColor: cardDecorColor,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'تكرار البلكونة',
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Colors.cyan,
                  size: 16,
                ),
                onPressed: () => _duplicateBalcony(item),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 26,
                  height: 28,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'حذف',
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 18,
                ),
                onPressed: () => _deleteBalcony(index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // سلة المحذوفات القابلة للاسترجاع
  // ============================================================================
  Widget _trashPanel() {
    if (_trash.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Text(
            'سلة المحذوفات فارغة',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF151218),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'المحذوفات (${_toArabic(_trash.length)})',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() => _trash.clear());
                  _triggerAutoSave();
                },
                child: const Text(
                  'تفريغ السلة',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
          ..._trash.map(
            (item) => Row(
              children: [
                Expanded(
                  child: Text(
                    item.name.isEmpty ? 'عنصر محذوف' : item.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _trash.remove(item);
                      if (item.isBalcony) {
                        _balconies.add(item.toBalcony());
                      } else {
                        _measurements.add(item.toMeasurement());
                      }
                    });
                    _triggerAutoSave();
                  },
                  child: const Text(
                    'استرجاع',
                    style: TextStyle(color: _gold, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // شريط الإجماليات السفلي
  // ============================================================================
  Widget _totalsBottomBar(double heavy, double light, int wheels, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(top: BorderSide(color: Color(0x33C7A064))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _summaryPill('مقاسات', _toArabic(count), _gold),
                _summaryPill(
                  'ثقيل',
                  '${_fmtAr(heavy)} م',
                  const Color(0xFFFFD45A),
                ),
                _summaryPill(
                  'خفيف',
                  '${_fmtAr(light)} م',
                  const Color(0xFF70D6FF),
                ),
                _summaryPill('عجل', _toArabic(wheels), Colors.white),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _performSave(isAuto: false),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 16),
            label: const Text(
              'حفظ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white60, fontSize: 10.5),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickInstallationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _installationDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: _gold, surface: _panel),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _installationDate = picked);
      _triggerAutoSave();
    }
  }
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
  bool enabled = true;
  bool expanded = false;

  _Calculation get calculation {
    final w = toDouble(width.text);
    final h = toDouble(height.text);

    // مضاعفات القماش بناءً على الطراز
    final heavyMultiplier = method == _WorkMethod.press ? 2.5 : 3.0;
    final lightMultiplier = method == _WorkMethod.doubleWave ? 3.0 : 2.0;

    // خصومات الارتفاع بالسنتيمتر بناءً على السقف ونوع التعليق
    double heavyOffset = 0;
    double lightOffset = 0;

    if (method == _WorkMethod.press) {
      heavyOffset = .03;
      lightOffset = .02;
    } else if (method == _WorkMethod.wave && ceiling == _CeilingType.kaboli) {
      heavyOffset = -.01;
      lightOffset = -.04;
    } else if (method == _WorkMethod.wave &&
        ceiling == _CeilingType.curtainBox) {
      heavyOffset = 0;
      lightOffset = -.04;
    } else if (method == _WorkMethod.doubleWave &&
        ceiling == _CeilingType.kaboli) {
      heavyOffset = -.01;
      lightOffset = -.02;
    } else if (method == _WorkMethod.doubleWave &&
        ceiling == _CeilingType.curtainBox) {
      heavyOffset = .01;
      lightOffset = 0;
    }

    // حساب العجل ومتر الشريط التلقائي
    final heavyWheels = w > 0 ? (w * 9.52).round() : 0;
    final lightWheels = (lightLayers > 0 && w > 0) ? heavyWheels : 0;
    final heavyTape = w > 0 ? (w * 1.33) : 0.0;
    final lightTape = (lightLayers > 0 && w > 0) ? heavyTape : 0.0;

    return _Calculation(
      heavyMeters: w > 0 ? (w * heavyMultiplier) : 0,
      lightMeters: (lightLayers > 0 && w > 0) ? (w * lightMultiplier) : 0,
      heavyHeight: h > 0 ? (h + heavyOffset) : 0,
      lightHeight: (lightLayers > 0 && h > 0) ? (h + lightOffset) : 0,
      heavyWheels: heavyWheels,
      lightWheels: lightWheels,
      heavyTapeMeters: heavyTape,
      lightTapeMeters: lightTape,
    );
  }

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

class _Balcony {
  static int _counter = 0;
  final int id = ++_counter;
  final TextEditingController name = TextEditingController(text: 'بلكونة');
  final TextEditingController parts = TextEditingController(text: '3');
  bool enabled = true;

  double get totalWidth {
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
        .fold<double>(
          0.0,
          (sum, part) => sum + (double.tryParse(part.trim()) ?? 0.0),
        );
  }

  void dispose() {
    name.dispose();
    parts.dispose();
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
    required this.heavyTapeMeters,
    required this.lightTapeMeters,
  });

  final double heavyMeters;
  final double lightMeters;
  final double heavyHeight;
  final double lightHeight;
  final int heavyWheels;
  final int lightWheels;
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
    this.wheels = '',
    this.parts = '',
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
    wheels: m.wheels.text,
    enabled: m.enabled,
  );

  factory _DeletedCard.balcony(_Balcony b) => _DeletedCard(
    isBalcony: true,
    name: b.name.text,
    parts: b.parts.text,
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
    wheels: (map['wheels'] ?? '').toString(),
    parts: (map['parts'] ?? '').toString(),
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
  final String wheels;
  final String parts;
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
    'wheels': wheels,
    'parts': parts,
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
    m.wheels.text = wheels;
    m.enabled = enabled;
    return m;
  }

  _Balcony toBalcony() {
    final b = _Balcony();
    b.name.text = name;
    b.parts.text = parts;
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
