import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/work_stage.dart';
import '../../../core/services/sync_status_service.dart';
import '../../../core/utils/digits.dart';
import '../../../core/widgets/stage_widgets.dart';
import '../data/client_details_repository.dart';
import 'invoice_calculator.dart';
import 'invoice_image_page.dart';
import 'invoice_meta.dart';
import 'invoice_share_card.dart';
import 'price_settings_page.dart';

part 'invoice_sections.dart';
part 'invoice_summary_bar.dart';
part 'invoice_quick_edit.dart';
part 'invoice_payments_dialog.dart';
part 'invoice_custom_dialogs.dart';
part 'invoice_share.dart';

// ألوان الفاتورة (لون مميز واحد = الذهبي، عشان الشكل يبقى هادي وواضح)
Color get _kBg => AppPalette.bg;
Color get _kPanel => AppPalette.panel;
Color get _kLine => AppPalette.line;
Color get _kGold => AppPalette.gold;
Color get _kMuted => AppPalette.muted;
Color get _kGreen => AppPalette.green;

// مراحل الشغل: المصدر الوحيد في core/constants/work_stage.dart
const Map<int, Color> _kStageColors = WorkStage.colors;

/// دالة مساعدة لتحويل أي نص أو رقم إلى أرقام عربية مشرقية (٠١٢٣٤٥٦٧٨٩)
String _arNum(dynamic value) => toArabicDigits(value);

/// قراءة الأرقام بأمان من أي نوع (double, int, String, null)
/// تحل مشكلة type 'Null' is not a subtype of type 'String'
/// ومشكلة type 'double' is not a subtype of type 'String'
double _safeNum(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  final s = val.toString();
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = arabic.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  final clean = b
      .toString()
      .replaceAll('،', '.')
      .replaceAll('٫', '.')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(clean) ?? 0.0;
}

/// الأرقام المالية بتتكتب لاتينية (14925) عشان تتنسخ وتتطابق بسهولة مع
/// كشف الحساب أو التحويل. التواريخ والموبايل لسه بأرقام عربية في مكانها.
String _money(dynamic v) {
  final d = _safeNum(v);
  final r = roundMoney(d);
  if (r == r.roundToDouble()) {
    return r.toInt().toString();
  }
  return r.toStringAsFixed(2);
}

String _fmtQty(dynamic q) {
  final d = _safeNum(q);
  if (d == d.roundToDouble()) {
    return d.toInt().toString();
  }
  return d.toStringAsFixed(2);
}

/// ============================================================================
/// صفحة فاتورة ستائر باريس الفاخرة — تجربة بريميوم عربية متكاملة
/// ترتيب الأعمدة: [الكمية] | [البند] | [السعر] | [الإجمالي]
/// بدون نصوص فرعية مشتتة، أرقام عربية مشرقية، وتعديل فوري ذكي
/// ============================================================================
class InvoicePage extends StatefulWidget {
  const InvoicePage({
    super.key,
    required this.clientId,
    required this.clientName,
    this.phone,
    this.address,
    this.startOnBalcony = false,
  });

  final String clientId;
  final String clientName;
  final String? phone;
  final String? address;
  final bool startOnBalcony;

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  String? _loadError;

  // المدخلات المجلوبة من قياسات العميل
  List<WindowSpec> _windows = [];
  List<BalconySpec> _balconies = [];

  // أسعار مخصصة
  final Map<String, double> _customPrices = {};

  // تعديلات يدوية على البنود المحسوبة (key -> override)
  final Map<String, double> _aptQtyOverride = {};
  final Map<String, double> _aptPriceOverride = {};
  final Map<String, double> _balcQtyOverride = {};
  final Map<String, double> _balcPriceOverride = {};

  // بنود إضافية مخصصة
  final List<InvoiceLine> _aptCustomLines = [];
  final List<InvoiceLine> _balcCustomLines = [];

  // البنود المستبعدة من الإجمالي (مفاتيح البنود)
  final Set<String> _aptExcluded = {};
  final Set<String> _balcExcluded = {};
  bool _hideExcluded = false;

  // لقطة الأسعار: لو الفاتورة محفوظة قبل كده، أسعارها متجمّدة ومش بتتأثر
  // بتغيير «ثوابت الحساب». بنعرض تنبيه صغير يوضّح ده للمستخدم.
  bool _pricesFrozen = false;
  DateTime? _pricesFrozenAt;
  List<PriceDef> _missingFrozenDefs = const [];
  bool _frozenNoteHidden = false;

  // نوع قماش البلكونة
  String _balconyFabricKey = 'fabric_dak';

  // خصم الفاتورة (اختياري)
  InvoiceDiscount _discount = const InvoiceDiscount();

  // المدفوع (مجموع سجل الدفعات) + هوية الفاتورة
  double _depositPaid = 0;
  final List<InvoicePayment> _payments = [];
  String? _invoiceNumber;
  DateTime? _issuedAt;

  // حالة الحفظ
  Timer? _autoSaveTimer;
  bool _saving = false;
  bool _savedRecently = false;
  bool _saveFailed = false;
  int _stage = 1; // مرحلة الشغل للعميل

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.startOnBalcony ? 1 : 0,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    // لو فيه تعديل لسه ما اتحفظش، نحفظه قبل ما نقفل الصفحة
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer!.cancel();
      _writeInvoice().then((_) {}, onError: (Object _) {});
    }
    _tabController.dispose();
    super.dispose();
  }

  /// حفظ تلقائي بعد آخر تعديل بثانية تقريبًا
  /// setState لأجزاء الواجهة المنقولة لملفات part (نفس نمط صفحة المقاسات)
  void _rebuild(VoidCallback fn) => setState(fn);

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    if (mounted && _savedRecently) setState(() => _savedRecently = false);
    _autoSaveTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _save(silent: true);
    });
  }

  Map<String, dynamic> _lineToMap(InvoiceLine l) => {
    'key': l.key,
    'label': l.label,
    'unit': l.unit,
    'qty': l.qty,
    'unit_price': l.unitPrice,
  };

  InvoiceLine? _lineFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final key = (raw['key'] ?? '').toString();
    final label = (raw['label'] ?? '').toString();
    if (key.isEmpty || label.isEmpty) return null;
    return InvoiceLine(
      key: key,
      label: label,
      unit: (raw['unit'] ?? '').toString(),
      qty: _safeNum(raw['qty']),
      unitPrice: _safeNum(raw['unit_price']),
      manual: true,
    );
  }

  // ============================ جلب البيانات ============================

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      // الأسعار العامة (ثوابت الحساب) لازم تتحمّل قبل أي حساب
      await PricesRepository.ensureLoaded();
      // المقاسات من مكانها الجديد + بيانات الفاتورة المحفوظة (الكاش الأول = سريع)
      final results = await Future.wait<Object>([
        ClientDetailsRepository.loadClientDocFast(widget.clientId),
        ClientDetailsRepository.loadFast(widget.clientId),
      ]);
      final data = results[0] as Map<String, dynamic>;
      _stage = WorkStage.fromData(data);
      final details = results[1] as ClientDetails;

      _windows = details.measurements
          .map((m) => WindowSpec.fromMap(m))
          .toList();
      _balconies = details.balconies
          .map((m) => BalconySpec.fromMap(m))
          .toList();

      // قراءة فاتورة سابقة إن وجدت
      final inv = data['invoice'];
      if (inv is Map) {
        final rawPrices = inv['prices'];
        if (rawPrices is Map) {
          rawPrices.forEach((k, v) {
            _customPrices[k.toString()] = _safeNum(v);
          });
          // فيه لقطة أسعار محفوظة = فاتورة قديمة، أسعارها متجمّدة
          if (rawPrices.isNotEmpty) {
            _pricesFrozen = true;
            final rawSavedAt = inv['saved_at'];
            if (rawSavedAt is Timestamp) {
              _pricesFrozenAt = rawSavedAt.toDate();
            }
            // بنود اتضافت للتطبيق بعد حفظ الفاتورة دي (زي الكوبشة)
            _missingFrozenDefs = kPriceDefs
                .where((d) => !rawPrices.containsKey(d.key) && d.value > 0)
                .toList();
          }
        }
        final rawAptQ = inv['apt_qty_override'];
        if (rawAptQ is Map) {
          rawAptQ.forEach((k, v) {
            _aptQtyOverride[k.toString()] = _safeNum(v);
          });
        }
        final rawAptP = inv['apt_price_override'];
        if (rawAptP is Map) {
          rawAptP.forEach((k, v) {
            _aptPriceOverride[k.toString()] = _safeNum(v);
          });
        }
        final rawBalcQ = inv['balc_qty_override'];
        if (rawBalcQ is Map) {
          rawBalcQ.forEach((k, v) {
            _balcQtyOverride[k.toString()] = _safeNum(v);
          });
        }
        final rawBalcP = inv['balc_price_override'];
        if (rawBalcP is Map) {
          rawBalcP.forEach((k, v) {
            _balcPriceOverride[k.toString()] = _safeNum(v);
          });
        }
        for (final k in (inv['apt_excluded'] as List? ?? const [])) {
          _aptExcluded.add(k.toString());
        }
        for (final k in (inv['balc_excluded'] as List? ?? const [])) {
          _balcExcluded.add(k.toString());
        }
        for (final raw in (inv['apt_custom_lines'] as List? ?? const [])) {
          final l = _lineFromMap(raw);
          if (l != null) _aptCustomLines.add(l);
        }
        for (final raw in (inv['balc_custom_lines'] as List? ?? const [])) {
          final l = _lineFromMap(raw);
          if (l != null) _balcCustomLines.add(l);
        }
        if (inv['balcony_fabric_key'] is String) {
          _balconyFabricKey = inv['balcony_fabric_key'] as String;
        }
        if (inv['deposit_paid'] != null) {
          _depositPaid = _safeNum(inv['deposit_paid']);
        }
        _discount = InvoiceDiscount.fromMap(inv['discount']);

        // هوية الفاتورة وسجل الدفعات
        final savedNumber = inv['number'];
        if (savedNumber is String && savedNumber.isNotEmpty) {
          _invoiceNumber = savedNumber;
        }
        final issued = inv['issued_at'];
        if (issued is Timestamp) _issuedAt = issued.toDate();
        for (final raw in (inv['payments'] as List? ?? const [])) {
          final p = InvoicePayment.fromMap(raw);
          if (p != null) _payments.add(p);
        }
        if (_payments.isEmpty && _depositPaid > 0) {
          // فاتورة قديمة: العربون كان رقم واحد، نحوّله لدفعة في السجل
          final savedAt = inv['saved_at'];
          _payments.add(
            InvoicePayment(
              amount: _depositPaid,
              date: savedAt is Timestamp ? savedAt.toDate() : DateTime.now(),
              note: 'عربون',
            ),
          );
        }
        if (_payments.isNotEmpty) _depositPaid = sumPayments(_payments);
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ============================ الحفظ في Firestore ============================

  Future<void> _writeInvoice() {
    final docRef = FirebaseFirestore.instance
        .collection('clients')
        .doc(widget.clientId);

    // أول حفظ = تاريخ ورقم الفاتورة (بيفضلوا ثابتين بعد كده)
    _invoiceNumber ??= newInvoiceNumber(DateTime.now(), widget.clientId);
    _issuedAt ??= DateTime.now();
    final total = _combinedTotal;

    final payload = {
      'number': _invoiceNumber,
      'issued_at': Timestamp.fromDate(_issuedAt!),
      'status': invoiceStatusFor(total: total, paid: _depositPaid).name,
      // 'total' = الصافي بعد الخصم (ده اللي الحالة والمتبقي بيتحسبوا عليه)
      'total': total,
      'subtotal': _subtotal,
      'discount': _discount.toMap(),
      'discount_amount': _discountAmount,
      'apt_total': _aptTotal,
      'balc_total': _balcTotal,
      'payments': _payments.map((p) => p.toMap()).toList(),
      // لقطة كاملة للأسعار: تغيير الأسعار الافتراضية بعدين ميغيّرش الفاتورة دي
      'prices': frozenPrices(_customPrices),
      'apt_qty_override': _aptQtyOverride,
      'apt_price_override': _aptPriceOverride,
      'balc_qty_override': _balcQtyOverride,
      'balc_price_override': _balcPriceOverride,
      'apt_custom_lines': _aptCustomLines.map(_lineToMap).toList(),
      'balc_custom_lines': _balcCustomLines.map(_lineToMap).toList(),
      'apt_excluded': _aptExcluded.toList(),
      'balc_excluded': _balcExcluded.toList(),
      'balcony_fabric_key': _balconyFabricKey,
      'deposit_paid': _depositPaid,
      'saved_at': FieldValue.serverTimestamp(),
    };

    return docRef.set({'invoice': payload}, SetOptions(merge: true));
  }

  Future<void> _save({bool silent = false}) async {
    if (_saving) {
      // فيه حفظ شغال: نعيد المحاولة بعده عشان آخر تعديل ميضيعش
      if (silent) _scheduleAutoSave();
      return;
    }
    _autoSaveTimer?.cancel();
    setState(() => _saving = true);

    try {
      // لو مفيش نت: الفاتورة بتتخزّن على الجهاز ومبنعلّقش الحفظ اللي بعده
      final outcome = await SyncStatus.instance.settle(_writeInvoice());

      if (!mounted) return;
      setState(() {
        _saving = false;
        _savedRecently = true;
        _saveFailed = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome == WriteOutcome.queued
                  ? 'اتحفظت على الجهاز، وهتترفع لما النت يرجع ✨'
                  : 'تم حفظ الفاتورة ✨',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: _kGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Invoice save failed: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
      // الحفظ التلقائي بيفشل في صمت (الأيقونة فوق بتحمّر)، واليدوي بيقولك السبب
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e), textAlign: TextAlign.center),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  String _friendlyError(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'مفيش صلاحية للحفظ — تأكد إنك داخل بحساب الأدمن';
        case 'unavailable':
        case 'network-request-failed':
          return 'مفيش اتصال بالإنترنت — هيتحفظ أول ما النت يرجع';
        default:
          return 'فشل الحفظ (${e.code})';
      }
    }
    return 'فشل الحفظ: $e';
  }

  // ============================ الحسابات المطبقة ============================

  ApartmentInvoice _getApartmentInvoice() {
    final base = calculateApartmentInvoice(
      windows: _windows,
      customPrices: _customPrices,
    );

    List<InvoiceLine> apply(List<InvoiceLine> list) {
      return list.map((l) {
        final q = _aptQtyOverride[l.key] ?? l.qty;
        final p = _aptPriceOverride[l.key] ?? l.unitPrice;
        return l.copyWith(qty: q, unitPrice: p);
      }).toList();
    }

    return ApartmentInvoice(
      fabricLines: apply(base.fabricLines),
      accessoryLines: apply([...base.accessoryLines, ..._aptCustomLines]),
    );
  }

  BalconyInvoice _getBalconyInvoice() {
    final base = calculateBalconyInvoice(
      balconies: _balconies,
      fabricKey: _balconyFabricKey,
      customPrices: _customPrices,
    );

    List<InvoiceLine> apply(List<InvoiceLine> list) {
      return list.map((l) {
        final q = _balcQtyOverride[l.key] ?? l.qty;
        final p = _balcPriceOverride[l.key] ?? l.unitPrice;
        return l.copyWith(qty: q, unitPrice: p);
      }).toList();
    }

    return BalconyInvoice(
      fabricLines: apply(base.fabricLines),
      accessoryLines: apply([...base.accessoryLines, ..._balcCustomLines]),
    );
  }

  // ============================ الواجهة الرئيسية ============================

  bool get _hasApt => _windows.any((w) => w.enabled && w.width > 0);
  bool get _hasBalc => _balconies.any((b) => b.enabled && b.width > 0);

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // يعيد البناء عند تغيير الثيم
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: _buildAppBar(),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: _kGold))
            : _loadError != null
            ? _buildErrorView()
            : Column(
                children: [
                  _buildClientBanner(),
                  _buildFrozenPricesNote(),
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [_buildApartmentTab(), _buildBalconyTab()],
                    ),
                  ),
                  _buildBottomSummaryBar(),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // عناصر القائمة الجانبية: بتفضّل الشريط العلوي فاضي عشان أهم زرار
    // (المشاركة) يبان. كل خيار ليه اسم مكتوب مش أيقونة بس.
    PopupMenuItem<String> menuItem(
      String value,
      IconData icon,
      String label, {
      Color? color,
    }) {
      final c = color ?? AppPalette.text;
      return PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? _kMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: c, fontSize: 13.5),
              ),
            ),
          ],
        ),
      );
    }

    return AppBar(
      backgroundColor: _kPanel,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'الفاتورة',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 19,
          color: AppPalette.text,
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'خيارات الفاتورة',
          icon: Icon(Icons.more_vert_rounded, color: _kMuted),
          color: _kPanel,
          onSelected: (value) {
            if (value == 'image') {
              _openInvoiceImage();
            } else if (value == 'text') {
              _shareAsText();
            } else if (value == 'excluded') {
              setState(() => _hideExcluded = !_hideExcluded);
            } else if (value == 'global_prices') {
              _openGlobalPrices();
            } else if (value == 'invoice_prices') {
              _openPriceSettings();
            }
          },
          itemBuilder: (_) => [
            menuItem(
              'image',
              Icons.image_rounded,
              'صورة الفاتورة (باللوجو) للمشاركة',
            ),
            menuItem('text', Icons.share_rounded, 'نسخ الفاتورة كنص'),
            menuItem(
              'excluded',
              _hideExcluded
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              _hideExcluded
                  ? 'إظهار البنود المستبعدة'
                  : 'إخفاء البنود المستبعدة (للتصوير)',
            ),
            const PopupMenuDivider(),
            menuItem(
              'global_prices',
              Icons.price_change_rounded,
              'ثوابت الحساب (الأسعار العامة)',
              color: _kGold,
            ),
            menuItem(
              'invoice_prices',
              Icons.tune_rounded,
              'أسعار الفاتورة دي',
            ),
          ],
        ),
        // مؤشر الحفظ (الحفظ تلقائي، والضغط عليه بيحفظ فورًا)
        IconButton(
          tooltip: _saveFailed
              ? 'فشل الحفظ — اضغط لإعادة المحاولة'
              : 'حفظ الفاتورة',
          icon: _saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kGold,
                  ),
                )
              : Icon(
                  _saveFailed
                      ? Icons.cloud_off_rounded
                      : _savedRecently
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_upload_outlined,
                  color: _saveFailed
                      ? const Color(0xFFEF4444)
                      : _savedRecently
                      ? _kGreen
                      : _kGold,
                ),
          onPressed: () => _save(),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: IconButton.filled(
            tooltip: 'مشاركة الفاتورة',
            style: IconButton.styleFrom(
              backgroundColor: _kGold,
              foregroundColor: _kBg,
              minimumSize: const Size(38, 38),
            ),
            icon: const Icon(Icons.ios_share_rounded, size: 19),
            onPressed: _shareAsText,
          ),
        ),
      ],
    );
  }

  Widget _buildClientBanner() {
    final shown = _issuedAt ?? DateTime.now();
    final today = _arNum('${shown.day}/${shown.month}/${shown.year}');
    final status = invoiceStatusFor(total: _combinedTotal, paid: _depositPaid);
    final hasPhone = widget.phone != null && widget.phone!.isNotEmpty;
    final hasAddress = widget.address != null && widget.address!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: BoxDecoration(
        color: _kPanel,
        border: Border(bottom: BorderSide(color: _kLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildStageBadge(),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.clientName.isEmpty
                      ? 'عميل بدون اسم'
                      : widget.clientName,
                  style: TextStyle(
                    color: AppPalette.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasPhone || hasAddress) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (hasPhone) _arNum(widget.phone!),
                      if (hasAddress) widget.address!,
                    ].join('  •  '),
                    style: TextStyle(color: _kMuted, fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_invoiceNumber != null)
                Text(
                  _invoiceNumber!,
                  style: TextStyle(
                    color: _kGold,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                today,
                style: TextStyle(color: _kMuted, fontSize: 12.5),
              ),
              Text(
                invoiceStatusLabel(status),
                style: TextStyle(
                  color: status == InvoiceStatus.paid ? _kGreen : _kMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// تنبيه صغير: أسعار الفاتورة دي متجمّدة من يوم حفظها، فمش بتتأثر
  /// بتغيير «ثوابت الحساب». بيظهر مرة واحدة وبيتقفل بضغطة.
  Widget _buildFrozenPricesNote() {
    if (!_pricesFrozen || _frozenNoteHidden) return const SizedBox.shrink();
    final at = _pricesFrozenAt;
    final date = at == null
        ? null
        : '${at.day}/${at.month}/${at.year}';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 2, 4, 2),
      decoration: BoxDecoration(
        color: _kGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_rounded, size: 15, color: _kGold),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              date == null
                  ? 'أسعار الفاتورة دي متجمّدة عند حفظها'
                  : 'أسعار الفاتورة دي متجمّدة من $date',
              style: TextStyle(
                color: _kGold,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _kGold,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 26),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _showFrozenPricesInfo,
            child: const Text('إيه معناها؟', style: TextStyle(fontSize: 11.5)),
          ),
          IconButton(
            tooltip: 'إخفاء التنبيه',
            iconSize: 15,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _frozenNoteHidden = true),
            icon: Icon(Icons.close_rounded, color: _kMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _showFrozenPricesInfo() async {
    final at = _pricesFrozenAt;
    final date = at == null
        ? 'وقت الحفظ'
        : '${at.day}/${at.month}/${at.year}';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('يعني إيه «أسعار متجمّدة»؟'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الفاتورة دي اتحفظت بأسعار يوم $date. أي تغيير في '
                '«ثوابت الحساب» بعد كده مش بيغيّر الأرقام دي، عشان '
                'حساب قديم ميتغيّرش لوحده.',
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 12),
              if (_missingFrozenDefs.isEmpty)
                const Text(
                  'كل بنود الفاتورة محفوظة بسعرها القديم ✅',
                  style: TextStyle(fontSize: 13, height: 1.6),
                )
              else ...[
                const Text(
                  'بس فيه بنود اتضافت للتطبيق بعد حفظها — دي لو اتضافت '
                  'للفاتورة هتتحسب بسعر النهارده:',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 8),
                for (final d in _missingFrozenDefs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '• ${d.label}: ${_fmtQty(d.value)} ج / ${d.unit}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _kGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }

  /// دايرة مرحلة الشغل: اضغط وغيّر المرحلة (١ أحمر • ٢ أصفر • ٣ أزرق • ٤ أخضر)
  Widget _buildStageBadge() {
    final color = _kStageColors[_stage]!;
    return PopupMenuButton<int>(
      tooltip: 'مرحلة الشغل',
      initialValue: _stage,
      color: _kPanel,
      onSelected: _setStage,
      itemBuilder: (_) => [
        for (final s in WorkStage.all)
          PopupMenuItem<int>(
            value: s,
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _kStageColors[s],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _kStageColors[s]!.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  stageMenuLabel(s),
                  style: TextStyle(
                    color: s == _stage ? _kStageColors[s] : AppPalette.text,
                    fontWeight: s == _stage ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color, width: 1.6),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 9),
          ],
        ),
        child: stageMark(_stage, color, size: 17),
      ),
    );
  }

  Future<void> _setStage(int stage) async {
    if (WorkStage.isCancelled(stage) && stage != _stage) {
      final ok = await confirmCancelWork(context);
      if (!ok || !mounted) return;
    }
    setState(() => _stage = stage);
    try {
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .update(WorkStage.updateFields(stage));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e), textAlign: TextAlign.center),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Widget _buildTabBar() {
    Tab tab(IconData icon, String text) => Tab(
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _kGold,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: _kBg,
        unselectedLabelColor: _kMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        splashBorderRadius: BorderRadius.circular(10),
        tabs: [
          tab(Icons.home_rounded, 'الشقة'),
          tab(Icons.balcony_rounded, 'البلكونة'),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, color: _kMuted, size: 46),
            const SizedBox(height: 12),
            Text(
              'تعذر تحميل بيانات الفاتورة',
              style: TextStyle(
                color: AppPalette.text,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _loadError ?? '',
              style: TextStyle(color: _kMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loadError = null;
                  _loading = true;
                });
                _load();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: _kBg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================ تبويب الشقة ============================

  double get _aptTotal {
    if (!_hasApt) return 0.0;
    final inv = _getApartmentInvoice();
    return roundMoney(
      _sumIncluded(inv.accessoryLines, _aptExcluded) +
          _sumIncluded(inv.fabricLines, _aptExcluded),
    );
  }

  double get _balcTotal {
    if (!_hasBalc) return 0.0;
    final inv = _getBalconyInvoice();
    return roundMoney(
      _sumIncluded(inv.accessoryLines, _balcExcluded) +
          _sumIncluded(inv.fabricLines, _balcExcluded),
    );
  }

  /// إجمالي الفاتورة قبل الخصم (شقة + بلكونة)
  double get _subtotal => roundMoney(_aptTotal + _balcTotal);

  /// قيمة الخصم بالجنيه
  double get _discountAmount => _discount.amountFor(_subtotal);

  /// الصافي بعد الخصم: ده اللي بيتحسب عليه المدفوع والمتبقي والحالة
  double get _combinedTotal => roundMoney(_subtotal - _discountAmount);

}
