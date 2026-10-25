import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_calculator.dart';

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

  // نوع قماش البلكونة
  String _balconyFabricKey = 'fabric_dak';

  // العربون المدفوع
  double _depositPaid = 0;

  // حالة الحفظ
  bool _saving = false;
  bool _savedRecently = false;

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
    _tabController.dispose();
    super.dispose();
  }

  // ============================ جلب البيانات ============================

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId);
      final doc = await docRef.get();
      final data = doc.data() ?? {};

      // قراءة الشبابيك
      final rawWindows = data['measurements'];
      if (rawWindows is List) {
        _windows = rawWindows
            .whereType<Map>()
            .map((m) => WindowSpec.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      }

      // قراءة البلكونات
      final rawBalc = data['balconies'];
      if (rawBalc is List) {
        _balconies = rawBalc
            .whereType<Map>()
            .map((m) => BalconySpec.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      }

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
        if (inv['balcony_fabric_key'] is String) {
          _balconyFabricKey = inv['balcony_fabric_key'] as String;
        }
        if (inv['deposit_paid'] != null) {
          _depositPaid = _safeNum(inv['deposit_paid']);
        }
        List<InvoiceLine> readCustom(dynamic raw) {
          if (raw is! List) return <InvoiceLine>[];
          return raw
              .whereType<Map>()
              .map((item) {
                final m = Map<String, dynamic>.from(item);
                return InvoiceLine(
                  key:
                      (m['key'] ??
                              'custom_${DateTime.now().microsecondsSinceEpoch}')
                          .toString(),
                  label: (m['label'] ?? '').toString(),
                  unit: (m['unit'] ?? 'قطعة').toString(),
                  qty: _safeNum(m['qty']),
                  unitPrice: _safeNum(m['unitPrice']),
                  isFabric: m['isFabric'] == true,
                );
              })
              .where((line) => line.label.trim().isNotEmpty)
              .toList();
        }

        _aptCustomLines.addAll(readCustom(inv['apt_custom_lines']));
        _balcCustomLines.addAll(readCustom(inv['balc_custom_lines']));
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId);

      final apt = _getApartmentInvoice();
      final balc = _getBalconyInvoice();
      final grandTotal = roundMoney(apt.grandTotal + balc.grandTotal);
      final remaining = (grandTotal - _depositPaid) < 0
          ? 0.0
          : roundMoney(grandTotal - _depositPaid);
      List<Map<String, dynamic>> serializeCustom(List<InvoiceLine> lines) =>
          lines
              .map(
                (line) => {
                  'key': line.key,
                  'label': line.label,
                  'unit': line.unit,
                  'qty': line.qty,
                  'unitPrice': line.unitPrice,
                  'isFabric': line.isFabric,
                },
              )
              .toList();
      final payload = {
        'prices': _customPrices,
        'apt_qty_override': _aptQtyOverride,
        'apt_price_override': _aptPriceOverride,
        'balc_qty_override': _balcQtyOverride,
        'balc_price_override': _balcPriceOverride,
        'apt_custom_lines': serializeCustom(_aptCustomLines),
        'balc_custom_lines': serializeCustom(_balcCustomLines),
        'balcony_fabric_key': _balconyFabricKey,
        'deposit_paid': _depositPaid,
        'apartment_total': apt.grandTotal,
        'balcony_total': balc.grandTotal,
        'grand_total': grandTotal,
        'remaining_balance': remaining,
        'saved_at': FieldValue.serverTimestamp(),
      };

      await docRef.set({
        'invoice': payload,
        'totalCost': grandTotal,
        'depositPaid': _depositPaid,
        'remainingBalance': remaining,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _saving = false;
          _savedRecently = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ الفاتورة بنجاح في ملف العميل',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحفظ: $e', textAlign: TextAlign.center),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
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
      accessoryLines: [...apply(base.accessoryLines), ..._aptCustomLines],
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
      accessoryLines: [...apply(base.accessoryLines), ..._balcCustomLines],
    );
  }

  // ============================ الواجهة الرئيسية ============================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0E14),
        appBar: _buildAppBar(),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFC7A064)),
              )
            : _loadError != null
            ? _buildErrorView()
            : Column(
                children: [
                  _buildClientHero(),
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
      backgroundColor: const Color(0xFF0C0E14),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 72,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8CE91), Color(0xFF9C713A)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x339E7A43),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF101016),
              size: 24,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'باريس للستائر',
                  style: TextStyle(
                    color: Color(0xFFF6E7C3),
                    fontSize: 17,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'INVOICE STUDIO  •  2026',
                  style: TextStyle(
                    color: Color(0xFF8F8A80),
                    fontSize: 9,
                    letterSpacing: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _appBarAction(
          icon: Icons.tune_rounded,
          tooltip: 'إعدادات الأسعار',
          onPressed: _openPriceSettings,
        ),
        _appBarAction(
          icon: Icons.share_rounded,
          tooltip: 'مشاركة الفاتورة',
          onPressed: _shareAsText,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, end: 10),
          child: Material(
            color: const Color(0xFF211D17),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _save,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE6C98A),
                          ),
                        )
                      : Icon(
                          _savedRecently
                              ? Icons.check_circle_rounded
                              : Icons.save_rounded,
                          color: _savedRecently
                              ? const Color(0xFF34D399)
                              : const Color(0xFFE6C98A),
                          size: 21,
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _appBarAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 3),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF171821),
          fixedSize: const Size(39, 39),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0x223E3B35)),
          ),
        ),
        icon: Icon(icon, color: const Color(0xFFD9C08A), size: 19),
      ),
    );
  }

  Widget _buildClientHero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF28231C), Color(0xFF191A21), Color(0xFF15161D)],
        ),
        border: Border.all(color: const Color(0x55C7A064)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x22D6B879),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0x66D6B879)),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFFE6C98A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'فاتورة العميل',
                      style: TextStyle(
                        color: Color(0xFFB7A98D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((widget.address ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFFB9A16E),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              widget.address!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB8B8C0),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF16352D),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0x4434D399)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 12,
                      color: Color(0xFF6EE7B7),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'جاهزة',
                      style: TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF0C0E14),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x446C5837)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC7A064), Color(0xFFE6C98A)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          labelColor: const Color(0xFF0C0E14),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            fontFamily: 'Cairo',
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            fontFamily: 'Cairo',
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.home_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'ستائر الشقة (${_arNum(_windows.where((w) => w.enabled).length)})',
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.balcony_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'ستائر البلكونة (${_arNum(_balconies.where((b) => b.enabled).length)})',
                  ),
                ],
              ),
            ),
          ],
        ),
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
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 48,
            ),
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
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC7A064),
                foregroundColor: const Color(0xFF0C0E14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================ تبويب الشقة ============================

  Widget _buildApartmentTab() {
    final invoice = _getApartmentInvoice();

    if (_windows.where((w) => w.enabled).isEmpty) {
      return _buildEmptyState(
        icon: Icons.curtains_rounded,
        title: 'لا توجد مقاسات مسجلة للشقة',
        sub: 'أضف مقاسات الشبابيك من شاشة مقاسات العميل أولاً',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
      children: [
        _buildSectionCard(
          title: 'المستلزمات، المواسير والتفصيل',
          icon: Icons.hardware_rounded,
          accent: const Color(0xFF38BDF8),
          lines: invoice.accessoryLines,
          totalLabel: 'إجمالي المستلزمات',
          totalVal: invoice.accessoryTotal,
          onEditQty: (key, current) => _openQuickEdit(
            title: 'تعديل الكمية',
            current: current,
            unit: '',
            onSave: (v) => setState(() => _aptQtyOverride[key] = v),
          ),
          onEditPrice: (key, current) => _openQuickEdit(
            title: 'تعديل سعر الوحدة',
            current: current,
            unit: 'ج.م',
            onSave: (v) => setState(() => _aptPriceOverride[key] = v),
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'الأقمشة المطلوبة',
          icon: Icons.texture_rounded,
          accent: const Color(0xFFC7A064),
          lines: invoice.fabricLines,
          totalLabel: 'إجمالي الأقمشة',
          totalVal: invoice.fabricTotal,
          onEditQty: (key, current) => _openQuickEdit(
            title: 'تعديل أمتار القماش',
            current: current,
            unit: 'متر',
            onSave: (v) => setState(() => _aptQtyOverride[key] = v),
          ),
          onEditPrice: (key, current) => _openQuickEdit(
            title: 'تعديل سعر المتر',
            current: current,
            unit: 'ج.م',
            onSave: (v) => setState(() => _aptPriceOverride[key] = v),
          ),
        ),
        const SizedBox(height: 10),
        _buildAddCustomLineButton(isBalcony: false),
      ],
    );
  }

  // ============================ تبويب البلكونة ============================

  Widget _buildBalconyTab() {
    final invoice = _getBalconyInvoice();

    if (_balconies.where((b) => b.enabled).isEmpty) {
      return _buildEmptyState(
        icon: Icons.balcony_rounded,
        title: 'لا توجد مقاسات مسجلة للبلكونة',
        sub: 'أضف أضلاع البلكونة من شاشة مقاسات العميل أولاً',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
      children: [
        _buildSectionCard(
          title: 'المواسير والمستلزمات والتركيب',
          icon: Icons.build_circle_rounded,
          accent: const Color(0xFFA855F7),
          lines: invoice.accessoryLines,
          totalLabel: 'إجمالي مستلزمات البلكونة',
          totalVal: invoice.accessoryTotal,
          onEditQty: (key, current) => _openQuickEdit(
            title: 'تعديل الكمية',
            current: current,
            unit: '',
            onSave: (v) => setState(() => _balcQtyOverride[key] = v),
          ),
          onEditPrice: (key, current) => _openQuickEdit(
            title: 'تعديل سعر الوحدة',
            current: current,
            unit: 'ج.م',
            onSave: (v) => setState(() => _balcPriceOverride[key] = v),
          ),
        ),
        const SizedBox(height: 12),
        _buildBalconyFabricSelector(),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'قماش البلكونة',
          icon: Icons.texture_rounded,
          accent: const Color(0xFF10B981),
          lines: invoice.fabricLines,
          totalLabel: 'إجمالي قماش البلكونة',
          totalVal: invoice.fabricTotal,
          onEditQty: (key, current) => _openQuickEdit(
            title: 'تعديل أمتار القماش',
            current: current,
            unit: 'متر',
            onSave: (v) => setState(() => _balcQtyOverride[key] = v),
          ),
          onEditPrice: (key, current) => _openQuickEdit(
            title: 'تعديل سعر المتر',
            current: current,
            unit: 'ج.م',
            onSave: (v) => setState(() => _balcPriceOverride[key] = v),
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 10),
        _buildAddCustomLineButton(isBalcony: true),
      ],
    );
  }

  Widget _buildBalconyFabricSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x5555c7a064)),
      ),
      child: Row(
        children: [
          const Icon(Icons.palette_rounded, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 8),
          const Text(
            'قماش البلكونة',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: kBalconyFabrics.containsKey(_balconyFabricKey)
                    ? _balconyFabricKey
                    : 'fabric_dak',
                isExpanded: true,
                dropdownColor: const Color(0xFF161622),
                icon: const Icon(Icons.expand_more, color: Color(0xFF10B981)),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                items: kBalconyFabrics.entries.map((e) {
                  final price =
                      _customPrices[e.key] ?? defaultPrices()[e.key] ?? 0;
                  return DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(
                      '${e.value} — ${_money(price)} ج/م',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _balconyFabricKey = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================ كارت القسم والجدول ============================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color accent,
    required List<InvoiceLine> lines,
    required String totalLabel,
    required double totalVal,
    required void Function(String key, double current) onEditQty,
    required void Function(String key, double current) onEditPrice,
  }) {
    if (lines.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0x446C5837)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 13,
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // رأس القسم
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
              border: Border(
                bottom: BorderSide(color: accent.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_arNum(lines.length)} بنود',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // رأس الأعمدة: [الكمية] | [البند] | [السعر] | [الإجمالي]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: const Color(0xFF0C0E14).withValues(alpha: 0.6),
            child: Row(
              children: const [
                SizedBox(
                  width: 65,
                  child: Text(
                    'الكمية',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'البند',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 65,
                  child: Text(
                    'السعر',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'الإجمالي',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),

          // أسطر البنود — بدون وصف فرعي متكلف ومضغوطة لشاشة الهاتف
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lines.length,
            separatorBuilder: (_, _) =>
                const Divider(color: Color(0x5555c7a064), height: 1),
            itemBuilder: (ctx, i) {
              final line = lines[i];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // الكمية ككبسولة ذكية تفتح شيت التعديل
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onEditQty(line.key, line.qty),
                      child: Container(
                        width: 65,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0E14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x5555c7a064)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _fmtQty(line.qty),
                              style: const TextStyle(
                                color: Color(0xFFF1F5F9),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            if (line.unit.isNotEmpty) ...[
                              const SizedBox(width: 2),
                              Text(
                                line.unit,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // اسم البند وحده صافياً بدون كلام تحته
                    Expanded(
                      child: Text(
                        line.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // السعر ككبسولة ذكية
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onEditPrice(line.key, line.unitPrice),
                      child: Container(
                        width: 65,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0E14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x5555c7a064)),
                        ),
                        child: Text(
                          _money(line.unitPrice),
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // إجمالي البند
                    SizedBox(
                      width: 72,
                      child: Text(
                        '${_money(line.total)} ج',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // فوتر القسم
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0C0E14),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              border: Border(top: BorderSide(color: Color(0x5555c7a064))),
            ),
            child: Row(
              children: [
                Text(
                  totalLabel,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_money(totalVal)} ج.م',
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String sub,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x5555c7a064)),
              ),
              child: Icon(icon, size: 48, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCustomLineButton({required bool isBalcony}) {
    return TextButton.icon(
      onPressed: () => _openAddCustomLineDialog(isBalcony: isBalcony),
      icon: const Icon(
        Icons.add_circle_outline_rounded,
        size: 18,
        color: Color(0xFFC7A064),
      ),
      label: const Text(
        'إضافة بند يدوي مخصص للفاتورة',
        style: TextStyle(
          color: Color(0xFFC7A064),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // ============================ الشريط المالي السفلي (المعادلة) ============================

  Widget _buildBottomSummaryBar() {
    final aptInv = _getApartmentInvoice();
    final balcInv = _getBalconyInvoice();

    final isApartmentTab = _tabController.index == 0;
    final currentTabTotal = isApartmentTab
        ? aptInv.grandTotal
        : balcInv.grandTotal;

    final combinedTotal = roundMoney(aptInv.grandTotal + balcInv.grandTotal);
    final remaining = roundMoney(combinedTotal - _depositPaid);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        border: Border(top: BorderSide(color: Color(0x5555c7a064), width: 1.5)),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // السطر الأول: تفصيل الحساب والعربون
              Row(
                children: [
                  // إجمالي الفاتورة الحالية
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isApartmentTab ? 'فاتورة الشقة' : 'فاتورة البلكونة',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_money(currentTabTotal)} ج',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // زر تعديل العربون
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _openDepositDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0E14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x5555c7a064)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.payments_rounded,
                                size: 13,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'العربون المدفوع',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_money(_depositPaid)} ج',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // المتبقي الصافي
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: remaining > 0
                            ? [
                                const Color(0xFFDC2626).withValues(alpha: 0.2),
                                const Color(0xFFEF4444).withValues(alpha: 0.1),
                              ]
                            : [
                                const Color(0xFF10B981).withValues(alpha: 0.2),
                                const Color(0xFF059669).withValues(alpha: 0.1),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: remaining > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          remaining > 0 ? 'المتبقي مطلوب' : 'خالص بالكامل',
                          style: TextStyle(
                            color: remaining > 0
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFF6EE7B7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_money(remaining.abs())} ج',
                          style: TextStyle(
                            color: remaining > 0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // السطر الثاني: إجمالي الحسابين معاً لو الشقة والبلكونة موجودين
              if (_windows.any((w) => w.enabled) &&
                  _balconies.any((b) => b.enabled))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0E14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إجمالي الشقة والبلكونة معاً:',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${_money(combinedTotal)} ج.م',
                        style: const TextStyle(
                          color: Color(0xFFC7A064),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
      backgroundColor: const Color(0xFF161622),
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
                        color: const Color(0xFF0C0E14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFC7A064)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _arNum(controller.text),
                            style: const TextStyle(
                              color: Color(0xFFC7A064),
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
                        fillColor: const Color(0xFF0C0E14),
                        hintText: 'أو اكتب القيمة مباشرة',
                        hintStyle: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0x5555c7a064),
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
                              backgroundColor: const Color(0xFFC7A064),
                              foregroundColor: const Color(0xFF0C0E14),
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
              ? const Color(0xFFC7A064).withValues(alpha: 0.18)
              : const Color(0xFF0C0E14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPositive
                ? const Color(0xFFC7A064)
                : const Color(0x5555c7a064),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isPositive ? const Color(0xFFC7A064) : Colors.white,
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
            backgroundColor: const Color(0xFF161622),
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
                fillColor: const Color(0xFF0C0E14),
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
                  borderSide: const BorderSide(color: Color(0x5555c7a064)),
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
            backgroundColor: const Color(0xFF161622),
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
                  );

                  setState(() {
                    if (isBalcony) {
                      _balcCustomLines.add(line);
                    } else {
                      _aptCustomLines.add(line);
                    }
                  });

                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC7A064),
                  foregroundColor: const Color(0xFF0C0E14),
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
      backgroundColor: const Color(0xFF161622),
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
                        Icon(Icons.tune_rounded, color: Color(0xFFC7A064)),
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
                        separatorBuilder: (_, _) => const Divider(
                          color: Color(0x5555c7a064),
                          height: 1,
                        ),
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
                                color: const Color(0xFF0C0E14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0x5555c7a064),
                                ),
                              ),
                              child: Text(
                                '${_money(current)} ج',
                                style: const TextStyle(
                                  color: Color(0xFFC7A064),
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
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC7A064),
                              foregroundColor: const Color(0xFF0C0E14),
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
    final combined = roundMoney(aptInv.grandTotal + balcInv.grandTotal);
    final remaining = roundMoney(combined - _depositPaid);

    final b = StringBuffer();
    b.writeln('━━━━━━━━━━━━━━━━━━━━');
    b.writeln('✨ ستائر باريس — PARIS CURTAINS ✨');
    b.writeln('━━━━━━━━━━━━━━━━━━━━');
    b.writeln('👤 العميل: ${widget.clientName}');
    if (widget.phone != null && widget.phone!.isNotEmpty) {
      b.writeln('📱 الهاتف: ${_arNum(widget.phone!)}');
    }
    b.writeln('━━━━━━━━━━━━━━━━━━━━');

    if (_windows.any((w) => w.enabled)) {
      b.writeln('🏠 [ستائر الشقة]');
      for (final l in aptInv.fabricLines) {
        b.writeln(
          '• ${l.label}: ${_fmtQty(l.qty)} ${l.unit} × ${_money(l.unitPrice)} = ${_money(l.total)} ج',
        );
      }
      for (final l in aptInv.accessoryLines) {
        b.writeln(
          '• ${l.label}: ${_fmtQty(l.qty)} ${l.unit} × ${_money(l.unitPrice)} = ${_money(l.total)} ج',
        );
      }
      b.writeln('🔹 إجمالي الشقة: ${_money(aptInv.grandTotal)} ج.م');
      b.writeln('');
    }

    if (_balconies.any((b) => b.enabled)) {
      b.writeln('🌿 [ستائر البلكونة]');
      for (final l in balcInv.fabricLines) {
        b.writeln(
          '• ${l.label}: ${_fmtQty(l.qty)} ${l.unit} × ${_money(l.unitPrice)} = ${_money(l.total)} ج',
        );
      }
      for (final l in balcInv.accessoryLines) {
        b.writeln(
          '• ${l.label}: ${_fmtQty(l.qty)} ${l.unit} × ${_money(l.unitPrice)} = ${_money(l.total)} ج',
        );
      }
      b.writeln('🔹 إجمالي البلكونة: ${_money(balcInv.grandTotal)} ج.م');
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
          'تم نسخ نص الفاتورة بالكامل! جاهز للإرسال على واتساب 📲',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFC7A064),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
