import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/client_details_repository.dart';
import 'invoice_calculator.dart';

// ألوان الفاتورة (لون مميز واحد = الذهبي، عشان الشكل يبقى هادي وواضح)
const Color _kBg = Color(0xFF0F172A);
const Color _kPanel = Color(0xFF1E293B);
const Color _kLine = Color(0xFF334155);
const Color _kGold = Color(0xFFC5A059);
const Color _kMuted = Color(0xFF94A3B8);
const Color _kGreen = Color(0xFF10B981);

// مراحل الشغل (نفس ألوان صفحة العملاء)
const Map<int, Color> _kStageColors = {
  1: Color(0xFFFF4D5E),
  2: Color(0xFFFFD43B),
  3: Color(0xFF38BDF8),
  4: Color(0xFF22E58B),
};
const Map<int, String> _kStageLabels = {
  1: 'بدأنا الشغل',
  2: 'جاري التحضير',
  3: 'تم التخريم وجاهز للتركيب',
  4: 'تمت وتم التركيب',
};

/// دالة مساعدة لتحويل أي نص أو رقم إلى أرقام عربية مشرقية (٠١٢٣٤٥٦٧٨٩)
String _arNum(dynamic value) {
  if (value == null) return '٠';
  final s = value.toString();
  const en = '0123456789';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final char in s.split('')) {
    final idx = en.indexOf(char);
    if (idx != -1) {
      buffer.write(ar[idx]);
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

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

String _money(dynamic v) {
  final d = _safeNum(v);
  final r = roundMoney(d);
  if (r == r.roundToDouble()) {
    return _arNum(r.toInt().toString());
  }
  return _arNum(r.toStringAsFixed(2));
}

String _fmtQty(dynamic q) {
  final d = _safeNum(q);
  if (d == d.roundToDouble()) {
    return _arNum(d.toInt().toString());
  }
  return _arNum(d.toStringAsFixed(2));
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

  // نوع قماش البلكونة
  String _balconyFabricKey = 'fabric_dak';

  // العربون المدفوع
  double _depositPaid = 0;

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
      // المقاسات من مكانها الجديد + بيانات الفاتورة المحفوظة (الكاش الأول = سريع)
      final results = await Future.wait<Object>([
        ClientDetailsRepository.loadClientDocFast(widget.clientId),
        ClientDetailsRepository.loadFast(widget.clientId),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final rawStage = data['work_stage'];
      _stage = rawStage is num
          ? rawStage.toInt().clamp(1, 4)
          : (data['installation_done'] == true ? 4 : 1);
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

    final payload = {
      'prices': _customPrices,
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
      await _writeInvoice();

      if (!mounted) return;
      setState(() {
        _saving = false;
        _savedRecently = true;
        _saveFailed = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ الفاتورة ✨',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: _kGreen,
            duration: Duration(seconds: 2),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: _buildAppBar(),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _kGold))
            : _loadError != null
            ? _buildErrorView()
            : Column(
                children: [
                  _buildClientBanner(),
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
    return AppBar(
      backgroundColor: _kPanel,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'الفاتورة',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 19,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'إعدادات الأسعار',
          icon: const Icon(Icons.tune_rounded, color: _kMuted),
          onPressed: _openPriceSettings,
        ),
        IconButton(
          tooltip: _hideExcluded
              ? 'إظهار البنود المستبعدة'
              : 'إخفاء البنود المستبعدة (للتصوير)',
          icon: Icon(
            _hideExcluded
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: _hideExcluded ? _kGold : _kMuted,
          ),
          onPressed: () => setState(() => _hideExcluded = !_hideExcluded),
        ),
        IconButton(
          tooltip: 'نسخ الفاتورة كنص',
          icon: const Icon(Icons.share_rounded, color: _kGold),
          onPressed: _shareAsText,
        ),
        // مؤشر الحفظ (الحفظ تلقائي، والضغط عليه بيحفظ فورًا)
        IconButton(
          tooltip: _saveFailed
              ? 'فشل الحفظ — اضغط لإعادة المحاولة'
              : 'حفظ الفاتورة',
          icon: _saving
              ? const SizedBox(
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
      ],
    );
  }

  Widget _buildClientBanner() {
    final now = DateTime.now();
    final today = _arNum('${now.day}/${now.month}/${now.year}');
    final hasPhone = widget.phone != null && widget.phone!.isNotEmpty;
    final hasAddress = widget.address != null && widget.address!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: const BoxDecoration(
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
                  style: const TextStyle(
                    color: Colors.white,
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
                    style: const TextStyle(color: _kMuted, fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(today, style: const TextStyle(color: _kMuted, fontSize: 12.5)),
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
        for (final s in const [1, 2, 3, 4])
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
                  '${_arNum(s)} • ${_kStageLabels[s]}',
                  style: TextStyle(
                    color: s == _stage ? _kStageColors[s] : Colors.white,
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
        child: Text(
          _arNum(_stage),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ),
    );
  }

  Future<void> _setStage(int stage) async {
    setState(() => _stage = stage);
    try {
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .update({
            'work_stage': stage,
            'installation_done': stage == 4,
            'installation_done_at': stage == 4
                ? FieldValue.serverTimestamp()
                : null,
          });
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
        children: [Icon(icon, size: 17), const SizedBox(width: 6), Text(text)],
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
            const Icon(Icons.cloud_off_rounded, color: _kMuted, size: 46),
            const SizedBox(height: 12),
            const Text(
              'تعذر تحميل بيانات الفاتورة',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _loadError ?? '',
              style: const TextStyle(color: _kMuted, fontSize: 12),
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

  Widget _buildApartmentTab() {
    if (!_hasApt) {
      return _buildEmptyState(
        icon: Icons.curtains_rounded,
        title: 'مفيش مقاسات للشقة',
        sub: 'ضيف مقاسات الشبابيك من صفحة المقاسات الأول',
      );
    }
    final invoice = _getApartmentInvoice();
    final ex = _aptExcluded;
    final acc = _sumIncluded(invoice.accessoryLines, ex);
    final fab = _sumIncluded(invoice.fabricLines, ex);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        // الإكسسوارات الأول
        _buildSectionCard(
          title: 'الإكسسوارات والمصنعية',
          icon: Icons.hardware_rounded,
          lines: invoice.accessoryLines,
          totalLabel: 'إجمالي الإكسسوارات',
          totalVal: acc,
          isBalcony: false,
          isFabric: false,
          showAdd: true,
        ),
        const SizedBox(height: 14),
        // وبعدها القماش
        _buildSectionCard(
          title: 'القماش',
          icon: Icons.texture_rounded,
          lines: invoice.fabricLines,
          totalLabel: 'إجمالي القماش',
          totalVal: fab,
          isBalcony: false,
          isFabric: true,
        ),
        const SizedBox(height: 14),
        _buildTabTotalCard(
          label: 'إجمالي الشقة',
          accessories: acc,
          fabric: fab,
          hasAccessories: _anyIncluded(invoice.accessoryLines, ex),
          hasFabric: _anyIncluded(invoice.fabricLines, ex),
        ),
      ],
    );
  }

  // ============================ تبويب البلكونة ============================

  Widget _buildBalconyTab() {
    if (!_hasBalc) {
      return _buildEmptyState(
        icon: Icons.balcony_rounded,
        title: 'مفيش مقاسات للبلكونة',
        sub: 'ضيف أضلاع البلكونة من صفحة المقاسات الأول',
      );
    }
    final invoice = _getBalconyInvoice();
    final ex = _balcExcluded;
    final acc = _sumIncluded(invoice.accessoryLines, ex);
    final fab = _sumIncluded(invoice.fabricLines, ex);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        // الإكسسوارات الأول
        _buildSectionCard(
          title: 'الإكسسوارات والمصنعية',
          icon: Icons.hardware_rounded,
          lines: invoice.accessoryLines,
          totalLabel: 'إجمالي الإكسسوارات',
          totalVal: acc,
          isBalcony: true,
          isFabric: false,
          showAdd: true,
        ),
        const SizedBox(height: 14),
        // وبعدها القماش — اضغط على اسم القماش عشان تغيّر النوع
        _buildSectionCard(
          title: 'القماش',
          icon: Icons.texture_rounded,
          lines: invoice.fabricLines,
          totalLabel: 'إجمالي القماش',
          totalVal: fab,
          isBalcony: true,
          isFabric: true,
        ),
        const SizedBox(height: 14),
        _buildTabTotalCard(
          label: 'إجمالي البلكونة',
          accessories: acc,
          fabric: fab,
          hasAccessories: _anyIncluded(invoice.accessoryLines, ex),
          hasFabric: _anyIncluded(invoice.fabricLines, ex),
        ),
      ],
    );
  }

  /// اسم القماش في البلكونة: اضغط عليه تختار النوع من قايمة صغيرة
  Widget _buildFabricPicker(InvoiceLine line) {
    return PopupMenuButton<String>(
      tooltip: 'غيّر نوع القماش',
      color: _kPanel,
      onSelected: (key) {
        setState(() => _balconyFabricKey = key);
        _scheduleAutoSave();
      },
      itemBuilder: (_) => [
        for (final e in kBalconyFabrics.entries)
          PopupMenuItem<String>(
            value: e.key,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  e.key == _balconyFabricKey
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: e.key == _balconyFabricKey ? _kGold : _kMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  e.value,
                  style: TextStyle(
                    color: e.key == _balconyFabricKey ? _kGold : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${_money(_customPrices[e.key] ?? defaultPrices()[e.key] ?? 0)} ج/م',
                  style: const TextStyle(color: _kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              line.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded, color: _kGold, size: 22),
        ],
      ),
    );
  }

  // ============================ تعديل البنود ============================

  double _sumIncluded(List<InvoiceLine> lines, Set<String> excluded) {
    return roundMoney(
      lines
          .where((l) => !excluded.contains(l.key))
          .fold(0.0, (sum, l) => sum + l.total),
    );
  }

  bool _anyIncluded(List<InvoiceLine> lines, Set<String> excluded) =>
      lines.any((l) => !excluded.contains(l.key));

  void _toggleLine(String key, {required bool isBalcony}) {
    final set = isBalcony ? _balcExcluded : _aptExcluded;
    setState(() {
      if (!set.remove(key)) set.add(key);
    });
    _scheduleAutoSave();
  }

  /// لو في أي بند داخل → استبعد الكل، ولو مفيش → ضمّن الكل
  void _toggleSection(List<InvoiceLine> lines, {required bool isBalcony}) {
    final set = isBalcony ? _balcExcluded : _aptExcluded;
    final anyIn = lines.any((l) => !set.contains(l.key));
    setState(() {
      for (final l in lines) {
        if (anyIn) {
          set.add(l.key);
        } else {
          set.remove(l.key);
        }
      }
    });
    _scheduleAutoSave();
  }

  void _editQty(
    String key,
    double current, {
    required bool isBalcony,
    required bool isFabric,
  }) {
    _openQuickEdit(
      title: isFabric ? 'تعديل أمتار القماش' : 'تعديل الكمية',
      current: current,
      unit: isFabric ? 'متر' : '',
      onSave: (v) {
        setState(() {
          (isBalcony ? _balcQtyOverride : _aptQtyOverride)[key] = v;
        });
        _scheduleAutoSave();
      },
    );
  }

  void _editPrice(
    String key,
    double current, {
    required bool isBalcony,
    required bool isFabric,
  }) {
    _openQuickEdit(
      title: isFabric ? 'تعديل سعر المتر' : 'تعديل سعر الوحدة',
      current: current,
      unit: 'ج.م',
      onSave: (v) {
        setState(() {
          (isBalcony ? _balcPriceOverride : _aptPriceOverride)[key] = v;
        });
        _scheduleAutoSave();
      },
    );
  }

  void _removeCustomLine(String key, {required bool isBalcony}) {
    setState(() {
      if (isBalcony) {
        _balcCustomLines.removeWhere((l) => l.key == key);
        _balcExcluded.remove(key);
        _balcQtyOverride.remove(key);
        _balcPriceOverride.remove(key);
      } else {
        _aptCustomLines.removeWhere((l) => l.key == key);
        _aptExcluded.remove(key);
        _aptQtyOverride.remove(key);
        _aptPriceOverride.remove(key);
      }
    });
    _scheduleAutoSave();
  }

  // ============================ كارت القسم والجدول ============================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<InvoiceLine> lines,
    required String totalLabel,
    required double totalVal,
    required bool isBalcony,
    required bool isFabric,
    bool showAdd = false,
  }) {
    final excluded = isBalcony ? _balcExcluded : _aptExcluded;
    final includedCount = lines.where((l) => !excluded.contains(l.key)).length;
    final visible = _hideExcluded
        ? lines.where((l) => !excluded.contains(l.key)).toList()
        : lines;

    if (visible.isEmpty && !showAdd) return const SizedBox.shrink();

    // أيقونة "تحديد الكل": كله داخل / بعضه / ولا حاجة
    final allIn = lines.isNotEmpty && includedCount == lines.length;
    final noneIn = includedCount == 0;

    return Container(
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // عنوان القسم
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
            child: Row(
              children: [
                Icon(icon, color: _kGold, size: 19),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: _kGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const Spacer(),
                if (lines.isNotEmpty)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _toggleSection(lines, isBalcony: isBalcony),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Text(
                            allIn ? 'الكل' : (noneIn ? 'بدون' : 'جزء'),
                            style: const TextStyle(
                              color: _kMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            allIn
                                ? Icons.check_circle_rounded
                                : noneIn
                                ? Icons.radio_button_unchecked
                                : Icons.remove_circle_outline_rounded,
                            size: 21,
                            color: noneIn ? _kMuted : _kGold,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: _kLine, height: 1),

          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              const Divider(
                color: _kLine,
                height: 1,
                indent: 14,
                endIndent: 14,
              ),
            _buildLineRow(
              visible[i],
              included: !excluded.contains(visible[i].key),
              onToggle: () => _toggleLine(visible[i].key, isBalcony: isBalcony),
              onQty: () => _editQty(
                visible[i].key,
                visible[i].qty,
                isBalcony: isBalcony,
                isFabric: isFabric,
              ),
              onPrice: () => _editPrice(
                visible[i].key,
                visible[i].unitPrice,
                isBalcony: isBalcony,
                isFabric: isFabric,
              ),
              onDelete: visible[i].manual
                  ? () =>
                        _removeCustomLine(visible[i].key, isBalcony: isBalcony)
                  : null,
              nameWidget: (isBalcony && isFabric)
                  ? _buildFabricPicker(visible[i])
                  : null,
            ),
          ],

          if (showAdd) ...[
            if (visible.isNotEmpty) const Divider(color: _kLine, height: 1),
            InkWell(
              onTap: () => _openAddCustomLineDialog(isBalcony: isBalcony),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                      color: _kGold,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'إضافة بند',
                      style: TextStyle(
                        color: _kGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // إجمالي القسم (المحدد فقط)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Text(
                  totalLabel,
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_money(totalVal)} ج.م',
                  style: TextStyle(
                    color: noneIn ? _kMuted : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortUnit(String unit) => unit == 'متر' ? 'م' : unit;

  /// سطر واحد للبند:  ✓ الاسم  |  الكمية × السعر  |  الإجمالي
  /// الدايرة على اليمين = داخل في الحساب ولا لأ. اضغط الكمية أو السعر للتعديل.
  Widget _buildLineRow(
    InvoiceLine line, {
    required bool included,
    required VoidCallback onToggle,
    required VoidCallback onQty,
    required VoidCallback onPrice,
    VoidCallback? onDelete,
    Widget? nameWidget,
  }) {
    Widget chip(String text, VoidCallback onTap) => InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );

    final unit = _shortUnit(line.unit);
    final qtyText = unit.isEmpty
        ? _fmtQty(line.qty)
        : '${_fmtQty(line.qty)} $unit';

    return Row(
      children: [
        // دايرة التحديد (داخل في الإجمالي ولا لأ)
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Icon(
              included
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 23,
              color: included ? _kGold : _kMuted,
            ),
          ),
        ),
        Expanded(
          child: Opacity(
            opacity: included ? 1 : 0.4,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Row(
                children: [
                  Expanded(
                    child:
                        nameWidget ??
                        Text(
                          line.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                  ),
                  const SizedBox(width: 6),
                  chip(qtyText, onQty),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '×',
                      style: TextStyle(color: _kMuted, fontSize: 13),
                    ),
                  ),
                  chip(_money(line.unitPrice), onPrice),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 58),
                    child: Text(
                      '${_money(line.total)} ج',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: _kGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        decoration: included
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onDelete != null)
          IconButton(
            tooltip: 'حذف البند',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFEF4444),
              size: 19,
            ),
          ),
      ],
    );
  }

  /// ملخص التبويب (آخر القائمة): بيعرض الأقسام اللي فيها بنود محددة بس
  Widget _buildTabTotalCard({
    required String label,
    required double accessories,
    required double fabric,
    required bool hasAccessories,
    required bool hasFabric,
  }) {
    Widget row(String l, double v, {bool big = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            l,
            style: TextStyle(
              color: big ? Colors.white : _kMuted,
              fontSize: big ? 15.5 : 13.5,
              fontWeight: big ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_money(v)} ج.م',
            style: TextStyle(
              color: big ? _kGold : Colors.white,
              fontSize: big ? 18 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(
        children: [
          if (hasAccessories) row('إجمالي الإكسسوارات', accessories),
          if (hasFabric) row('إجمالي القماش', fabric),
          if (hasAccessories || hasFabric)
            const Divider(color: _kLine, height: 14),
          row(label, roundMoney(accessories + fabric), big: true),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String sub,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: _kLine),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              style: const TextStyle(color: _kMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================ الشريط المالي السفلي ============================
  // الإجمالي (شقة + بلكونة) | العربون (اضغط للتعديل) | المتبقي

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

  double get _combinedTotal => roundMoney(_aptTotal + _balcTotal);

  Widget _buildBottomSummaryBar() {
    final apt = _aptTotal;
    final balc = _balcTotal;
    final combined = roundMoney(apt + balc);
    final remaining = roundMoney(combined - _depositPaid);
    final owes = remaining > 0;
    final remainColor = owes ? const Color(0xFFEF4444) : _kGreen;

    Widget block({
      required String label,
      required String value,
      required Color color,
      VoidCallback? onTap,
      Color? border,
      IconData? trailing,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border ?? _kLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: _kMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 4),
                      Icon(trailing, size: 12, color: _kMuted),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '$value ج',
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: _kPanel,
        border: Border(top: BorderSide(color: _kLine, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            offset: Offset(0, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  block(
                    label: 'الإجمالي',
                    value: _money(combined),
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  block(
                    label: 'العربون',
                    value: _money(_depositPaid),
                    color: _kGreen,
                    onTap: _openDepositDialog,
                    trailing: Icons.edit_rounded,
                  ),
                  const SizedBox(width: 8),
                  block(
                    label: owes ? 'المتبقي' : 'خالص',
                    value: _money(remaining.abs()),
                    color: remainColor,
                    border: remainColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
              if (_hasApt && _hasBalc)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'الشقة ${_money(apt)} ج  +  البلكونة ${_money(balc)} ج',
                    style: const TextStyle(color: _kMuted, fontSize: 11.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================ ديالوج التعديل السريع الذكي ============================

  void _openQuickEdit({
    required String title,
    required double current,
    required String unit,
    required void Function(double val) onSave,
  }) {
    final controller = TextEditingController(text: current.toString());
    double tempVal = current;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void update(double delta) {
              final next = (tempVal + delta).clamp(0.0, 9999.0);
              tempVal = roundMoney(next);
              controller.text = tempVal == tempVal.roundToDouble()
                  ? tempVal.toInt().toString()
                  : tempVal.toString();
              setModalState(() {});
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF475569),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // عرض الرقم بوضوح فائق
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFC5A059)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _arNum(controller.text),
                            style: const TextStyle(
                              color: Color(0xFFC5A059),
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (unit.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              unit,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // أزرار الزيادة والنقصان السريعة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStepButton(label: '٥-', onTap: () => update(-5)),
                        const SizedBox(width: 8),
                        _buildStepButton(label: '١-', onTap: () => update(-1)),
                        const SizedBox(width: 8),
                        _buildStepButton(
                          label: '٠٫٥-',
                          onTap: () => update(-0.5),
                        ),
                        const SizedBox(width: 14),
                        _buildStepButton(
                          label: '+٠٫٥',
                          onTap: () => update(0.5),
                          isPositive: true,
                        ),
                        const SizedBox(width: 8),
                        _buildStepButton(
                          label: '+١',
                          onTap: () => update(1),
                          isPositive: true,
                        ),
                        const SizedBox(width: 8),
                        _buildStepButton(
                          label: '+٥',
                          onTap: () => update(5),
                          isPositive: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // حقل إدخال يدوي مباشر
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        hintText: 'أو اكتب القيمة مباشرة',
                        hintStyle: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF334155),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (val) {
                        tempVal = _safeNum(val);
                        setModalState(() {});
                      },
                    ),

                    const SizedBox(height: 16),

                    // أزرار الحفظ والإلغاء
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final v = _safeNum(controller.text);
                              onSave(v);
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC5A059),
                              foregroundColor: const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'تطبيق التعديل',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStepButton({
    required String label,
    required VoidCallback onTap,
    bool isPositive = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isPositive
              ? const Color(0xFFC5A059).withValues(alpha: 0.18)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPositive
                ? const Color(0xFFC5A059)
                : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isPositive ? const Color(0xFFC5A059) : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ============================ ديالوج العربون ============================

  void _openDepositDialog() {
    final controller = TextEditingController(
      text: _depositPaid == 0
          ? ''
          : (_depositPaid == _depositPaid.roundToDouble()
                ? _depositPaid.toInt().toString()
                : _depositPaid.toString()),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.payments_rounded, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text(
                  'تسجيل العربون المدفوع',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: 'مثال: ٥٠٠٠',
                hintStyle: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
                suffixText: 'ج.م',
                suffixStyle: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final v = _safeNum(controller.text);
                  setState(() => _depositPaid = v);
                  _scheduleAutoSave();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'حفظ العربون',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================ ديالوج إضافة بند مخصص ============================

  void _openAddCustomLineDialog({required bool isBalcony}) {
    final labelCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'قطعة');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isBalcony
                  ? 'إضافة بند لفاتورة البلكونة'
                  : 'إضافة بند لفاتورة الشقة',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'اسم البند',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'الكمية',
                            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: unitCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'الوحدة (متر/قطعة..)',
                            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'سعر الوحدة (ج.م)',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final label = labelCtrl.text.trim();
                  if (label.isEmpty) return;
                  final q = _safeNum(qtyCtrl.text);
                  final p = _safeNum(priceCtrl.text);
                  final key = 'custom_${DateTime.now().millisecondsSinceEpoch}';

                  final line = InvoiceLine(
                    key: key,
                    label: label,
                    unit: unitCtrl.text.trim(),
                    qty: q <= 0 ? 1 : q,
                    unitPrice: p,
                    manual: true,
                  );

                  setState(() {
                    if (isBalcony) {
                      _balcCustomLines.add(line);
                    } else {
                      _aptCustomLines.add(line);
                    }
                  });
                  _scheduleAutoSave();

                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A059),
                  foregroundColor: const Color(0xFF0F172A),
                ),
                child: const Text(
                  'إضافة البند',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================ ديالوج الأسعار الافتراضية ============================

  void _openPriceSettings() {
    final localCopy = Map<String, double>.from(defaultPrices())
      ..addAll(_customPrices);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.75,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF475569),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Icons.tune_rounded, color: Color(0xFFC5A059)),
                        SizedBox(width: 8),
                        Text(
                          'تعديل قائمة الأسعار الافتراضية',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: kPriceDefs.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: Color(0xFF334155), height: 1),
                        itemBuilder: (_, i) {
                          final def = kPriceDefs[i];
                          final current = localCopy[def.key] ?? def.value;
                          return ListTile(
                            dense: true,
                            title: Text(
                              def.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'الوحدة: ${def.unit}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              child: Text(
                                '${_money(current)} ج',
                                style: const TextStyle(
                                  color: Color(0xFFC5A059),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onTap: () {
                              _openQuickEdit(
                                title: 'تعديل سعر: ${def.label}',
                                current: current,
                                unit: 'ج/${def.unit}',
                                onSave: (v) {
                                  localCopy[def.key] = v;
                                  setModalState(() {});
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _customPrices.clear();
                                _customPrices.addAll(localCopy);
                              });
                              _scheduleAutoSave();
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC5A059),
                              foregroundColor: const Color(0xFF0F172A),
                            ),
                            child: const Text(
                              'تطبيق الأسعار الجديدة',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================ مشاركة نص الفاتورة (واتساب) ============================

  void _shareAsText() {
    final aptInv = _getApartmentInvoice();
    final balcInv = _getBalconyInvoice();
    final combined = _combinedTotal;
    final remaining = roundMoney(combined - _depositPaid);

    String fmt(InvoiceLine l) =>
        '• ${l.label}: ${_fmtQty(l.qty)} ${l.unit} × ${_money(l.unitPrice)} = ${_money(l.total)} ج';

    // الإكسسوارات الأول وبعدها القماش — والبنود المستبعدة مش بتظهر
    List<InvoiceLine> picked(
      List<InvoiceLine> acc,
      List<InvoiceLine> fab,
      Set<String> ex,
    ) => [...acc, ...fab].where((l) => !ex.contains(l.key)).toList();

    final b = StringBuffer();
    b.writeln('━━━━━━━━━━━━━━━━━━━━');
    b.writeln('✨ ستائر باريس — PARIS CURTAINS ✨');
    b.writeln('━━━━━━━━━━━━━━━━━━━━');
    b.writeln('👤 العميل: ${widget.clientName}');
    if (widget.phone != null && widget.phone!.isNotEmpty) {
      b.writeln('📱 الهاتف: ${_arNum(widget.phone!)}');
    }
    b.writeln('━━━━━━━━━━━━━━━━━━━━');

    final aptLines = _hasApt
        ? picked(aptInv.accessoryLines, aptInv.fabricLines, _aptExcluded)
        : <InvoiceLine>[];
    if (aptLines.isNotEmpty) {
      b.writeln('🏠 [ستائر الشقة]');
      for (final l in aptLines) {
        b.writeln(fmt(l));
      }
      b.writeln('🔹 إجمالي الشقة: ${_money(_aptTotal)} ج.م');
      b.writeln('');
    }

    final balcLines = _hasBalc
        ? picked(balcInv.accessoryLines, balcInv.fabricLines, _balcExcluded)
        : <InvoiceLine>[];
    if (balcLines.isNotEmpty) {
      b.writeln('🌿 [ستائر البلكونة]');
      for (final l in balcLines) {
        b.writeln(fmt(l));
      }
      b.writeln('🔹 إجمالي البلكونة: ${_money(_balcTotal)} ج.م');
      b.writeln('');
    }

    b.writeln('━━━━━━━━━━━━━━━━━━━━');
    b.writeln('💰 الحساب الإجمالي: ${_money(combined)} ج.م');
    b.writeln('💵 العربون المدفوع: ${_money(_depositPaid)} ج.م');
    b.writeln('⚖️ المتبقي الصافي: ${_money(remaining)} ج.م');
    b.writeln('━━━━━━━━━━━━━━━━━━━━');
    b.writeln('شكراً لثقتكم بنا ✨ ستائر باريس ترحب بكم دائماً');

    Clipboard.setData(ClipboardData(text: b.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ نص الفاتورة! جاهز للإرسال على واتساب 📲',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _kGold,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
