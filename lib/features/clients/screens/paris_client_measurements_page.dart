import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// شاشة أولية قابلة للدمج داخل تطبيق Paris Curtains.
/// تحفظ بيانات المقاسات داخل مستند العميل في Firestore. يتطلب cloud_firestore.
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
  static const _gold = Color(0xFFFFD45A);
  static const _neon = Color(0xFF27E7F2);
  static const _bg = Color(0xFF090D14);
  static const _panel = Color(0xFF111925);

  late final TextEditingController _nameController;
  late DateTime? _installationDate;
  final List<_Measurement> _measurements = [_Measurement()];
  final List<_Balcony> _balconies = [];
  final List<_DeletedCard> _trash = [];
  int _nextId = 1;
  bool _saving = false;
  bool _showTrash = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.clientName);
    _installationDate = widget.installationDate;
    _loadSavedData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final item in _measurements) {
      item.dispose();
    }
    for (final item in _balconies) {
      item.dispose();
    }
    for (final item in _trash) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();
      if (!mounted || !doc.exists) return;
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
        m.velvetSides = (raw['velvet_sides'] as num?)?.toInt() ?? 1;
        m.lightLayers = (raw['light_layers'] as num?)?.toInt() ?? 1;
        m.wheels.text = (raw['wheels'] ?? '').toString();
        m.enabled = raw['enabled'] != false;
        loadedMeasurements.add(m);
      }
      for (final raw in (data['deleted_cards'] as List? ?? const [])) {
        if (raw is Map)
          loadedTrash.add(_DeletedCard.fromMap(Map<String, dynamic>.from(raw)));
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
      });
    } catch (_) {
      /* Keep the editable screen usable if offline; saving will report errors. */
    }
  }

  String _digits(String value) => value
      .replaceAll('0', '٠')
      .replaceAll('1', '١')
      .replaceAll('2', '٢')
      .replaceAll('3', '٣')
      .replaceAll('4', '٤')
      .replaceAll('5', '٥')
      .replaceAll('6', '٦')
      .replaceAll('7', '٧')
      .replaceAll('8', '٨')
      .replaceAll('9', '٩');

  String _date(DateTime? value) => value == null
      ? 'حدد موعد التركيب'
      : _digits(
          '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
        );

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
    if (picked != null) setState(() => _installationDate = picked);
  }

  void _addMeasurement() {
    setState(() {
      final item = _Measurement();
      item.name.text = '';
      item.width.text = '';
      item.height.text = '';
      _nextId++;
      _measurements.add(item);
    });
  }

  void _addBalcony() {
    setState(() => _balconies.add(_Balcony()));
  }

  Future<void> _saveData() async {
    if (_saving) return;
    setState(() => _saving = true);
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
          'heavy_meters': c.heavyMeters,
          'light_meters': c.lightMeters,
          'heavy_height': c.heavyHeight,
          'light_height': c.lightHeight,
          'velvet_sides': m.velvetSides,
          'light_layers': m.lightLayers,
          'wheels': m.wheels.text.trim(),
          'enabled': m.enabled,
        };
      }).toList();
      final balconies = _balconies
          .map(
            (b) => <String, dynamic>{
              'id': b.id,
              'type': 'balcony',
              'name': b.name.text.trim(),
              'parts': b.parts.text.trim(),
              'width': b.totalWidth,
              'duck_meters': b.totalWidth * 1.5,
              'height': 2.8,
              'enabled': b.enabled,
            },
          )
          .toList();
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
            'deleted_cards': _trash.map((t) => t.toMap()).toList(),
            'measurements_updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ بيانات العميل والمقاسات')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'بيانات العميل',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _clientHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'المقاسات',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'سلة المحذوفات',
                    onPressed: () => setState(() => _showTrash = !_showTrash),
                    icon: Badge(
                      label: Text('${_trash.length}'),
                      child: Icon(
                        _showTrash ? Icons.close : Icons.delete_sweep_outlined,
                        color: _neon,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إضافة بلكونة',
                    onPressed: _addBalcony,
                    icon: const Icon(Icons.add_circle, color: _neon),
                  ),
                  const SizedBox(width: 2),
                  FilledButton.icon(
                    onPressed: _addMeasurement,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 19),
                    label: const Text(
                      'إضافة مقاس',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            if (_showTrash) _trashPanel(),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 18),
                itemCount: _measurements.length + _balconies.length,
                onReorder: (oldIndex, newIndex) {
                  // Keep drag-reordering safe while the list contains two card types.
                  // Measurement cards can be reordered among measurement positions only;
                  // balcony cards are not passed into the measurements list by mistake.
                  if (oldIndex >= _measurements.length ||
                      newIndex > _measurements.length)
                    return;
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    if (newIndex < 0 || newIndex >= _measurements.length)
                      return;
                    final item = _measurements.removeAt(oldIndex);
                    _measurements.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  if (index < _measurements.length)
                    return _measurementCard(_measurements[index], index);
                  final bIndex = index - _measurements.length;
                  return _balconyCard(
                    _balconies[bIndex],
                    bIndex,
                    key: ValueKey(_balconies[bIndex].id),
                  );
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: const BoxDecoration(
                color: _panel,
                border: Border(top: BorderSide(color: _neon, width: .6)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'واجهة الإكسسوارات ستُضاف في الخطوة التالية',
                              ),
                            ),
                          ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: const BorderSide(color: _gold),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.widgets_outlined),
                      label: const Text(
                        'الإكسسوارات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveData,
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'جارٍ الحفظ' : 'حفظ البيانات'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clientHeader() => Container(
    margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _gold.withValues(alpha: .65)),
      boxShadow: [
        BoxShadow(color: _gold.withValues(alpha: .08), blurRadius: 14),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _editClientName,
              tooltip: 'تعديل الاسم',
              icon: const Icon(Icons.edit_rounded, color: _gold),
            ),
            Expanded(
              child: Text(
                _nameController.text,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.person_pin_rounded, color: _gold, size: 27),
          ],
        ),
        InkWell(
          onTap: _pickInstallationDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withValues(alpha: .35)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: _gold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _date(_installationDate),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Text(
                  'موعد التركيب',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _editClientName() async {
    final controller = TextEditingController(text: _nameController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'تعديل اسم العميل',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'اسم العميل',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty)
      setState(() => _nameController.text = result.trim());
    controller.dispose();
  }

  void _duplicateMeasurement(_Measurement source) {
    final copy = _Measurement()
      ..name.text = source.name.text
      ..width.text = source.width.text
      ..height.text = source.height.text
      ..method = source.method
      ..ceiling = source.ceiling
      ..velvetSides = source.velvetSides
      ..lightLayers = source.lightLayers
      ..wheels.text = source.wheels.text
      ..enabled = source.enabled;
    setState(
      () => _measurements.insert(_measurements.indexOf(source) + 1, copy),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('اتعملت نسخة من المقاس — عدّل البيانات الجديدة'),
      ),
    );
  }

  void _duplicateBalcony(_Balcony source) {
    final copy = _Balcony()
      ..name.text = source.name.text
      ..parts.text = source.parts.text
      ..enabled = source.enabled;
    setState(() => _balconies.insert(_balconies.indexOf(source) + 1, copy));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('اتعملت نسخة من البلكونة')));
  }

  void _moveMeasurementToTrash(_Measurement item) {
    setState(() {
      _measurements.remove(item);
      _trash.add(_DeletedCard.measurement(item));
    });
  }

  void _moveBalconyToTrash(_Balcony item) {
    setState(() {
      _balconies.remove(item);
      _trash.add(_DeletedCard.balcony(item));
    });
  }

  void _restoreTrash(_DeletedCard card) {
    setState(() {
      _trash.remove(card);
      if (card.type == 'measurement')
        _measurements.add(card.toMeasurement());
      else
        _balconies.add(card.toBalcony());
    });
  }

  Widget _trashPanel() => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.redAccent.withValues(alpha: .7)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'سلة المحذوفات (${_digits(_trash.length.toString())})',
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_trash.isEmpty)
          const Text(
            'السلة فارغة',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white60),
          ),
        ..._trash.map(
          (card) => Row(
            children: [
              Expanded(
                child: Text(
                  card.name,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                tooltip: 'استرجاع',
                onPressed: () => _restoreTrash(card),
                icon: const Icon(Icons.restore, color: _neon),
              ),
              IconButton(
                tooltip: 'حذف نهائي',
                onPressed: () => setState(() {
                  _trash.remove(card);
                  card.dispose();
                }),
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _measurementCard(_Measurement item, int index) {
    final calc = item.calculation;
    final disabled = !item.enabled;
    return GestureDetector(
      key: ValueKey('measurement-${item.id}'),
      onDoubleTap: () => _duplicateMeasurement(item),
      child: Opacity(
        opacity: disabled ? .48 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          decoration: BoxDecoration(
            color: const Color(0xFF050505),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: disabled ? Colors.white24 : _neon,
              width: 1.5,
            ),
            boxShadow: disabled
                ? const []
                : [
                    BoxShadow(
                      color: _neon.withValues(alpha: .20),
                      blurRadius: 10,
                      spreadRadius: .5,
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Reference-inspired card: emoji markers, bold name and prominent width.
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'تفعيل/تعطيل المقاس',
                    onPressed: () =>
                        setState(() => item.enabled = !item.enabled),
                    icon: Icon(
                      item.enabled
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: item.enabled ? _gold : Colors.white54,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: item.name,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _gold,
                        decoration: disabled
                            ? TextDecoration.lineThrough
                            : null,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '⭐ اسم المقاس',
                        hintStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 112),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _gold, width: 1.2),
                      color: _gold.withValues(alpha: .08),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📌', style: TextStyle(fontSize: 16)),
                        SizedBox(
                          width: 76,
                          child: TextField(
                            controller: item.width,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'العرض',
                              hintStyle: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const Text(
                          'م',
                          style: TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 2, right: 2),
                      child: Icon(Icons.drag_indicator, color: _neon, size: 23),
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0x44FFD45A), height: 13),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 13,
                runSpacing: 5,
                children: [
                  _miniInfo('🪟', item.method.label, _gold),
                  _miniInfo(
                    '🧵',
                    'تقيل ${_digits(_fmt(calc.heavyMeters))} م',
                    Colors.white,
                  ),
                  _miniInfo(
                    '🏳️',
                    'خفيف ${_digits(_fmt(calc.lightMeters))} م',
                    Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 13,
                runSpacing: 4,
                children: [
                  _miniInfo(
                    '📏',
                    'ارتفاع ${_digits(_fmt(_Measurement.toDouble(item.height.text)))} م',
                    _neon,
                  ),
                  _miniInfo(
                    '✅',
                    item.method == _WorkMethod.press
                        ? 'حلقات كبس'
                        : item.method.label,
                    _neon,
                  ),
                  if (item.method != _WorkMethod.press)
                    _miniInfo('🏠', item.ceiling.label, _neon),
                ],
              ),
              if (item.expanded) ...[
                const Divider(color: Colors.white12, height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _gold.withValues(alpha: .35)),
                  ),
                  child: Text(
                    '🪡 ارتفاع الخياطة: تقيل ${_digits(_fmt(calc.heavyHeight))} م  •  خفيف ${_digits(_fmt(calc.lightHeight))} م',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        'ارتفاع الشباك',
                        item.height,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: DropdownButtonFormField<_WorkMethod>(
                        initialValue: item.method,
                        dropdownColor: _panel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: _decoration('طريقة الشغل'),
                        items: _WorkMethod.values
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(m.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          if (v != null) item.method = v;
                        }),
                      ),
                    ),
                    if (item.method != _WorkMethod.press) ...[
                      const SizedBox(width: 7),
                      Expanded(
                        child: DropdownButtonFormField<_CeilingType>(
                          initialValue: item.ceiling,
                          dropdownColor: _panel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          decoration: _decoration('التركيب'),
                          items: _CeilingType.values
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.label),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            if (v != null) item.ceiling = v;
                          }),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: item.velvetSides,
                        dropdownColor: _panel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: _decoration('جنب قطيفة'),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('١ جنب')),
                          DropdownMenuItem(value: 2, child: Text('٢ جنب')),
                        ],
                        onChanged: (v) =>
                            setState(() => item.velvetSides = v ?? 1),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: item.lightLayers,
                        dropdownColor: _panel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: _decoration('الخفيف'),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('طبقة واحدة')),
                          DropdownMenuItem(value: 2, child: Text('طبقتان')),
                        ],
                        onChanged: (v) =>
                            setState(() => item.lightLayers = v ?? 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: item.wheels,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _decoration('🎡 عدد العجل / ملاحظات'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _moveMeasurementToTrash(item),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text('حذف الكارت'),
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => item.expanded = !item.expanded),
                  style: TextButton.styleFrom(
                    foregroundColor: _gold,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    item.expanded ? Icons.expand_less : Icons.expand_more,
                    size: 19,
                  ),
                  label: Text(
                    item.expanded
                        ? 'إخفاء التفاصيل'
                        : 'ارتفاع الخياطة والتفاصيل',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniInfo(String emoji, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 3),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _balconyCard(
    _Balcony item,
    int index, {
    required Key key,
  }) => GestureDetector(
    key: key,
    onDoubleTap: () => _duplicateBalcony(item),
    child: Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF080B10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _neon, width: 1.15),
        boxShadow: [
          BoxShadow(color: _neon.withValues(alpha: .12), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => item.enabled = !item.enabled),
                icon: Icon(
                  item.enabled
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: _gold,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: item.name,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'اسم البلكونة',
                  ),
                ),
              ),
              const Icon(Icons.window_rounded, color: _gold),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.parts,
                  onChanged: (_) => setState(() {}),
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _decoration('أجزاء العرض: ٣ + ١ + ١'),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'الإجمالي ${_digits(_fmt(item.totalWidth))} م',
                style: const TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '🧵 قماش الدك: ${_digits(_fmt(item.totalWidth * 1.5))} م  •  📏 الارتفاع: ٢٫٨ م',
              style: const TextStyle(color: _neon, fontSize: 14),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _duplicateBalcony(item),
                icon: const Icon(Icons.copy, size: 17),
                label: const Text('نسخ'),
              ),
              TextButton.icon(
                onPressed: () => _moveBalconyToTrash(item),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text('حذف'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _numberField(
    String label,
    TextEditingController controller, {
    required ValueChanged<String> onChanged,
  }) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textAlign: TextAlign.right,
    onChanged: onChanged,
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: _decoration(label),
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
    filled: true,
    fillColor: const Color(0xFF0B121C),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _neon),
    ),
  );

  String _fmt(double value) {
    final fixed = value.toStringAsFixed(2);
    if (fixed.endsWith('.00')) return fixed.substring(0, fixed.length - 3);
    if (fixed.endsWith('0')) return fixed.substring(0, fixed.length - 1);
    return fixed;
  }
}

class _Measurement {
  static int _counter = 0;
  final int id = ++_counter;
  final name = TextEditingController(text: 'مقاس');
  final width = TextEditingController(text: '2');
  final height = TextEditingController(text: '2.90');
  final wheels = TextEditingController();
  _WorkMethod method = _WorkMethod.wave;
  _CeilingType ceiling = _CeilingType.kaboli;
  int velvetSides = 1;
  int lightLayers = 1;
  bool enabled = true;
  bool expanded = false;

  _Calculation get calculation {
    final w = toDouble(width.text);
    final h = toDouble(height.text);
    final heavyMultiplier = method == _WorkMethod.press ? 2.5 : 3.0;
    final lightMultiplier = method == _WorkMethod.doubleWave ? 3.0 : 2.0;
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
    return _Calculation(
      heavyMeters: w * heavyMultiplier,
      lightMeters: w * lightMultiplier,
      heavyHeight: (h + heavyOffset).clamp(0, 99).toDouble(),
      lightHeight: (h + lightOffset).clamp(0, 99).toDouble(),
    );
  }

  static double toDouble(String value) {
    final normalized = value
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
        .replaceAll('٫', '.')
        .replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
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
  final name = TextEditingController();
  final parts = TextEditingController();
  bool enabled = true;
  double get totalWidth {
    final normalized = parts.text
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
        .replaceAll('٫', '.')
        .replaceAll(',', '.');
    return normalized
        .split('+')
        .fold<double>(
          0,
          (sum, part) => sum + (double.tryParse(part.trim()) ?? 0),
        );
  }

  void dispose() {
    name.dispose();
    parts.dispose();
  }
}

class _DeletedCard {
  _DeletedCard({required this.type, required this.data});
  factory _DeletedCard.measurement(_Measurement m) => _DeletedCard(
    type: 'measurement',
    data: {
      'name': m.name.text,
      'width': m.width.text,
      'height': m.height.text,
      'method': m.method.name,
      'ceiling': m.ceiling.name,
      'velvet_sides': m.velvetSides,
      'light_layers': m.lightLayers,
      'wheels': m.wheels.text,
      'enabled': m.enabled,
    },
  );
  factory _DeletedCard.balcony(_Balcony b) => _DeletedCard(
    type: 'balcony',
    data: {'name': b.name.text, 'parts': b.parts.text, 'enabled': b.enabled},
  );
  factory _DeletedCard.fromMap(Map<String, dynamic> map) => _DeletedCard(
    type: (map['type'] ?? 'measurement').toString(),
    data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
  );
  final String type;
  final Map<String, dynamic> data;
  String get name => (data['name'] ?? 'كارت بدون اسم').toString();
  Map<String, dynamic> toMap() => {'type': type, 'data': data};
  _Measurement toMeasurement() {
    final m = _Measurement();
    m.name.text = name;
    m.width.text = (data['width'] ?? '').toString();
    m.height.text = (data['height'] ?? '').toString();
    m.method = _WorkMethod.values.firstWhere(
      (v) => v.name == data['method'],
      orElse: () => _WorkMethod.wave,
    );
    m.ceiling = _CeilingType.values.firstWhere(
      (v) => v.name == data['ceiling'],
      orElse: () => _CeilingType.kaboli,
    );
    m.velvetSides = (data['velvet_sides'] as num?)?.toInt() ?? 1;
    m.lightLayers = (data['light_layers'] as num?)?.toInt() ?? 1;
    m.wheels.text = (data['wheels'] ?? '').toString();
    m.enabled = data['enabled'] != false;
    return m;
  }

  _Balcony toBalcony() {
    final b = _Balcony();
    b.name.text = name;
    b.parts.text = (data['parts'] ?? '').toString();
    b.enabled = data['enabled'] != false;
    return b;
  }

  void dispose() {}
}

class _Calculation {
  const _Calculation({
    required this.heavyMeters,
    required this.lightMeters,
    required this.heavyHeight,
    required this.lightHeight,
  });
  final double heavyMeters, lightMeters, heavyHeight, lightHeight;
}

enum _WorkMethod { press, wave, doubleWave }

extension on _WorkMethod {
  String get label => switch (this) {
    _WorkMethod.press => 'حلقات كبس',
    _WorkMethod.wave => 'ويفي',
    _WorkMethod.doubleWave => 'دابل ويفي',
  };
}

enum _CeilingType { kaboli, curtainBox }

extension on _CeilingType {
  String get label => switch (this) {
    _CeilingType.kaboli => 'كابولي',
    _CeilingType.curtainBox => 'بيت ستارة',
  };
}
