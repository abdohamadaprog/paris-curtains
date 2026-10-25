import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import 'invoice_calculator.dart';

// ألوان وهوية ستائر باريس الملكية الفاخرة (Dark & Gold)
const Color _gold = AppColors.primaryGold;
const Color _goldLight = AppColors.lightGold;
const Color _goldDeep = AppColors.goldDeep;
const Color _bgDark = Color(0xFF0C0E14);
const Color _cardDark = Color(0xFF161622);
const Color _cardDark2 = Color(0xFF1E2030);
const Color _borderGold = Color(0x55C7A064);
const Color _success = Color(0xFF4ADE80);
const Color _danger = Color(0xFFFF5252);

/// بنود أسعار تتطلب إدخال يدوي إذا لزم
const List<PriceDef> _manualPriceDefs = [
  PriceDef('kobsha', 'كوبشة', 'قطعة', 0),
  PriceDef('transport', 'موصلات ونقل', 'مرة', 0),
  PriceDef('balc_install', 'تركيب بلكونة', 'بلكونة', 0),
];

/// تحويل الأرقام إلى أرقام عربية مشرقية (٠١٢٣٤٥٦٧٨٩)
String _ar(String s) =>
    s.replaceAllMapped(RegExp(r'[0-9]'), (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)]);

String _money(double v) {
  final r = roundMoney(v);
  final f = NumberFormat(r == r.roundToDouble() ? '#,##0' : '#,##0.00', 'en');
  return _ar(f.format(r));
}

String _qtyText(double v) {
  final s = v == v.roundToDouble()
      ? v.toInt().toString()
      : v
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
  return _ar(s);
}

double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : parseNumber('${v ?? ''}');

class _Custom {
  static int _next = 0;
  _Custom({
    required this.name,
    required this.qty,
    required this.price,
    required this.balcony,
  });
  final int id = _next++;
  String name;
  double qty;
  double price;
  final bool balcony;

  Map<String, dynamic> toMap() => {
    'name': name,
    'qty': qty,
    'price': price,
    'balcony': balcony,
  };
}

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

class _InvoicePageState extends State<InvoicePage> {
  bool _loading = true;
  String? _error;
  bool _balconyTab = false;
  bool _dirty = false;
  bool _saving = false;

  // خيارات الفاتورة المعتمدة
  bool _includeFabric = false; // القماش اختياري - الاستندر مصنعية وإكسسوار
  bool _includeBalcony = false; // إضافة البلكونة للفاتورة
  double _depositPaid = 0.0; // العربون المدفوع (مقدم)

  Map<String, double> _globalDefaults = defaultPrices();
  Map<String, double> _prices = defaultPrices();
  final Map<String, double> _qtyOverride = {};
  final List<_Custom> _custom = [];
  String _balconyFabric = 'fabric_dak';
  List<WindowSpec> _windows = [];
  List<BalconySpec> _balconies = [];

  final TextEditingController _depositController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _balconyTab = widget.startOnBalcony;
    _load();
  }

  @override
  void dispose() {
    _depositController.dispose();
    super.dispose();
  }

  // ============================ جلب البيانات ============================
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final docGlobal = await FirebaseFirestore.instance
          .collection('settings')
          .doc('invoice_prices')
          .get();
      if (docGlobal.exists && docGlobal.data() != null) {
        final m = docGlobal.data()!;
        _globalDefaults = {
          for (final d in kPriceDefs) d.key: _toDouble(m[d.key] ?? d.value),
        };
      }

      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();
      final data = doc.data() ?? {};

      final rawWindows = (data['measurements'] as List<dynamic>?) ?? [];
      _windows = [
        for (final m in rawWindows)
          if (m is Map && WindowSpec.fromMap(m) != null) WindowSpec.fromMap(m)!,
      ];

      final rawBalc = (data['balconies'] as List<dynamic>?) ?? [];
      _balconies = [
        for (final m in rawBalc)
          if (m is Map && BalconySpec.fromMap(m) != null)
            BalconySpec.fromMap(m)!,
      ];

      _prices = {..._globalDefaults};

      final inv = data['invoice'];
      if (inv is Map) {
        _includeFabric = inv['include_fabric'] == true;
        _includeBalcony = inv['include_balcony'] == true;
        _depositPaid = _toDouble(inv['deposit_paid']);
        _depositController.text = _depositPaid > 0 ? '$_depositPaid' : '';

        final p = inv['prices'];
        if (p is Map) {
          for (final e in p.entries) {
            _prices['${e.key}'] = _toDouble(e.value);
          }
        }
        final q = inv['qty_overrides'];
        if (q is Map) {
          for (final e in q.entries) {
            _qtyOverride['${e.key}'] = _toDouble(e.value);
          }
        }
        final bf = inv['balcony_fabric'];
        if (bf is String && kBalconyFabrics.containsKey(bf)) {
          _balconyFabric = bf;
        }
        final cust = inv['custom'];
        if (cust is List) {
          _custom.clear();
          for (final c in cust) {
            if (c is Map) {
              _custom.add(
                _Custom(
                  name: '${c['name'] ?? ''}',
                  qty: _toDouble(c['qty']),
                  price: _toDouble(c['price']),
                  balcony: c['balcony'] == true,
                ),
              );
            }
          }
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'حدث خطأ أثناء تحميل الفاتورة: $e';
      });
    }
  }

  // ============================ حفظ الفاتورة ============================
  Future<bool> _save() async {
    setState(() => _saving = true);
    try {
      final aptTotals = _totalsFor(false);
      final balTotals = _totalsFor(true);

      final double totalBill =
          (aptTotals.acc +
                  (_includeFabric ? aptTotals.fabric : 0) +
                  (_includeBalcony ? (balTotals.acc + balTotals.fabric) : 0))
              .toDouble();
      final double remaining = (totalBill - _depositPaid) > 0
          ? (totalBill - _depositPaid)
          : 0.0;

      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .update({
            'invoice': {
              'prices': _prices,
              'qty_overrides': _qtyOverride,
              'custom': [for (final c in _custom) c.toMap()],
              'balcony_fabric': _balconyFabric,
              'include_fabric': _includeFabric,
              'include_balcony': _includeBalcony,
              'deposit_paid': _depositPaid,
              'apartment_fabric_total': aptTotals.fabric,
              'apartment_accessories_total': aptTotals.acc,
              'balcony_fabric_total': balTotals.fabric,
              'balcony_accessories_total': balTotals.acc,
              'grand_total': roundMoney(totalBill),
              'remaining_balance': roundMoney(remaining),
              'updated_at': FieldValue.serverTimestamp(),
            },
            'totalCost': roundMoney(totalBill),
            'depositPaid': roundMoney(_depositPaid),
            'remainingBalance': roundMoney(remaining),
          });

      setState(() {
        _dirty = false;
        _saving = false;
      });
      _snack('تم حفظ الفاتورة بنجاح');
      return true;
    } catch (e) {
      setState(() => _saving = false);
      _snack('تعذر الحفظ: $e');
      return false;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _cardDark2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================ الحسابات ============================
  InvoiceAuto _autoFor(bool balcony) => balcony
      ? calcBalcony(_balconies, _balconyFabric, _prices)
      : calcApartment(_windows, _prices);

  double _qtyOf(AutoLine l) => _qtyOverride[l.key] ?? l.qty;
  double _priceOf(AutoLine l) => _prices[l.priceKey] ?? 0.0;
  double _lineTotal(AutoLine l) => roundMoney(_qtyOf(l) * _priceOf(l));

  bool _visible(AutoLine l) {
    if (l.manual) return true;
    return _qtyOf(l) > 0;
  }

  ({double fabric, double acc}) _totalsFor(bool balcony) {
    final auto = _autoFor(balcony);
    var f = 0.0, a = 0.0;
    for (final l in auto.fabric) {
      f += _lineTotal(l);
    }
    for (final l in auto.accessories) {
      if (_visible(l)) a += _lineTotal(l);
    }
    for (final c in _custom.where((c) => c.balcony == balcony)) {
      a += roundMoney(c.qty * c.price);
    }
    return (fabric: roundMoney(f), acc: roundMoney(a));
  }

  void _touch(VoidCallback fn) {
    setState(() {
      fn();
      _dirty = true;
    });
  }

  void _setQty(AutoLine l, double v) => _touch(() {
    if ((v - l.qty).abs() < 1e-9) {
      _qtyOverride.remove(l.key);
    } else {
      _qtyOverride[l.key] = v;
    }
  });

  void _setPrice(String key, double v) => _touch(() => _prices[key] = v);

  // ============================ إرسال الفاتورة عبر واتساب ============================
  Future<void> _shareOnWhatsApp() async {
    final aptTotals = _totalsFor(false);
    final balTotals = _totalsFor(true);
    final autoApt = _autoFor(false);

    final double totalBill =
        aptTotals.acc +
        (_includeFabric ? aptTotals.fabric : 0) +
        (_includeBalcony ? (balTotals.acc + balTotals.fabric) : 0);
    final double remaining = (totalBill - _depositPaid) > 0
        ? (totalBill - _depositPaid)
        : 0.0;

    final buffer = StringBuffer();
    buffer.writeln('✨ *فاتورة حساب معتمدة — باريس للستاير* ✨');
    buffer.writeln('م/ عبدالرحمن حمادة · هاتف: 01012345678');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 *العميل:* ${widget.clientName}');
    if ((widget.phone ?? '').isNotEmpty) {
      buffer.writeln('📱 *الهاتف:* ${widget.phone}');
    }
    if ((widget.address ?? '').isNotEmpty) {
      buffer.writeln('📍 *العنوان:* ${widget.address}');
    }
    buffer.writeln(
      '🪟 *عدد الشبابيك:* ${_ar('${autoApt.windows}')} شبابيك (إجمالي عرض: ${_ar('${autoApt.totalWidth}')} م)',
    );
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🛠️ *المصنعيات والتركيب الداخلي:*');
    buffer.writeln(
      '• تركيب داخلي للشقة (ثابت ١٠٠ج للشباك): ${_money((autoApt.windows * 100).toDouble())} ج.م',
    );
    buffer.writeln('• إجمالي المصنعيات والتجهيز: ${_money(aptTotals.acc)} ج.م');

    if (_includeFabric) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('🧵 *أقمشة الستائر (مشمولة بالفاتورة):*');
      buffer.writeln('• إجمالي الأقمشة: ${_money(aptTotals.fabric)} ج.م');
    } else {
      buffer.writeln(
        '*(ملاحظة: القماش توريد العميل وغير مضاف في هذه الفاتورة)*',
      );
    }

    if (_includeBalcony && balTotals.acc > 0) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln(
        '🏖️ *حساب البلكونات:* ${_money(balTotals.acc + balTotals.fabric)} ج.م',
      );
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 *إجمالي الحساب:* ${_money(totalBill)} ج.م');
    if (_depositPaid > 0) {
      buffer.writeln('✅ *تم دفع عربون:* ${_money(_depositPaid)} ج.م');
    }
    buffer.writeln(
      '🔥 *المتبقي عند الاستلام والتركيب:* ${_money(remaining)} ج.م',
    );
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln(
      '📜 *الضمان:* ضمان شامل 3 سنوات على التراكات والإكسسوارات الصامتة.',
    );

    final phoneClean = (widget.phone ?? '').replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse(
      'https://wa.me/2$phoneClean?text=${Uri.encodeComponent(buffer.toString())}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('تعذر فتح تطبيق واتساب');
    }
  }

  // ============================ الواجهة ============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _cardDark,
        elevation: 0,
        title: Text(
          'فاتورة: ${widget.clientName}',
          style: const TextStyle(
            color: _gold,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'إعدادات الأسعار الافتراضية',
            icon: const Icon(Icons.tune_rounded, color: _gold),
            onPressed: _openPrices,
          ),
          IconButton(
            tooltip: 'مشاركة عبر واتساب',
            icon: const Icon(Icons.share_rounded, color: _success),
            onPressed: _shareOnWhatsApp,
          ),
          IconButton(
            tooltip: 'حفظ',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _gold,
                    ),
                  )
                : Icon(
                    _dirty ? Icons.save_rounded : Icons.check_circle_outline,
                    color: _dirty ? _goldLight : Colors.white38,
                  ),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : (_error != null)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _error!,
                  style: const TextStyle(color: _danger),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _content(),
    );
  }

  Widget _content() {
    final auto = _autoFor(_balconyTab);
    final t = _totalsFor(_balconyTab);
    final aptTotals = _totalsFor(false);
    final balTotals = _totalsFor(true);

    final double grandTotal =
        aptTotals.acc +
        (_includeFabric ? aptTotals.fabric : 0) +
        (_includeBalcony ? (balTotals.acc + balTotals.fabric) : 0);

    final double remaining = (grandTotal - _depositPaid) > 0
        ? (grandTotal - _depositPaid)
        : 0.0;

    final accessories = auto.accessories.where(_visible).toList();
    final customHere = _custom.where((c) => c.balcony == _balconyTab).toList();

    return Column(
      children: [
        _tabs(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
            children: [
              _clientCard(auto),
              _configBar(aptTotals, balTotals),
              const SizedBox(height: 12),

              _sectionBar(
                'أولاً : أقمشة الستائر (${_includeFabric ? "مشمولة بالحساب" : "توريد الزبون - استرشادي"})',
                total: t.fabric,
                isFabric: true,
              ),
              _tableHeader(),
              if (_balconyTab) _fabricChoice(),
              for (final l in auto.fabric) _lineRow(l),
              _subtotal('إجمالي الأقمشة', t.fabric, isSubdued: !_includeFabric),

              const SizedBox(height: 16),

              _sectionBar(
                'ثانياً : المصنعيات والإكسسوار والتركيب',
                total: t.acc,
                isFabric: false,
              ),
              _tableHeader(),
              for (final l in accessories) _lineRow(l),
              for (final c in customHere) _customRow(c),
              _addCustomButton(),
              _subtotal('إجمالي المصنعية والإكسسوار', t.acc),

              const SizedBox(height: 20),

              // كرت الملخص المالي وتسوية الحساب (إجمالي، عربون، متبقي)
              _financialSettlementCard(grandTotal, remaining),
              const SizedBox(height: 80),
            ],
          ),
        ),
        _bottomActionBar(grandTotal, remaining),
      ],
    );
  }

  Widget _tabs() {
    return Container(
      color: _cardDark,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _balconyTab = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: !_balconyTab ? _gold : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    'فاتورة ستائر الشقة (${_windows.length})',
                    style: TextStyle(
                      color: !_balconyTab ? _gold : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _balconyTab = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _balconyTab ? _gold : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    'فاتورة البلكونات (${_balconies.length})',
                    style: TextStyle(
                      color: _balconyTab ? _gold : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientCard(InvoiceAuto auto) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGold),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.clientName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _goldLight,
                  ),
                ),
                if ((widget.phone ?? '').isNotEmpty)
                  Text(
                    widget.phone!,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
          ),
          _statBox('الشبابيك', '${auto.windows}'),
          const SizedBox(width: 8),
          _statBox('إجمالي العرض', '${auto.totalWidth} م'),
        ],
      ),
    );
  }

  Widget _statBox(String title, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
          const SizedBox(height: 2),
          Text(
            _ar(val),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _configBar(
    ({double fabric, double acc}) apt,
    ({double fabric, double acc}) bal,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _cardDark2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'إضافة القماش للحساب',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
              value: _includeFabric,
              activeColor: _gold,
              onChanged: (v) => _touch(() => _includeFabric = v ?? false),
            ),
          ),
          Expanded(
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'ضم البلكونة للفاتورة',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
              value: _includeBalcony,
              activeColor: _gold,
              onChanged: (v) => _touch(() => _includeBalcony = v ?? false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionBar(
    String title, {
    required double total,
    required bool isFabric,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2030),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _goldLight,
            ),
          ),
          Text(
            '${_money(total)} ج.م',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isFabric && !_includeFabric ? Colors.white38 : _gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      color: Colors.black38,
      child: const Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              'البند والمواصفات',
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'الكمية',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'السعر',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'الإجمالي',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fabricChoice() => Container(
    padding: const EdgeInsets.all(8),
    color: _cardDark,
    child: Row(
      children: [
        const Text(
          'نوع قماش البلكونة:',
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _balconyFabric,
          dropdownColor: _cardDark2,
          style: const TextStyle(color: _gold, fontSize: 13),
          underline: const SizedBox(),
          items: [
            for (final e in kBalconyFabrics.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null) _touch(() => _balconyFabric = v);
          },
        ),
      ],
    ),
  );

  Widget _lineRow(AutoLine l) {
    final qty = _qtyOf(l);
    final price = _priceOf(l);
    final total = _lineTotal(l);
    final bool isFixedInstall = l.key == 'install';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        border: Border(bottom: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (l.note.isNotEmpty)
                  Text(
                    l.note,
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _NumBox(value: qty, onChanged: (v) => _setQty(l, v)),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: isFixedInstall
                ? Center(
                    child: Text(
                      _ar('${price.toInt()}'),
                      style: const TextStyle(color: _gold, fontSize: 13),
                    ),
                  )
                : _NumBox(
                    value: price,
                    highlight: true,
                    onChanged: (v) => _setPrice(l.priceKey, v),
                  ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${_money(total)} ج',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _goldLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customRow(_Custom c) {
    return Container(
      color: const Color(0xFF1A1D2B),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle,
                    color: _danger,
                    size: 16,
                  ),
                  onPressed: () => _touch(() => _custom.remove(c)),
                ),
                Expanded(
                  child: Text(
                    c.name,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _NumBox(
              value: c.qty,
              onChanged: (v) => _touch(() => c.qty = v),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: _NumBox(
              value: c.price,
              highlight: true,
              onChanged: (v) => _touch(() => c.price = v),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${_money(c.qty * c.price)} ج',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, color: _goldLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addCustomButton() => TextButton.icon(
    icon: const Icon(Icons.add, color: _gold, size: 16),
    label: const Text(
      'إضافة بند يدوي مخصص',
      style: TextStyle(color: _gold, fontSize: 12),
    ),
    onPressed: _addCustom,
  );

  Widget _subtotal(String label, double value, {bool isSubdued = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSubdued ? Colors.white38 : Colors.white70,
            ),
          ),
          Text(
            '${_money(value)} ج.م',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSubdued ? Colors.white38 : _gold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================ كرت الملخص المالي وتسوية الحساب ============================
  // المعادلة المعتمدة: حسابنا 10 آلاف - دفع 5 آلاف = فاضل 5 آلاف
  Widget _financialSettlementCard(double grandTotal, double remaining) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2030), Color(0xFF141522)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الملخص المالي وتسوية الحساب',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _goldLight,
                ),
              ),
              Text(
                'بالجنيه المصري (EGP)',
                style: TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 1. الإجمالي المطلوب
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إجمالي الحساب',
                        style: TextStyle(fontSize: 10, color: Colors.white54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_money(grandTotal)} ج',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _includeFabric ? 'شامل القماش' : 'مصنعية وإكسسوار',
                        style: const TextStyle(fontSize: 9, color: _gold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. العربون المدفوع
              Expanded(
                child: InkWell(
                  onTap: _editDepositDialog,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _success.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تم دفع عربون',
                              style: TextStyle(
                                fontSize: 10,
                                color: _success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(Icons.edit, size: 12, color: _success),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _depositPaid > 0
                              ? '${_money(_depositPaid)} ج'
                              : '٠ ج',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _success,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _depositPaid > 0
                              ? 'مخصوم من الإجمالي'
                              : 'اضغط لتعديل',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. المتبقي عند الاستلام
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B1017),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _danger, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المتبقي للاستلام',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFFF9E9E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_money(remaining)} ج',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF5252),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'يدفع عند التركيب',
                        style: TextStyle(fontSize: 9, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_depositPaid > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '💡 معادلة الحساب: (حسابنا ${_money(grandTotal)} ج - دفع ${_money(_depositPaid)} ج = فاضل ${_money(remaining)} ج)',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomActionBar(double grandTotal, double remaining) {
    return Container(
      color: _cardDark,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المتبقي: ${_money(remaining)} ج.م',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _danger,
                    ),
                  ),
                  Text(
                    'الإجمالي ${_money(grandTotal)} ج • مدفوع ${_money(_depositPaid)} ج',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.share, size: 16),
              label: const Text(
                'واتساب',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _shareOnWhatsApp,
            ),
          ],
        ),
      ),
    );
  }

  // ============================ النوافذ ============================
  Future<void> _editDepositDialog() async {
    final ctrl = TextEditingController(
      text: _depositPaid > 0 ? _depositPaid.toStringAsFixed(0) : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2030),
        title: const Text(
          'تسجيل العربون المدفوع (مقدم)',
          style: TextStyle(color: _goldLight, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المبلغ اللي العميل دفعه عربون ليتم خصمه من الإجمالي:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: _success,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                suffixText: 'ج.م',
                suffixStyle: const TextStyle(color: _gold),
                filled: true,
                fillColor: Colors.black38,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _gold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'تأكيد وحفظ',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      final v = double.tryParse(normalizeDigits(ctrl.text)) ?? 0.0;
      _touch(() => _depositPaid = v);
      await _save();
    }
  }

  Future<void> _addCustom() async {
    final nCtrl = TextEditingController();
    final qCtrl = TextEditingController(text: '1');
    final pCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2030),
        title: const Text('إضافة بند يدوي', style: TextStyle(color: _gold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'اسم البند'),
            ),
            TextField(
              controller: qCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'الكمية'),
            ),
            TextField(
              controller: pCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'سعر الوحدة'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إضافة', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (ok == true && nCtrl.text.trim().isNotEmpty) {
      _touch(() {
        _custom.add(
          _Custom(
            name: nCtrl.text.trim(),
            qty: double.tryParse(normalizeDigits(qCtrl.text)) ?? 1.0,
            price: double.tryParse(normalizeDigits(pCtrl.text)) ?? 0.0,
            balcony: _balconyTab,
          ),
        );
      });
    }
  }

  Future<void> _openPrices() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _cardDark2,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          builder: (_, sc) => ListView(
            controller: sc,
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'إعدادات الأسعار الافتراضية',
                style: TextStyle(
                  color: _gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              for (final d in kPriceDefs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: _NumBox(
                          value: _prices[d.key] ?? d.value,
                          highlight: true,
                          onChanged: (v) {
                            _setPrice(d.key, v);
                            setMState(() {});
                          },
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
}

class _NumBox extends StatefulWidget {
  const _NumBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.highlight = false,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final bool highlight;

  @override
  State<_NumBox> createState() => _NumBoxState();
}

class _NumBoxState extends State<_NumBox> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(covariant _NumBox old) {
    super.didUpdateWidget(old);
    if ((old.value - widget.value).abs() > 1e-9) {
      _ctrl.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _format(double v) => v == 0
      ? ''
      : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1));

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.highlight
              ? _gold.withValues(alpha: 0.5)
              : Colors.white12,
        ),
      ),
      child: TextField(
        controller: _ctrl,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          color: widget.highlight ? _goldLight : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onSubmitted: (t) {
          final v = double.tryParse(normalizeDigits(t)) ?? 0.0;
          widget.onChanged(v);
        },
      ),
    );
  }
}
