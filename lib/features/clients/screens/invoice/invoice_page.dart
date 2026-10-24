import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import 'invoice_calculator.dart';

// تصميم الفاتورة: ورق كريمي + عناوين سودا + ذهبي (زي نسخة الفاتورة المعتمدة)
const Color _gold = AppColors.primaryGold;
const Color _goldDeep = AppColors.goldDeep;
const Color _ink = Color(0xFF0C0C0C);
const Color _paper = Color(0xFFF6F0E4);
const Color _paper2 = Color(0xFFFBF7EE);
const Color _rule = Color(0xFFE2D6BC);
const Color _danger = Color(0xFFB3261E);

/// بنود أسعار بتتكتب يدوي وبتتخزن مع الفاتورة (مش ليها سعر افتراضي)
const List<PriceDef> _manualPriceDefs = [
  PriceDef('kobsha', 'كوبشة', 'قطعة', 0),
  PriceDef('transport', 'موصلات ونقل', 'مرة', 0),
  PriceDef('balc_install', 'تركيب بلكونة', 'بلكونة', 0),
];

String _ar(String s) => s.replaceAllMapped(
  RegExp(r'[0-9]'),
  (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
);

String _money(double v) {
  final r = roundMoney(v);
  final f = NumberFormat(r == r.roundToDouble() ? '#,##0' : '#,##0.00', 'en');
  return _ar(f.format(r));
}

String _qtyText(double v) {
  final s = v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return _ar(s);
}

double _toDouble(dynamic v) => v is num ? v.toDouble() : parseNumber('${v ?? ''}');

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

  Map<String, double> _globalDefaults = defaultPrices();
  Map<String, double> _prices = defaultPrices();
  final Map<String, double> _qtyOverride = {};
  final List<_Custom> _custom = [];
  String _balconyFabric = 'fabric_dak';
  List<WindowSpec> _windows = [];
  List<BalconySpec> _balconies = [];

  @override
  void initState() {
    super.initState();
    _balconyTab = widget.startOnBalcony;
    _load();
  }

  // ============================ التحميل والحفظ ============================

  Future<void> _load() async {
    try {
      final db = FirebaseFirestore.instance;

      // الأسعار الافتراضية العامة (لو القواعد ما بتسمحش بتفضل الأسعار المدمجة)
      try {
        final s = await db.collection('settings').doc('prices').get();
        if (s.exists) {
          final saved = s.data() ?? {};
          _globalDefaults = {
            ...defaultPrices(),
            for (final e in saved.entries) e.key: _toDouble(e.value),
          };
        }
      } catch (_) {}

      final doc = await db.collection('clients').doc(widget.clientId).get();
      final data = doc.data() ?? {};

      _windows = [
        for (final m in (data['measurements'] as List? ?? const []))
          if (m is Map) ...[
            if (WindowSpec.fromMap(m) != null) WindowSpec.fromMap(m)!,
          ],
      ];
      _balconies = [
        for (final m in (data['balconies'] as List? ?? const []))
          if (m is Map) ...[
            if (BalconySpec.fromMap(m) != null) BalconySpec.fromMap(m)!,
          ],
      ];

      _prices = {..._globalDefaults};
      final inv = data['invoice'];
      if (inv is Map) {
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
        final c = inv['custom'];
        if (c is List) {
          for (final raw in c) {
            if (raw is Map) {
              _custom.add(
                _Custom(
                  name: '${raw['name'] ?? ''}',
                  qty: _toDouble(raw['qty']),
                  price: _toDouble(raw['price']),
                  balcony: raw['balcony'] == true,
                ),
              );
            }
          }
        }
        final bf = inv['balcony_fabric'];
        if (bf is String && kBalconyFabrics.containsKey(bf)) _balconyFabric = bf;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<bool> _save() async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      final apt = _totalsFor(false);
      final bal = _totalsFor(true);
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .update({
            'invoice': {
              'prices': _prices,
              'qty_overrides': _qtyOverride,
              'custom': [for (final c in _custom) c.toMap()],
              'balcony_fabric': _balconyFabric,
              'apartment_fabric_total': apt.fabric,
              'apartment_accessories_total': apt.acc,
              'apartment_total': roundMoney(apt.fabric + apt.acc),
              'balcony_fabric_total': bal.fabric,
              'balcony_accessories_total': bal.acc,
              'balcony_total': roundMoney(bal.fabric + bal.acc),
              'updated_at': FieldValue.serverTimestamp(),
            },
          });
      if (!mounted) return true;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      _snack('تم حفظ الفاتورة');
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('تعذر حفظ الفاتورة: $e');
      }
      return false;
    }
  }

  void _snack(String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  // ============================ الحسابات ============================

  InvoiceAuto _autoFor(bool balcony) => balcony
      ? calcBalcony(_balconies, _balconyFabric, _prices)
      : calcApartment(_windows, _prices);

  double _qtyOf(AutoLine l) => _qtyOverride[l.key] ?? l.qty;
  double _priceOf(AutoLine l) => _prices[l.priceKey] ?? 0;
  bool _visible(AutoLine l) =>
      l.manual || l.qty > 0 || _qtyOverride.containsKey(l.key);
  double _lineTotal(AutoLine l) => roundMoney(_qtyOf(l) * _priceOf(l));

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

  // ============================ الواجهة ============================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تعديلات لم تُحفظ'),
            content: const Text('تحب تحفظ الفاتورة قبل ما تخرج؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('رجوع'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'discard'),
                child: const Text('خروج بدون حفظ'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('حفظ وخروج'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (choice == 'save') {
          if (await _save() && mounted) Navigator.of(context).pop();
        } else if (choice == 'discard') {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _paper,
        appBar: AppBar(
          backgroundColor: _ink,
          foregroundColor: _gold,
          title: Text(
            'فاتورة / عرض سعر',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          actions: [
            IconButton(
              tooltip: 'إعدادات الأسعار',
              icon: const Icon(Icons.tune_rounded),
              onPressed: _loading ? null : _openPrices,
            ),
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
                    ),
                  )
                : IconButton(
                    tooltip: 'حفظ الفاتورة',
                    icon: Icon(
                      Icons.save_rounded,
                      color: _dirty ? _gold : Colors.white54,
                    ),
                    onPressed: _loading ? null : _save,
                  ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SelectableText(
                    'تعذر تحميل بيانات العميل\n$_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _danger),
                  ),
                ),
              )
            : _content(),
      ),
    );
  }

  Widget _content() {
    final auto = _autoFor(_balconyTab);
    final t = _totalsFor(_balconyTab);
    final accessories = auto.accessories.where(_visible).toList();
    final customHere = _custom.where((c) => c.balcony == _balconyTab).toList();
    final unpriced = <String>[
      for (final l in [...auto.fabric, ...accessories])
        if (_priceOf(l) == 0 && _qtyOf(l) > 0 && l.key != 'transport') l.name,
    ];
    final empty = auto.totalWidth <= 0;

    return Column(
      children: [
        _tabs(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            children: [
              _clientCard(auto),
              if (empty)
                _notice(
                  _balconyTab
                      ? 'مفيش بلكونات مسجلة للعميل ده. سجّل مقاسات البلكونة الأول.'
                      : 'مفيش مقاسات مسجلة للعميل ده. سجّل المقاسات الأول.',
                ),
              if (unpriced.isNotEmpty)
                _notice('بنود لسه ما اتسعرتش: ${unpriced.join('، ')}', warn: true),
              _sectionBar('أولاً : الأقمشة'),
              if (_balconyTab) _fabricChoice(),
              _tableHeader(),
              for (final l in auto.fabric) _lineRow(l),
              _subtotal('إجمالي تكلفة الأقمشة', t.fabric),
              const SizedBox(height: 12),
              _sectionBar('ثانياً : الإكسسوارات والمصنعية'),
              _tableHeader(),
              for (final l in accessories) _lineRow(l),
              for (final c in customHere) _customRow(c),
              _addCustomButton(),
              _subtotal('إجمالي تكلفة الإكسسوارات والمصنعية', t.acc),
              const SizedBox(height: 12),
              _notes(),
            ],
          ),
        ),
        _grandTotal(t.fabric + t.acc),
      ],
    );
  }

  Widget _tabs() {
    Widget tab(String label, bool balcony) {
      final active = _balconyTab == balcony;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _balconyTab = balcony),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? _ink : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? _gold : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _paper2,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _rule),
      ),
      child: Row(children: [tab('ستائر الشقة', false), tab('فاتورة بلكونة', true)]),
    );
  }

  Widget _clientCard(InvoiceAuto auto) {
    Widget cell(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );

    final phone = (widget.phone ?? '').trim();
    final address = (widget.address ?? '').trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _paper2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.clientName,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          if (phone.isNotEmpty || address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [if (phone.isNotEmpty) phone, if (address.isNotEmpty) address].join('  •  '),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          const Divider(height: 18, color: _rule),
          Row(
            children: [
              cell(
                _balconyTab ? 'إجمالي المقاسات' : 'إجمالي أطوال الشبابيك',
                '${_qtyText(roundMoney(auto.totalWidth))} م',
              ),
              cell(
                _balconyTab ? 'عدد البلكونات' : 'عدد الشبابيك',
                _qtyText(auto.windows.toDouble()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notice(String text, {bool warn = false}) {
    final color = warn ? _danger : _goldDeep;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          Icon(warn ? Icons.warning_amber_rounded : Icons.info_outline, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _sectionBar(String title) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: const BoxDecoration(
      color: _ink,
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    child: Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
    ),
  );

  Widget _tableHeader() {
    Widget h(String t, int flex) => Expanded(
      flex: flex,
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _gold, fontSize: 11.5, fontWeight: FontWeight.bold),
      ),
    );
    return Container(
      color: const Color(0xFF1B1B1B),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      child: Row(children: [h('البند', 5), h('الكمية', 2), h('السعر', 2), h('الإجمالي', 2)]),
    );
  }

  Widget _fabricChoice() => Container(
    width: double.infinity,
    color: _paper2,
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final e in kBalconyFabrics.entries)
          ChoiceChip(
            label: Text(
              '${e.value} • ${_money(_prices[e.key] ?? 0)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _balconyFabric == e.key ? Colors.black : Colors.black54,
              ),
            ),
            selected: _balconyFabric == e.key,
            showCheckmark: false,
            selectedColor: _gold,
            backgroundColor: Colors.white,
            side: BorderSide(color: _balconyFabric == e.key ? _goldDeep : _rule),
            onSelected: (_) => _touch(() => _balconyFabric = e.key),
          ),
      ],
    ),
  );

  Widget _lineRow(AutoLine l) {
    final qty = _qtyOf(l);
    final price = _priceOf(l);
    final overridden = _qtyOverride.containsKey(l.key);
    final flagged = price == 0 && qty > 0 && l.key != 'transport';
    final quick = l.key == 'kobsha' || l.key == 'balc_install';
    final total = _lineTotal(l);
    final mode = _balconyTab ? 'b' : 'a';

    return Container(
      decoration: const BoxDecoration(
        color: _paper2,
        border: Border(bottom: BorderSide(color: _rule)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(
                      l.note.isEmpty ? l.unit : '${l.unit} • ${l.note}',
                      style: const TextStyle(fontSize: 10.5, color: Colors.black54),
                    ),
                    if (overridden)
                      InkWell(
                        onTap: () => _touch(() => _qtyOverride.remove(l.key)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '↺ رجوع للكمية التلقائية',
                            style: TextStyle(fontSize: 10.5, color: _goldDeep, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: _NumField(
                  key: ValueKey('q-$mode-${l.key}'),
                  value: qty,
                  highlight: overridden,
                  onChanged: (v) => _setQty(l, v),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: _NumField(
                  key: ValueKey('p-$mode-${l.priceKey}'),
                  value: price,
                  blankZero: true,
                  flagged: flagged,
                  onChanged: (v) => _setPrice(l.priceKey, v),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  total > 0 ? _money(total) : '—',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (quick)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 6,
                children: [
                  for (final v in const [100.0, 200.0, 300.0])
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(_ar('${v.toInt()}'), style: const TextStyle(fontSize: 11)),
                      backgroundColor: price == v ? _gold : Colors.white,
                      side: const BorderSide(color: _rule),
                      onPressed: () => _setPriceAndRefresh(l.priceKey, v),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // الشيبس لازم تحدّث خانة السعر المفتوحة كمان
  void _setPriceAndRefresh(String key, double v) {
    FocusManager.instance.primaryFocus?.unfocus();
    _touch(() => _prices[key] = v);
  }

  Widget _customRow(_Custom c) {
    return Container(
      decoration: const BoxDecoration(
        color: _paper2,
        border: Border(bottom: BorderSide(color: _rule)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                InkWell(
                  onTap: () => _touch(() => _custom.remove(c)),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 18, color: _danger),
                  ),
                ),
                Expanded(
                  child: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _NumField(
              key: ValueKey('cq-${c.id}'),
              value: c.qty,
              onChanged: (v) => _touch(() => c.qty = v),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: _NumField(
              key: ValueKey('cp-${c.id}'),
              value: c.price,
              blankZero: true,
              onChanged: (v) => _touch(() => c.price = v),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              roundMoney(c.qty * c.price) > 0 ? _money(c.qty * c.price) : '—',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addCustomButton() => Container(
    width: double.infinity,
    color: _paper2,
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: TextButton.icon(
      onPressed: _addCustom,
      icon: const Icon(Icons.add_circle_outline, color: _goldDeep),
      label: const Text('إضافة بند جديد', style: TextStyle(color: _goldDeep, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _subtotal(String label, double value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: const BoxDecoration(
      color: _ink,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
        ),
        Text(
          '${_money(value)} ج.م',
          style: const TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  Widget _grandTotal(double value) => Container(
    padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
    decoration: const BoxDecoration(
      color: _ink,
      border: Border(top: BorderSide(color: _gold, width: 1.5)),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'الإجمالي النهائي',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Text(
          '${_money(value)} ج.م',
          style: const TextStyle(color: _gold, fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  Widget _notes() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _paper2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _rule),
    ),
    child: const Text(
      'ملاحظات:\n'
      '• الأسعار قابلة للتغيير في حال تعديل المقاسات أو الخامات.\n'
      '• مدة التنفيذ تختلف حسب حجم الشغل.\n'
      '• السعر يشمل الخامات والمصنعية طبقًا للبيانات المذكورة.',
      style: TextStyle(fontSize: 12, height: 1.6, color: Colors.black54),
    ),
  );

  // ============================ النوافذ ============================

  Future<void> _addCustom() async {
    final name = TextEditingController();
    final qty = TextEditingController(text: '1');
    final price = TextEditingController();
    InputDecoration deco(String t) =>
        InputDecoration(labelText: t, isDense: true, border: const OutlineInputBorder());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة بند جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, autofocus: true, decoration: deco('اسم البند')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qty,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: deco('الكمية'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: deco('سعر الوحدة'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    final n = name.text.trim();
    final q = parseNumber(qty.text);
    final p = parseNumber(price.text);
    name.dispose();
    qty.dispose();
    price.dispose();
    if (ok == true && n.isNotEmpty && mounted) {
      _touch(() => _custom.add(_Custom(name: n, qty: q, price: p, balcony: _balconyTab)));
    }
  }

  Future<void> _openPrices() async {
    final tmp = Map<String, double>.from(_prices);
    var version = 0;
    final defs = [...kPriceDefs, ..._manualPriceDefs];

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('إعدادات الأسعار'),
          contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final d in defs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            '${d.label}\n${d.unit}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: _NumField(
                            key: ValueKey('set-${d.key}-$version'),
                            value: tmp[d.key] ?? 0,
                            blankZero: true,
                            onChanged: (v) => tmp[d.key] = v,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actionsOverflowButtonSpacing: 4,
          actions: [
            TextButton(
              onPressed: () => setD(() {
                tmp
                  ..clear()
                  ..addAll(_globalDefaults);
                version++;
              }),
              child: const Text('رجوع للافتراضي'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'apply'),
              child: const Text('على الفاتورة دي'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, 'default'),
              child: const Text('حفظ كافتراضي'),
            ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;
    _touch(() => _prices = Map<String, double>.from(tmp));
    if (action == 'default') {
      try {
        await FirebaseFirestore.instance.collection('settings').doc('prices').set(tmp);
        _globalDefaults = {...defaultPrices(), ...tmp};
        _snack('تم حفظ الأسعار كإعدادات افتراضية للفواتير الجديدة');
      } catch (e) {
        _snack('اتطبقت على الفاتورة دي بس. تعذر حفظها كافتراضي (راجع قواعد Firestore): $e');
      }
    }
  }
}

// ============================ خانة رقم قابلة للتعديل ============================

class _NumField extends StatefulWidget {
  const _NumField({
    super.key,
    required this.value,
    required this.onChanged,
    this.highlight = false,
    this.flagged = false,
    this.blankZero = false,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final bool highlight;
  final bool flagged;
  final bool blankZero;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _c = TextEditingController(text: _text(widget.value));
  final FocusNode _f = FocusNode();

  String _text(double v) {
    if (widget.blankZero && v == 0) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  void didUpdateWidget(covariant _NumField old) {
    super.didUpdateWidget(old);
    if (!_f.hasFocus && old.value != widget.value) _c.text = _text(widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.flagged
        ? _danger
        : widget.highlight
        ? _goldDeep
        : _rule;
    return SizedBox(
      height: 34,
      child: TextField(
        controller: _c,
        focusNode: _f,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        onChanged: (s) => widget.onChanged(parseNumber(s)),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.flagged ? 'سعر؟' : '—',
          hintStyle: TextStyle(fontSize: 11, color: widget.flagged ? _danger : Colors.black38),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border, width: widget.flagged || widget.highlight ? 1.5 : 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _gold, width: 2),
          ),
        ),
      ),
    );
  }
}
