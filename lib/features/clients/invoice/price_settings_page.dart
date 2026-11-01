import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'invoice_calculator.dart';

// ألوان الصفحة (نفس هوية صفحة الفاتورة)
const Color _kBg = Color(0xFF0F172A);
const Color _kPanel = Color(0xFF1E293B);
const Color _kLine = Color(0xFF334155);
const Color _kGold = Color(0xFFC5A059);
const Color _kMuted = Color(0xFF94A3B8);
const Color _kGreen = Color(0xFF10B981);
const Color _kRed = Color(0xFFE57373);

// ============================================================================
// تخزين ثوابت الحساب (الأسعار العامة) في Firestore: settings/prices
// بنخزّن بس الأسعار اللي اتغيّرت عن الأصلية. أي سعر مش متغيّر بيرجع
// لقيمته في invoice_calculator.dart.
// ============================================================================
class PricesRepository {
  PricesRepository._();

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('settings').doc('prices');

  static bool _loaded = false;

  /// بتحمّل الأسعار العامة مرة واحدة (أو تاني لو force). مبترميش خطأ:
  /// لو النت أو الصلاحية مش متاحة بنكمّل بآخر قيم معروفة / الأسعار الأصلية.
  static Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    try {
      final snap = await _doc.get();
      PriceOverrides.set(_parse(snap.data()));
      _loaded = true;
    } catch (e) {
      debugPrint('Prices load failed: $e');
    }
  }

  static Map<String, double> _parse(Map<String, dynamic>? data) {
    final raw = data?['prices'];
    final out = <String, double>{};
    if (raw is! Map) return out;
    final known = {for (final d in kPriceDefs) d.key: d.value};
    raw.forEach((k, v) {
      final key = k.toString();
      if (!known.containsKey(key)) return;
      if (v is! num) return;
      final n = v.toDouble();
      if (n.isNaN || n.isInfinite || n < 0) return;
      if (n == known[key]) return;
      out[key] = n;
    });
    return out;
  }

  static Future<void> save(Map<String, double> overrides) async {
    await _doc.set({
      'prices': overrides,
      'updated_at': FieldValue.serverTimestamp(),
    });
    PriceOverrides.set(overrides);
    _loaded = true;
  }
}

// ============================================================================
// تقسيم الأسعار لمجموعات في الصفحة (أي سعر جديد يتضاف في kPriceDefs
// ومش مذكور هنا هيظهر تلقائيًا في مجموعة "أخرى")
// ============================================================================
class _Group {
  final String title;
  final IconData icon;
  final List<String> keys;
  const _Group(this.title, this.icon, this.keys);
}

const List<_Group> _kGroups = [
  _Group('الأقمشة', Icons.texture_rounded, [
    'fabric_linen',
    'fabric_velvet',
    'fabric_dak',
    'fabric_blackout3d',
    'fabric_blackout_sun',
  ]),
  _Group('الويفي والمسارات', Icons.straighten_rounded, [
    'track',
    'holder_wave',
    'holder_double',
    'wave_tape',
    'wave_prep',
    'kasrat',
  ]),
  _Group('الكبس والحلقات (الشقة)', Icons.radio_button_unchecked_rounded, [
    'pipe_press',
    'cantilever_forgia',
    'qamqam_forgia',
    'press_tape',
    'ring_unit',
    'press_drill',
    'rings_per_m_apartment',
  ]),
  _Group('البلكونة', Icons.balcony_rounded, [
    'balc_pipe',
    'balc_tape',
    'balc_avez',
    'balc_sew',
    'rings_per_m_balcony',
    'balc_install',
  ]),
  _Group('الخياطة والتركيب', Icons.content_cut_rounded, [
    'sew_light',
    'sew_heavy',
    'install_window',
    'kobsha',
    'transport',
  ]),
];

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

class PriceSettingsPage extends StatefulWidget {
  const PriceSettingsPage({super.key});

  @override
  State<PriceSettingsPage> createState() => _PriceSettingsPageState();
}

class _PriceSettingsPageState extends State<PriceSettingsPage> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final d in kPriceDefs) {
      _ctrls[d.key] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    await PricesRepository.ensureLoaded(force: true);
    final current = defaultPrices();
    for (final d in kPriceDefs) {
      _ctrls[d.key]!.text = _fmt(current[d.key] ?? d.value);
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// القيمة المكتوبة (أو null لو فاضية/غلط)
  double? _valueOf(String key) {
    final t = _ctrls[key]!.text.trim();
    if (t.isEmpty) return null;
    final n = double.tryParse(normalizeDigits(t));
    if (n == null || n.isNaN || n.isInfinite || n < 0) return null;
    return n;
  }

  bool get _hasInvalid => kPriceDefs.any((d) => _valueOf(d.key) == null);

  int get _changedCount => kPriceDefs
      .where((d) => (_valueOf(d.key) ?? d.value) != d.value)
      .length;

  Future<void> _save() async {
    if (_hasInvalid || _saving) return;
    setState(() => _saving = true);
    try {
      final overrides = <String, double>{};
      for (final d in kPriceDefs) {
        final v = _valueOf(d.key)!;
        if (v != d.value) overrides[d.key] = v;
      }
      await PricesRepository.save(overrides);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ ثوابت الحساب ✨',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: _kGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Prices save failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذّر الحفظ. اتأكد من النت والصلاحيات وجرّب تاني',
            textAlign: TextAlign.center,
          ),
          backgroundColor: _kRed,
        ),
      );
    }
  }

  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _kPanel,
          title: const Text(
            'إرجاع كل الأسعار للأصلية؟',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: const Text(
            'هيرجّع كل الخانات للأسعار الأصلية في التطبيق. '
            'مش هيتحفظ غير لما تدوس "حفظ".',
            style: TextStyle(color: _kMuted, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: _kMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرجاع', style: TextStyle(color: _kGold)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    for (final d in kPriceDefs) {
      _ctrls[d.key]!.text = _fmt(d.value);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final defsByKey = {for (final d in kPriceDefs) d.key: d};
    final grouped = <String>{for (final g in _kGroups) ...g.keys};
    final others = kPriceDefs
        .where((d) => !grouped.contains(d.key))
        .map((d) => d.key)
        .toList();

    final groups = <_Group>[
      for (final g in _kGroups)
        _Group(
          g.title,
          g.icon,
          g.keys.where(defsByKey.containsKey).toList(),
        ),
      if (others.isNotEmpty)
        _Group('أخرى', Icons.more_horiz_rounded, others),
    ];

    final changed = _changedCount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kPanel,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'ثوابت الحساب',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 19,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'إرجاع كل الأسعار للأصلية',
              icon: const Icon(Icons.restart_alt_rounded, color: _kMuted),
              onPressed: _loading ? null : _resetAll,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _kGold))
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                      children: [
                        _infoBanner(),
                        for (final g in groups)
                          if (g.keys.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _groupHeader(g),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: _kPanel,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _kLine),
                              ),
                              child: Column(
                                children: [
                                  for (int i = 0; i < g.keys.length; i++) ...[
                                    if (i > 0)
                                      const Divider(
                                        height: 1,
                                        color: _kLine,
                                      ),
                                    _row(defsByKey[g.keys[i]]!),
                                  ],
                                ],
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
                  _bottomBar(changed),
                ],
              ),
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGold.withValues(alpha: 0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _kGold, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'دي الأسعار الافتراضية لأي فاتورة جديدة. الفواتير اللي '
              'اتحفظت قبل كده بتفضل على أسعارها وقت الحفظ، وتقدر '
              'تعدّل سعر فاتورة معينة من صفحة الفاتورة نفسها.',
              style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupHeader(_Group g) {
    return Row(
      children: [
        Icon(g.icon, color: _kGold, size: 18),
        const SizedBox(width: 8),
        Text(
          g.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
          ),
        ),
      ],
    );
  }

  Widget _row(PriceDef d) {
    final ctrl = _ctrls[d.key]!;
    final value = _valueOf(d.key);
    final invalid = value == null;
    final modified = !invalid && value != d.value;
    final isRingsPerMeter = d.key.startsWith('rings_per_m');
    final suffix = isRingsPerMeter ? 'حلقة/م' : 'ج';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  modified
                      ? 'الأصلي: ${_fmt(d.value)} • الوحدة: ${d.unit}'
                      : 'الوحدة: ${d.unit}',
                  style: TextStyle(
                    color: modified ? _kGold : _kMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (modified)
            IconButton(
              tooltip: 'رجّع الأصلي',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.undo_rounded, color: _kGold, size: 18),
              onPressed: () {
                ctrl.text = _fmt(d.value);
                setState(() {});
              },
            ),
          const SizedBox(width: 6),
          SizedBox(
            width: 112,
            child: TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫]')),
              ],
              style: const TextStyle(
                color: _kGold,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                suffixText: suffix,
                suffixStyle: const TextStyle(color: _kMuted, fontSize: 11),
                filled: true,
                fillColor: _kBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: invalid
                        ? _kRed
                        : (modified ? _kGold : _kLine),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: invalid ? _kRed : _kGold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(int changed) {
    final invalid = _hasInvalid;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: _kPanel,
          border: Border(top: BorderSide(color: _kLine)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                invalid
                    ? 'فيه خانة فاضية أو رقمها غلط'
                    : (changed == 0
                          ? 'مفيش تعديلات عن الأسعار الأصلية'
                          : '$changed سعر معدّل عن الأصلي'),
                style: TextStyle(
                  color: invalid ? _kRed : _kMuted,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: (invalid || _saving) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: _kBg,
                disabledBackgroundColor: _kLine,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kBg,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: const Text(
                'حفظ',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
