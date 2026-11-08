import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/sync_status_service.dart';
import '../../../core/widgets/sync_status_banner.dart';
import '../../../core/services/telegram_backup_service.dart';
import 'package:paris_curtains/features/clients/invoice/invoice_page.dart';
import '../data/client_details_repository.dart';

part 'balcony_card.dart';
part 'measurement_card_hero.dart';
part 'measurement_card_shell.dart';
part 'measurement_data.dart';
part 'measurement_edit_panel.dart';
part 'measurement_header.dart';
part 'measurement_image_page.dart';
part 'measurement_models.dart';

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
    extends State<ParisClientMeasurementsPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TabController _tabs;
  final ScrollController _aptScroll = ScrollController();
  final ScrollController _balcScroll = ScrollController();
  DateTime? _installationDate;

  final List<_Measurement> _measurements = [_Measurement()];
  final List<_Balcony> _balconies = [];
  final List<_DeletedCard> _trash = [];

  bool _saving = false;
  bool _isAutoSaving = false;
  bool _savedSuccess = false;

  /// آخر حفظ اتخزّن على الجهاز بس (مفيش نت) ولسه ماترفعش للسيرفر
  bool _savedLocalOnly = false;
  bool _showTrash = false;
  bool _loaded = false;
  bool _loadFailed = false;

  // لو العميل عدّل حاجة، منبدّلش بياناته ببيانات جاية من السيرفر
  bool _userEdited = false;
  String? _loadedSignature;

  // مؤقت الحفظ التلقائي (Debounce Auto-Save)
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.clientName);
    _installationDate = widget.installationDate;
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _loadSavedData();
  }

  @override
  void dispose() {
    // لو المستخدم رجع قبل ما مؤقّت الحفظ التلقائي (٦٥٠ مللي) يخلص، نحفظ
    // آخر تعديل دلوقتي قبل ما الكنترولرز تتقفل (من غير ده كان بيضيع).
    // _performSave بتقرا الكنترولرز بشكل متزامن قبل أول await، ومبتنادّيش
    // setState وإحنا بنتقفل.
    if (_autoSaveTimer?.isActive == true &&
        _userEdited &&
        _loaded &&
        !_loadFailed) {
      unawaited(_performSave(isAuto: true));
    }
    _autoSaveTimer?.cancel();
    _tabs.dispose();
    _aptScroll.dispose();
    _balcScroll.dispose();
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
  // فتح الفاتورة (بيفتح على نفس التبويب اللي واقف عليه: شقة / بلكونة)
  // ============================================================================
  // الحفظ بيتبعت في الخلفية: الكاش المحلي بيتحدّث فورًا والفاتورة بتقرا منه،
  // فمفيش انتظار للسيرفر.
  Future<void> _openInvoice() async {
    _autoSaveTimer?.cancel();
    if (_userEdited) unawaited(_performSave(isAuto: true));
    final typed = _nameController.text.trim();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoicePage(
          clientId: widget.clientId,
          clientName: typed.isEmpty ? widget.clientName : typed,
          phone: widget.phone,
          address: widget.address,
          startOnBalcony: _tabs.index == 1,
        ),
      ),
    );
  }

  // بتتنادى من ملفات الـ extensions بدل setState مباشرة
  void _rebuild(VoidCallback fn) => setState(fn);

  // ============================================================================
  // صورة المقاسات (مشاركة / حفظ / نسخة على تليجرام)
  // ============================================================================
  void _openMeasurementsImage() {
    final rows = <_MeasurementSheetRow>[];

    for (final m in _measurements) {
      if (!m.enabled) continue;
      final w = _Measurement.toDouble(m.width.text);
      final h = _Measurement.toDouble(m.height.text);
      if (w <= 0 && h <= 0) continue;
      final c = m.calculation;
      final name = m.name.text.trim();
      rows.add(
        _MeasurementSheetRow(
          title: name.isEmpty ? 'شباك' : name,
          lines: [
            'المقاس: ${_fmtAr(w)} × ${_fmtAr(h)} م',
            'الطريقة: ${m.method.label} • السقف: ${m.ceiling.label}',
            'قماش ثقيل: ${_fmtAr(c.heavyMeters)} م'
                '${m.lightLayers > 0 ? ' • خفيف: ${_fmtAr(c.lightMeters)} م' : ''}',
            'عجل: ${c.heavyWheelsLabel}'
                '${m.lightLayers > 0 ? ' • خفيف: ${_toArabic(c.lightWheels)}' : ''}'
                ' • شريط: ${_fmtAr(c.heavyTapeMeters)} م',
            'ارتفاع القص: ${_fmtAr(c.heavyHeight)} م'
                '${m.lightLayers > 0 ? ' • خفيف: ${_fmtAr(c.lightHeight)} م' : ''}',
          ],
        ),
      );
    }

    for (final b in _balconies) {
      if (!b.enabled) continue;
      final name = b.name.text.trim();
      rows.add(
        _MeasurementSheetRow(
          title: name.isEmpty ? 'بلكونة' : name,
          lines: [
            'الأضلاع: ${b.sideList.map(_fmtAr).join(' + ')} م',
            'الارتفاع: ${_fmtAr(_Measurement.toDouble(b.height.text))} م',
            'قماش: ${_fmtAr(b.fabricMeters)} م • كبس: ${_fmtAr(b.tapeMeters)} م',
            'أفيز: ${_toArabic(b.avezCount)} • حلقات: ${_toArabic(b.ringsCount)}',
          ],
        ),
      );
    }

    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مفيش مقاسات لسه — ضيف مقاس الأول'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final typed = _nameController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MeasurementImagePage(
          data: _MeasurementSheetData(
            clientName: typed.isEmpty ? widget.clientName : typed,
            phone: widget.phone,
            date: _toArabic(
              '${now.day.toString().padLeft(2, '0')}/'
              '${now.month.toString().padLeft(2, '0')}/${now.year}',
            ),
            rows: rows,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // يعيد البناء عند تغيير الثيم
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
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const SyncStatusBanner(),
                  _clientInfoBar(),
                  _measureTabsBar(),
                  if (_showTrash)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: SingleChildScrollView(child: _trashPanel()),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildBody(),
                        if (_loaded && _expandedId == null)
                          PositionedDirectional(
                            start: 14,
                            bottom: 14,
                            child: _addButton(),
                          ),
                      ],
                    ),
                  ),
                  if (_loaded) _bottomBar(),
                ],
              ),
              if (_expandedId != null) _expandedOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _panel,
      elevation: 0,
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.clientName,
              style: TextStyle(
                color: AppPalette.text,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // مؤشر الحفظ التلقائي
          if (_isAutoSaving || _savedSuccess)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (_isAutoSaving || _savedLocalOnly)
                    ? AppPalette.amberStrong.withValues(alpha: 0.15)
                    : AppPalette.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_isAutoSaving || _savedLocalOnly)
                      ? AppPalette.amberStrong
                      : AppPalette.green,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isAutoSaving) ...[
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppPalette.amberStrong,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'جاري الحفظ...',
                      style: TextStyle(color: AppPalette.amberStrong, fontSize: 10),
                    ),
                  ] else ...[
                    Icon(
                      _savedLocalOnly ? Icons.phone_android_rounded : Icons.check,
                      color: _savedLocalOnly ? AppPalette.amberStrong : AppPalette.mint,
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _savedLocalOnly ? 'محفوظ على الجهاز' : 'محفوظ',
                      style: TextStyle(
                        color: _savedLocalOnly
                            ? AppPalette.amberStrong
                            : AppPalette.mint,
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
          tooltip: 'صورة المقاسات',
          onPressed: _openMeasurementsImage,
          icon: Icon(Icons.image_rounded, color: AppPalette.text.withValues(alpha: 0.7)),
        ),
        IconButton(
          tooltip: 'المحذوفات',
          onPressed: () => _rebuild(() => _showTrash = !_showTrash),
          icon: Badge(
            isLabelVisible: _trash.isNotEmpty,
            label: Text(_toArabic(_trash.length)),
            child: Icon(
              _showTrash ? Icons.close : Icons.delete_outline_rounded,
              color: _trash.isNotEmpty ? AppPalette.amber : AppPalette.text.withValues(alpha: 0.54),
            ),
          ),
        ),
        IconButton(
          tooltip: 'حفظ يدوي',
          icon: _saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
                )
              : Icon(Icons.save_rounded, color: _gold),
          onPressed: () => _performSave(isAuto: false),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (!_loaded) {
      if (_loadFailed) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, color: AppPalette.text.withValues(alpha: 0.38), size: 46),
              const SizedBox(height: 10),
              Text(
                'تعذر تحميل المقاسات. تأكد من الاتصال.',
                style: TextStyle(color: AppPalette.text.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _loadFailed = false);
                  _loadSavedData();
                },
                style: OutlinedButton.styleFrom(foregroundColor: _gold),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        );
      }
      return Center(child: CircularProgressIndicator(color: _gold));
    }
    return TabBarView(
      controller: _tabs,
      children: [_apartmentTab(), _balconyTab()],
    );
  }

  // ============================== تبويب الشقة ==============================
  Widget _apartmentTab() {
    return Column(
      children: [
        Expanded(
          child: _measurements.isEmpty
              ? _emptyTab(
                  Icons.window_outlined,
                  'مفيش مقاسات لسه',
                  'اضغط "إضافة مقاس" وابدأ',
                )
              : ReorderableListView.builder(
                  key: const PageStorageKey<String>('apartment-list'),
                  scrollController: _aptScroll,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
                  itemCount: _measurements.length,
                  onReorderItem: (oldIndex, newIndex) {
                    // onReorderItem بيمرر فهرس الوجهة النهائي بعد النقل
                    if (newIndex < 0 || newIndex >= _measurements.length) {
                      return;
                    }
                    setState(() {
                      final item = _measurements.removeAt(oldIndex);
                      _measurements.insert(newIndex, item);
                    });
                    _triggerAutoSave();
                  },
                  itemBuilder: (context, index) =>
                      _measurementCard(_measurements[index], index),
                ),
        ),
      ],
    );
  }

  // ============================== تبويب البلكونات ==============================
  Widget _balconyTab() {
    return Column(
      children: [
        Expanded(
          child: _balconies.isEmpty
              ? _emptyTab(
                  Icons.balcony_rounded,
                  'مفيش بلكونات لسه',
                  'اضغط "إضافة بلكونة" وابدأ',
                )
              : ListView.builder(
                  key: const PageStorageKey<String>('balcony-list'),
                  controller: _balcScroll,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
                  itemCount: _balconies.length,
                  itemBuilder: (context, index) => _balconyCard(
                    _balconies[index],
                    index,
                    key: ValueKey('balcony-${_balconies[index].id}'),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _emptyTab(IconData icon, String text, String hint) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _line, size: 52),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: AppPalette.text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(hint, style: TextStyle(color: _muted, fontSize: 13)),
        ],
      ),
    );
  }

  /// زرار الإضافة العائم: بيضيف مقاس (تبويب الشقة) أو بلكونة (تبويب البلكونات)
  Widget _addButton() {
    final isBalcony = _tabs.index == 1;
    return FloatingActionButton.extended(
      heroTag: 'add-measurement-fab',
      onPressed: isBalcony ? _addBalcony : _addMeasurement,
      backgroundColor: _gold,
      foregroundColor: Colors.black,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, size: 24),
      label: Text(
        isBalcony ? 'إضافة بلكونة' : 'إضافة مقاس',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
      ),
    );
  }

  int? _expandedId; // الكارت المكبّر حاليًا
  bool _closing = false;
}
