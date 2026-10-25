import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import 'package:paris_curtian_app/features/clients/screens/invoice/invoice_page.dart';

part 'measurements/balcony_card.dart';
part 'measurements/measurement_card_hero.dart';
part 'measurements/measurement_card_shell.dart';
part 'measurements/measurement_data.dart';
part 'measurements/measurement_edit_panel.dart';
part 'measurements/measurement_header.dart';
part 'measurements/measurement_models.dart';
part 'measurements/measurement_theme.dart';
part 'measurements/trash_panel.dart';

/// ============================================================================
/// شاشة مقاسات العميل الفاخرة لتطبيق ستائر باريس — Paris Curtains
/// التصميم المطور النهائي الخالي من أي أخطاء والمتوافق مع جميع إصدارات فلاتر:
/// - متوافق مع كافة إصدارات Flutter (استخدام withOpacity بدلاً من withValues)
/// - كروت مدمجة عالية الكثافة تتسع لـ ٥ مقاسات على شاشة الهاتف
/// - تكبير بانبثاق مرن (Spring Pop Zoom) بلمسة واحدة
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

  String _date(DateTime? value) => value == null
      ? 'حدد موعد التركيب'
      : _toArabic(
          '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
        );

  // ============================================================================
  // واجهة التطبيق الرئيسية
  // ============================================================================
  // بيحفظ المقاسات الأول عشان الفاتورة تقراها محدّثة، وبعدين يفتحها
  Future<void> _openInvoice({required bool balcony}) async {
    await _performSave(isAuto: true);
    if (!mounted) return;
    final typed = _nameController.text.trim();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoicePage(
          clientId: widget.clientId,
          clientName: typed.isEmpty ? widget.clientName : typed,
          phone: widget.phone,
          address: widget.address,
        ),
      ),
    );
  }

  // بتتنادى من ملفات الـ extensions بدل setState مباشرة
  void _rebuild(VoidCallback fn) => setState(fn);

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

    return PopScope(
      canPop: _expandedId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _expandedId != null) {
          _closeCard();
        }
      },
      child: Scaffold(
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
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'فاتورة الشقة',
              icon: const Icon(Icons.receipt_long_rounded, color: _gold),
              onPressed: () => _openInvoice(balcony: false),
            ),
            IconButton(
              tooltip: 'فاتورة البلكونة',
              icon: const Icon(Icons.balcony_rounded, color: _gold),
              onPressed: () => _openInvoice(balcony: true),
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
          child: Stack(
            children: [
              Column(
                children: [
                  _clientInfoBar(),
                  _sectionHeaderBar(),
                  if (_showTrash) _trashPanel(),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 2, 10, 16),
                      itemCount: _measurements.length + _balconies.length,
                      onReorderItem: (oldIndex, newIndex) {
                        // onReorderItem يمرر فهرس الوجهة النهائي بعد النقل،
                        // لذلك لا نحتاج إلى إنقاص newIndex كما في onReorder.
                        if (oldIndex >= _measurements.length ||
                            newIndex < 0 ||
                            newIndex >= _measurements.length) {
                          return;
                        }
                        setState(() {
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
                  _totalsBottomBar(
                    totalHeavy,
                    totalLight,
                    totalWheels,
                    activeCount,
                  ),
                ],
              ),
              if (_expandedId != null) _expandedOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  int? _expandedId; // الكارت المكبّر حاليًا
  bool _closing = false;
}
