part of 'paris_client_measurements_page.dart';

// ============================================================================
// محرر المقاسات (شاشة كاملة) — بيستبدل الكارت المنبثق + لوحة التعديل القديمة
//
//  • شاشة واحدة لكل شغل التعديل، بتفتح بحركة ناعمة.
//  • لوحة أرقام مدمجة (٠–٩ + ٫ + مسح): مفيش كيبورد النظام اللي كان بيغطي
//    الشاشة ويقلب الأرقام عربي/إنجليزي. الأرقام كلها بتتعرض عربي ثابت.
//  • + و − كبار بضغط مطوّل بيسرّع، وشرايح الخطوة (٠٫٠١ · ٠٫٠٥ · ٠٫١ · ٠٫٥).
//  • النتيجة (قماش/خياطة/عجل/أفيز) فوق طول الوقت وبتتحدّث لحظيًا.
//  • سحب يمين/شمال أو أسهم للتنقل بين المقاسات، و"التالي" بيمشّيك
//    عرض ← ارتفاع ← المقاس اللي بعده من غير ما تقفل الشاشة.
//  • للبلكونة: الرسمة فوق والضلع اللي بتعدّله بيتلوّن فيها.
// ============================================================================

/// آخر خطوة اختارها المستخدم (بتتفتكر بين المرات)
double _lastEditorStep = 0.05;

String _arNum(String t) =>
    _toArabic(t.isEmpty ? '0.00' : t).replaceAll('.', '٫');

class _EditField {
  const _EditField(this.label, this.c, {this.side = 0});
  final String label;
  final TextEditingController c;

  /// رقم الضلع (١–٤) للبلكونة، أو ٠ لو الحقل مش ضلع
  final int side;
}

extension _MeasurementEditorLauncher on _ParisClientMeasurementsPageState {
  void _openCard(_Measurement item) {
    final i = _measurements.indexOf(item);
    if (i >= 0) _pushEditor(balcony: false, index: i);
  }

  void _openBalconyEditor(_Balcony item) {
    final i = _balconies.indexOf(item);
    if (i >= 0) _pushEditor(balcony: true, index: i);
  }

  Future<void> _pushEditor({required bool balcony, required int index}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => _ItemEditorPage(
          host: this,
          balcony: balcony,
          initialIndex: index,
        ),
        transitionsBuilder: (_, anim, _, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
    if (mounted) _rebuild(() {});
  }
}

class _ItemEditorPage extends StatefulWidget {
  const _ItemEditorPage({
    required this.host,
    required this.balcony,
    required this.initialIndex,
  });

  final _ParisClientMeasurementsPageState host;
  final bool balcony;
  final int initialIndex;

  @override
  State<_ItemEditorPage> createState() => _ItemEditorPageState();
}

class _ItemEditorPageState extends State<_ItemEditorPage> {
  static const List<double> _steps = [0.01, 0.05, 0.10, 0.50];

  _ParisClientMeasurementsPageState get host => widget.host;
  bool get _balcony => widget.balcony;

  late int _i = widget.initialIndex;
  int _f = 0; // الحقل المختار
  bool _fresh = true; // أول رقم بتكتبه بيستبدل القيمة كلها
  int _mode = 0; // 0 = المقاسات، 1 = التفصيل (للشقة فقط)
  int _dir = 1; // اتجاه حركة التنقل
  double _step = _lastEditorStep;

  double? _pressed;
  Timer? _delay;
  Timer? _repeat;
  Timer? _sync;
  int _ticks = 0;

  int get _count => _balcony ? host._balconies.length : host._measurements.length;
  _Measurement get _m => host._measurements[_i];
  _Balcony get _b => host._balconies[_i];
  int get _id => _balcony ? _b.id : _m.id;

  List<_EditField> _fields() {
    if (!_balcony) {
      final m = _m;
      return [_EditField('العرض', m.width), _EditField('الارتفاع', m.height)];
    }
    final b = _b;
    final n = b.sidesCount.clamp(1, 4).toInt();
    final labels = ['الواجهة', n == 2 ? 'الجانب' : 'اليمين', 'الشمال', 'الخلفي'];
    final ctrls = [b.side1, b.side2, b.side3, b.side4];
    return [
      for (var k = 0; k < n; k++) _EditField(labels[k], ctrls[k], side: k + 1),
      _EditField('الارتفاع', b.height),
    ];
  }

  int get _fi {
    final n = _fields().length;
    return _f.clamp(0, n - 1).toInt();
  }

  @override
  void dispose() {
    _stopHold(update: false);
    _sync?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------ منطق

  void _normalize(TextEditingController c) {
    final v = _Measurement.toDouble(c.text).clamp(0.0, 99.99).toDouble();
    final t = v.toStringAsFixed(2);
    if (c.text != t) c.text = t;
  }

  void _normalizeAll() {
    if (_count == 0 || _i >= _count) return;
    for (final f in _fields()) {
      _normalize(f.c);
    }
    if (_balcony) _b.syncPartsFromSides();
  }

  void _changed() {
    if (_balcony && _i < _count) _b.syncPartsFromSides();
    if (mounted) setState(() {});
    host._triggerAutoSave();
    // الصفحة اللي ورا بتتحدّث بعد وقفة قصيرة عشان الحركة تفضل ناعمة
    _sync ??= Timer(const Duration(milliseconds: 220), () {
      _sync = null;
      if (host.mounted) host._rebuild(() {});
    });
  }

  void _select(int k) {
    final fields = _fields();
    _normalize(fields[_fi].c);
    setState(() {
      _f = k;
      _fresh = true;
    });
  }

  void _goItem(int delta) {
    final n = _i + delta;
    if (n < 0 || n >= _count) return;
    _normalizeAll();
    setState(() {
      _dir = delta;
      _i = n;
      _f = 0;
      _fresh = true;
    });
  }

  void _close() {
    _normalizeAll();
    Navigator.of(context).pop();
  }

  void _next() {
    final fields = _fields();
    if (_fi < fields.length - 1) {
      _select(_fi + 1);
    } else if (_i < _count - 1) {
      _goItem(1);
    } else {
      _close();
    }
  }

  /// إضافة مقاس/بلكونة جديدة بنفس الإعدادات والانتقال لها فورًا (من غير
  /// ما تقفل المحرر) — عشان تسجّل كذا مقاس ورا بعض بسرعة.
  void _addNew() {
    _normalizeAll();
    if (_balcony) {
      final b = _Balcony();
      b.name.text = 'بلكونة ${_toArabic(host._balconies.length + 1)}';
      b.height.text = _b.height.text;
      host._rebuild(() => host._balconies.add(b));
      host._triggerAutoSave();
      setState(() {
        _dir = 1;
        _i = host._balconies.length - 1;
        _f = 0;
        _fresh = true;
      });
      return;
    }
    final item = host._appendMeasurementLike(_m);
    setState(() {
      _dir = 1;
      _i = host._measurements.indexOf(item);
      _f = 0;
      _fresh = true;
    });
  }

  void _key(String k) {
    final c = _fields()[_fi].c;
    var t = _fresh ? '' : c.text;
    if (k == 'back') {
      t = t.isEmpty ? '' : t.substring(0, t.length - 1);
      if (t.isEmpty) t = '0';
    } else if (k == '.') {
      if (t.isEmpty) {
        t = '0.';
      } else if (!t.contains('.')) {
        t += '.';
      }
    } else {
      t = (t == '0' || t.isEmpty) ? k : t + k;
      final dot = t.indexOf('.');
      if (dot >= 0 && t.length - dot - 1 > 2) return;
      if (dot < 0 && t.length > 2) return;
    }
    _fresh = false;
    c.text = t;
    _changed();
  }

  void _bump(double d) {
    final c = _fields()[_fi].c;
    final cur = _Measurement.toDouble(c.text);
    final nx = (((cur + d) * 100).round() / 100).clamp(0.0, 99.99).toDouble();
    c.text = nx.toStringAsFixed(2);
    _fresh = true;
    _changed();
  }

  void _startHold(double sign) {
    _stopHold(update: false);
    setState(() => _pressed = sign);
    _bump(sign * _step);
    _ticks = 0;
    _delay = Timer(const Duration(milliseconds: 380), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 80), (_) {
        _ticks++;
        final mult = _ticks > 30 ? 10 : (_ticks > 12 ? 4 : 1);
        _bump(sign * _step * mult);
      });
    });
  }

  void _stopHold({bool update = true}) {
    _delay?.cancel();
    _repeat?.cancel();
    _delay = null;
    _repeat = null;
    if (update && mounted && _pressed != null) {
      setState(() => _pressed = null);
    }
  }

  void _setSides(int n) {
    final b = _b;
    b.sidesCount = n;
    final ctrls = [b.side1, b.side2, b.side3, b.side4];
    // الضلع الجديد بيبدأ بصفر ويتحدد علطول عشان تكتب مقاسه
    for (var k = 0; k < n; k++) {
      if (ctrls[k].text.trim().isEmpty) ctrls[k].text = '0.00';
    }
    _f = (n - 1).clamp(0, 3).toInt();
    _fresh = true;
    _changed();
  }

  Future<void> _menu(String v) async {
    switch (v) {
      case 'dup':
        if (_balcony) {
          host._duplicateBalcony(_b);
        } else {
          host._duplicateMeasurement(_m);
        }
        _normalizeAll();
        setState(() {
          _dir = 1;
          _i = _count - 1;
          _f = 0;
          _fresh = true;
        });
        break;
      case 'tpl':
        await host._saveAsTemplate(_m);
        break;
      case 'del':
        final idx = _i;
        _normalizeAll();
        Navigator.of(context).pop();
        if (_balcony) {
          host._deleteBalcony(idx);
        } else {
          host._deleteMeasurement(idx);
        }
        break;
    }
  }

  // -------------------------------------------------------------- واجهة

  @override
  Widget build(BuildContext context) {
    if (_count == 0 || _i >= _count) return const Scaffold(body: SizedBox());
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _normalizeAll();
        },
        child: Scaffold(
          backgroundColor: _bg,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                _header(),
                if (!_balcony) _modeTabs(),
                Expanded(
                  child: _mode == 0 || _balcony ? _dimsLayout() : _optionsLayout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final name = _balcony ? _b.name : _m.name;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: c),
    );
    final canPrev = _i > 0;
    final canNext = _i < _count - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
      child: Column(
        children: [
          Row(
            children: [
              _headerCircle(
                icon: Icons.close_rounded,
                tooltip: 'إغلاق',
                onTap: _close,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: ValueKey('name-$_balcony-$_id'),
                  controller: name,
                  onChanged: (_) => _changed(),
                  textInputAction: TextInputAction.done,
                  style: TextStyle(
                    color: _gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: _panel,
                    hintText: _balcony ? 'اسم البلكونة' : 'اسم الغرفة',
                    hintStyle: TextStyle(color: _muted),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    border: border(_line),
                    enabledBorder: border(_line),
                    focusedBorder: border(_gold),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              _headerCircle(
                icon: Icons.add_rounded,
                tooltip: _balcony ? 'بلكونة جديدة' : 'مقاس جديد',
                onTap: _addNew,
              ),
              const SizedBox(width: 2),
              PopupMenuButton<String>(
                tooltip: 'خيارات',
                icon: Icon(Icons.more_vert_rounded, color: AppPalette.text),
                color: _panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: _menu,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'dup', child: Text('تكرار')),
                  if (!_balcony)
                    const PopupMenuItem(value: 'tpl', child: Text('حفظ كقالب')),
                  PopupMenuItem(
                    value: 'del',
                    child: Text(
                      'حذف',
                      style: TextStyle(color: AppPalette.redStrong),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                _navButton(
                  icon: Icons.chevron_right_rounded,
                  enabled: canPrev,
                  tooltip: 'السابق',
                  onTap: () => _goItem(-1),
                ),
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _balcony ? 'بلكونة' : 'مقاس',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _toArabic(_i + 1),
                          style: TextStyle(
                            color: _gold,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          ' / ${_toArabic(_count)}',
                          style: TextStyle(
                            color: AppPalette.text.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _navButton(
                  icon: Icons.chevron_left_rounded,
                  enabled: canNext,
                  tooltip: 'التالي',
                  onTap: () => _goItem(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCircle({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _panel,
        shape: CircleBorder(side: BorderSide(color: _line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: AppPalette.text, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required bool enabled,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 38,
          height: 32,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? _gold : _muted.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  Widget _modeTabs() {
    Widget tab(int m, String label, IconData icon) {
      final on = _mode == m;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () {
            _normalizeAll();
            setState(() => _mode = m);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: on ? _gold : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: on ? _bg : _muted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: on ? _bg : _muted,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            tab(0, 'المقاسات', Icons.straighten_rounded),
            tab(1, 'التفصيل', Icons.tune_rounded),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------- شاشة المقاسات

  Widget _dimsLayout() {
    final top = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Column(
        children: [
          _resultStrip(),
          const SizedBox(height: 10),
          if (_balcony) ...[
            _sidesSeg(),
            const SizedBox(height: 8),
            host._buildLiveBalconySketch(
              _b,
              selectedSide: _fields()[_fi].side,
            ),
            const SizedBox(height: 8),
          ],
          _fieldCards(),
        ],
      ),
    );

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -250) {
              _goItem(1);
            } else if (v > 250) {
              _goItem(-1);
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(-0.12 * _dir, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey('top-$_balcony-$_id'),
              child: top,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _keypadArea()),
      ],
    );
  }

  Widget _resultStrip() {
    if (_balcony) {
      final b = _b;
      return _editorStats([
        MapEntry('إجمالي المقاس', '${_toArabic(b.totalWidth.toStringAsFixed(2))} م'),
        MapEntry('قماش (× ١.٥)', '${_toArabic(b.fabricMeters.toStringAsFixed(2))} م'),
        MapEntry('إجمالي الأفيز', _toArabic(b.totalAvez)),
      ]);
    }
    final m = _m;
    final c = m.calculation;
    final hasLight = m.lightLayers > 0;
    return _editorStats([
      MapEntry(
        'قماش ثقيل',
        m.heavyEnabled ? '${_fmtAr(c.heavyMeters)} م' : '—',
      ),
      MapEntry('قماش خفيف', hasLight ? '${_fmtAr(c.lightMeters)} م' : '—'),
      if (m.blackoutEnabled)
        MapEntry('بلاك أوت', '${_fmtAr(c.blackoutMeters)} م'),
      MapEntry(
        'خياطة ثقيل',
        m.heavyEnabled ? '${_fmtAr(c.heavyHeight)} م' : '—',
      ),
      MapEntry('خياطة خفيف', hasLight ? '${_fmtAr(c.lightHeight)} م' : '—'),
      MapEntry(
        'العجل',
        m.method == _WorkMethod.press
            ? '—'
            : (m.heavyEnabled
                  ? c.heavyWheelsLabel
                  : _toArabic(c.lightWheels)),
      ),
    ]);
  }

  Widget _editorStats(List<MapEntry<String, String>> stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.28)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 18,
        runSpacing: 8,
        children: [
          for (final s in stats)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.key,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.value,
                  style: TextStyle(
                    color: AppPalette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _sidesSeg() {
    final cur = _b.sidesCount.clamp(1, 4).toInt();
    return Row(
      children: [
        Text(
          'عدد الأضلاع',
          style: TextStyle(
            color: _muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        for (var n = 1; n <= 4; n++) ...[
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _setSides(n),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: n == cur ? _gold : _panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: n == cur ? _gold : _line),
                ),
                child: Text(
                  _toArabic(n),
                  style: TextStyle(
                    color: n == cur ? _bg : AppPalette.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          if (n < 4) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _fieldCards() {
    final fields = _fields();
    final big = !_balcony;
    return Row(
      children: [
        for (var k = 0; k < fields.length; k++) ...[
          if (k > 0) SizedBox(width: big ? 10 : 6),
          Expanded(child: _fieldCard(fields[k], k, k == _fi, big)),
        ],
      ],
    );
  }

  Widget _fieldCard(_EditField f, int k, bool on, bool big) {
    final val = _Measurement.toDouble(f.c.text);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _select(k),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(vertical: big ? 14 : 9, horizontal: 6),
        decoration: BoxDecoration(
          color: on ? _gold.withValues(alpha: 0.16) : _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: on ? _gold : _line,
            width: on ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                big ? '${f.label} (م)' : f.label,
                style: TextStyle(
                  color: on ? _gold : _muted,
                  fontSize: big ? 14 : 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _arNum(f.c.text),
                style: TextStyle(
                  color: on ? _gold : AppPalette.text,
                  fontSize: big ? 36 : 21,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
            if (!big && f.side > 0)
              Text(
                val > 0 ? '${_toArabic(_calcAvez(val))} أفيز' : '—',
                style: TextStyle(color: AppPalette.amber, fontSize: 11.5),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------- لوحة الأرقام

  Widget _keypadArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        children: [
          _nudgeRow(),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) {
                final keyH = ((cons.maxHeight - 24) / 4).clamp(24.0, 62.0).toDouble();
                Widget row(List<String> keys) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      for (var j = 0; j < keys.length; j++) ...[
                        if (j > 0) const SizedBox(width: 8),
                        Expanded(child: _digitKey(keys[j], keyH)),
                      ],
                    ],
                  ),
                );
                final fields = _fields();
                final isLastField = _fi >= fields.length - 1;
                final label = !isLastField
                    ? 'التالي'
                    : (_i < _count - 1 ? 'المقاس\nالتالي' : 'تم');
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          row(['1', '2', '3']),
                          row(['4', '5', '6']),
                          row(['7', '8', '9']),
                          Row(
                            children: [
                              Expanded(child: _digitKey('.', keyH)),
                              const SizedBox(width: 8),
                              Expanded(child: _digitKey('0', keyH)),
                              const SizedBox(width: 8),
                              Expanded(child: _digitKey('00', keyH)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          SizedBox(
                            height: keyH,
                            width: double.infinity,
                            child: _padKey(
                              onTap: () => _key('back'),
                              onLongPress: () {
                                _fresh = true;
                                _key('back');
                              },
                              child: Icon(
                                Icons.backspace_outlined,
                                color: AppPalette.redStrong,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: keyH * 3 + 16,
                            width: double.infinity,
                            child: _padKey(
                              accent: true,
                              onTap: _next,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isLastField && _i >= _count - 1
                                        ? Icons.check_rounded
                                        : Icons.arrow_back_rounded,
                                    color: _bg,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _bg,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _digitKey(String k, double h) {
    final shown = k == '.' ? '٫' : _toArabic(k);
    return SizedBox(
      height: h,
      child: _padKey(
        onTap: () {
          if (k == '00') {
            _key('0');
            _key('0');
          } else {
            _key(k);
          }
        },
        child: Text(
          shown,
          style: TextStyle(
            color: AppPalette.text,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _padKey({
    required Widget child,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool accent = false,
  }) {
    return Material(
      color: accent ? _gold : _panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent ? _gold : _line),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _nudgeRow() {
    return Row(
      children: [
        _holdBtn(Icons.add_rounded, 1),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              for (var s = 0; s < _steps.length; s++) ...[
                if (s > 0) const SizedBox(width: 5),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      _lastEditorStep = _steps[s];
                      setState(() => _step = _steps[s]);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _step == _steps[s] ? _gold : _panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _line),
                      ),
                      child: Text(
                        _arNum(_steps[s].toStringAsFixed(2)),
                        style: TextStyle(
                          color: _step == _steps[s] ? _bg : AppPalette.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _holdBtn(Icons.remove_rounded, -1),
      ],
    );
  }

  Widget _holdBtn(IconData icon, double sign) {
    final down = _pressed == sign;
    return Listener(
      onPointerDown: (_) => _startHold(sign),
      onPointerUp: (_) => _stopHold(),
      onPointerCancel: (_) => _stopHold(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 54,
        height: 50,
        decoration: BoxDecoration(
          color: down ? _gold : _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold.withValues(alpha: 0.55)),
        ),
        child: Icon(icon, size: 28, color: down ? _bg : _gold),
      ),
    );
  }

  // --------------------------------------------------------- شاشة التفصيل

  Widget _optionsLayout() {
    final item = _m;
    final calc = item.calculation;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      children: [
        _resultStrip(),
        const SizedBox(height: 2),

        // ---------------------------------------------------------- الطراز
        _sectionTitle(
          'الطراز',
          icon: Icons.style_rounded,
          subtitle: 'طريقة التعليق ونوع السقف',
        ),
        _sectionBox([
          _segmentedLabel(
            'طريقة التعليق',
            _segmented<_WorkMethod>(
              values: _WorkMethod.values,
              selected: item.method,
              text: (v) => v.label,
              onChanged: (v) {
                item.method = v;
                _changed();
              },
            ),
          ),
          _softDivider(),
          _segmentedLabel(
            'نوع السقف',
            _segmented<_CeilingType>(
              values: _CeilingType.values,
              selected: item.ceiling,
              text: (v) => v.label,
              onChanged: (v) {
                item.ceiling = v;
                _changed();
              },
            ),
          ),
        ]),

        // ---------------------------------------------------- الطبقات والقماش
        _sectionTitle(
          'الطبقات والقماش',
          icon: Icons.layers_rounded,
          subtitle: _layersSubtitle(item, calc),
          trailing: item.hasException
              ? TextButton.icon(
                  onPressed: () => _resetAllExceptions(item),
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('إعادة ضبط'),
                  style: TextButton.styleFrom(
                    foregroundColor: _muted,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
        ),

        // ---------- الطبقة الثقيلة ----------
        _layerCard(
          title: 'الثقيل — قطيفة',
          subtitle: item.heavyEnabled
              ? '${_toArabic(item.velvetSides)} جنب • الطبقة الأساسية'
              : 'متوقفة — بدون قماش ثقيل',
          icon: Icons.blinds_rounded,
          color: AppPalette.amber,
          enabled: item.heavyEnabled,
          onToggle: () {
            item.heavyEnabled = !item.heavyEnabled;
            _changed();
          },
          children: [
            _sidesChips(
              label: 'عدد الأجناب',
              value: item.velvetSides,
              onChanged: (v) {
                item.velvetSides = v;
                _changed();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _statTile(
                  label: 'عرض الطبقة',
                  value: '${_fmtAr(item.heavyWidth)} م',
                  color: AppPalette.amber,
                  isOverride: item.heavyWidthOverride != null,
                  onTap: () => _editExceptionNumber(
                    title: 'عرض الطبقة الثقيلة (متر)',
                    current: item.heavyWidth,
                    min: 0.1,
                    max: 20,
                    onDone: (v) => item.heavyWidthOverride = v,
                  ),
                  onReset: () {
                    item.heavyWidthOverride = null;
                    _changed();
                  },
                ),
                const SizedBox(width: 8),
                _statTile(
                  label: 'نسبة التجميع',
                  value: '× ${_ratioText(item.heavyRatio)}',
                  color: AppPalette.amber,
                  isOverride: item.heavyRatioOverride != null,
                  onTap: () => _editExceptionNumber(
                    title: 'نسبة تجميع الثقيل',
                    current: item.heavyRatio,
                    min: 1,
                    max: 4,
                    onDone: (v) => item.heavyRatioOverride = v,
                  ),
                  onReset: () {
                    item.heavyRatioOverride = null;
                    _changed();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _resultBar(
              color: AppPalette.amber,
              width: item.heavyWidth,
              ratioText: _ratioText(item.heavyRatio),
              meters: calc.heavyMeters,
            ),
          ],
        ),

        // ---------- الطبقة الخفيفة ----------
        _layerCard(
          title: 'الخفيف — كتان',
          subtitle: item.hasLight
              ? '${_toArabic(item.lightSides)} جنب • طبقة خلفية'
              : 'متوقفة — بدون قماش خفيف',
          icon: Icons.window_rounded,
          color: AppPalette.skyLight,
          enabled: item.hasLight,
          onToggle: () {
            if (item.hasLight) {
              item.lightLayers = 0;
            } else {
              item.lightLayers = 1;
              if (item.lightSides < 1) item.lightSides = 2;
            }
            _changed();
          },
          children: [
            _sidesChips(
              label: 'عدد الأجناب',
              value: item.lightSides,
              onChanged: (v) {
                item.lightSides = v;
                _changed();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _statTile(
                  label: 'عرض الطبقة',
                  value: '${_fmtAr(item.lightWidth)} م',
                  color: AppPalette.skyLight,
                  isOverride: item.lightWidthOverride != null,
                  onTap: () => _editExceptionNumber(
                    title: 'عرض الطبقة الخفيفة (متر)',
                    current: item.lightWidth,
                    min: 0.1,
                    max: 20,
                    onDone: (v) => item.lightWidthOverride = v,
                  ),
                  onReset: () {
                    item.lightWidthOverride = null;
                    _changed();
                  },
                ),
                const SizedBox(width: 8),
                _statTile(
                  label: 'نسبة التجميع',
                  value: '× ${_ratioText(item.lightRatio)}',
                  color: AppPalette.skyLight,
                  isOverride: item.lightRatioOverride != null,
                  onTap: () => _editExceptionNumber(
                    title: 'نسبة تجميع الخفيف',
                    current: item.lightRatio,
                    min: 1,
                    max: 4,
                    onDone: (v) => item.lightRatioOverride = v,
                  ),
                  onReset: () {
                    item.lightRatioOverride = null;
                    _changed();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _resultBar(
              color: AppPalette.skyLight,
              width: item.lightWidth,
              ratioText: _ratioText(item.lightRatio),
              meters: calc.lightMeters,
            ),
          ],
        ),

        // ---------- البلاك أوت ----------
        _layerCard(
          title: 'البلاك أوت — طبقة إضافية',
          subtitle: item.blackoutEnabled
              ? '${_blackoutTypeLabel(item.blackoutType)} • عزل كامل'
              : 'متوقفة — بدون بلاك أوت',
          icon: Icons.nightlight_round,
          color: AppPalette.violet,
          enabled: item.blackoutEnabled,
          onToggle: () {
            item.blackoutEnabled = !item.blackoutEnabled;
            _changed();
          },
          children: [
            _blackoutTypeControl(item),
            const SizedBox(height: 8),
            Row(
              children: [
                _statTile(
                  label: 'عرض الطبقة',
                  value: '${_fmtAr(item.blackoutWidth)} م',
                  color: AppPalette.violet,
                  isOverride: item.blackoutWidthOverride != null,
                  onTap: () => _editExceptionNumber(
                    title: 'عرض البلاك أوت (متر)',
                    current: item.blackoutWidth,
                    min: 0.1,
                    max: 20,
                    onDone: (v) => item.blackoutWidthOverride = v,
                  ),
                  onReset: () {
                    item.blackoutWidthOverride = null;
                    _changed();
                  },
                ),
                const SizedBox(width: 8),
                _statTile(
                  label: 'نسبة التجميع',
                  value: '× ${_ratioText(item.blackoutRatio)}',
                  color: AppPalette.violet,
                  isOverride: item.blackoutRatioOverride != null,
                  onTap: () => _editExceptionNumber(
                    title: 'نسبة تجميع البلاك أوت',
                    current: item.blackoutRatio,
                    min: 1,
                    max: 2,
                    onDone: (v) => item.blackoutRatioOverride = v,
                  ),
                  onReset: () {
                    item.blackoutRatioOverride = null;
                    _changed();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _resultBar(
              color: AppPalette.violet,
              width: item.blackoutWidth,
              ratioText: _ratioText(item.blackoutRatio),
              meters: calc.blackoutMeters,
              rounded: true,
            ),
          ],
        ),

        // ------------------------------------------------------------- العجل
        if (item.method != _WorkMethod.press) ...[
          _sectionTitle(
            'العجل',
            icon: Icons.settings_rounded,
            subtitle: 'يُحسب تلقائيًا أو تعدّله يدويًا',
          ),
          _sectionBox([
            _wheelsControl(item, calc),
            const SizedBox(height: 8),
            Text(
              'قماش العجل ${_fmtAr(calc.wheelsFabricMeters)} م (العجل × ٠٫١٤٨)',
              style: TextStyle(
                fontSize: 11.5,
                color: AppPalette.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ],
      ],
    );
  }

  // ------------------------------------------------------ استثناءات القماش
  // كل طبقة (ثقيل / خفيف / بلاك أوت) ليها: تشغيل/إيقاف + عرض + نسبة تجميع.
  // أي تعديل هنا بيتحوّل لاستثناء صريح بيتحفظ ويتنقل للفاتورة وصورة المقاسات.
  // القيمة الافتراضية = عرض الشباك والنسبة حسب الطراز، فمفيش أي تغيير في
  // حسابات المقاسات القديمة.

  // ------------------------------------------------------ الطبقات والقماش
  // كل طبقة (ثقيل / خفيف / بلاك أوت) ليها: تشغيل/إيقاف + عرض + نسبة تجميع.
  // أي تعديل هنا بيتحوّل لاستثناء صريح بيتحفظ ويتنقل للفاتورة وصورة المقاسات.
  // القيمة الافتراضية = عرض الشباك والنسبة حسب الطراز، فمفيش أي تغيير في
  // حسابات المقاسات القديمة.

  String _ratioText(double r) =>
      _toArabic(r.toStringAsFixed(r == r.roundToDouble() ? 1 : 2));

  String _layersSubtitle(_Measurement item, _Calculation calc) {
    final count =
        (item.heavyEnabled ? 1 : 0) +
        (item.hasLight ? 1 : 0) +
        (item.blackoutEnabled ? 1 : 0);
    final total =
        (item.heavyEnabled ? calc.heavyMeters : 0.0) +
        (item.hasLight ? calc.lightMeters : 0.0) +
        (item.blackoutEnabled ? calc.blackoutMeters : 0.0);
    return '${_toArabic(count)} طبقة • ${_fmtAr(total)} م قماش';
  }

  String _blackoutTypeLabel(String key) =>
      key == 'fabric_blackout_sun' ? 'عازل شمس' : 'بلاك أوت 3D';

  void _resetAllExceptions(_Measurement item) {
    item.heavyEnabled = true;
    item.heavyWidthOverride = null;
    item.heavyRatioOverride = null;
    item.lightWidthOverride = null;
    item.lightRatioOverride = null;
    item.blackoutEnabled = false;
    item.blackoutWidthOverride = null;
    item.blackoutRatioOverride = null;
    _changed();
  }

  Widget _sectionTitle(
    String title, {
    required IconData icon,
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _gold.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, size: 15, color: _gold),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: AppPalette.text,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(color: _muted, fontSize: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          ?trailing,
        ],
      ),
    );
  }

  Widget _sectionBox(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _segmentedLabel(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _softDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(height: 1, color: _line.withValues(alpha: 0.7)),
    );
  }

  Widget _segmented<T>({
    required List<T> values,
    required T selected,
    required String Function(T) text,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == selected ? _gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    text(v),
                    style: TextStyle(
                      color: v == selected ? _bg : _muted,
                      fontWeight: v == selected
                          ? FontWeight.w900
                          : FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _layerCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: enabled ? color.withValues(alpha: 0.05) : _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled ? color.withValues(alpha: 0.42) : _line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (enabled ? color : _muted).withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: enabled ? color : _muted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enabled ? AppPalette.text : _muted,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: _muted, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.82,
                  child: Switch(
                    value: enabled,
                    onChanged: (_) => onToggle(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    thumbColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? color
                          : null,
                    ),
                    trackColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? color.withValues(alpha: 0.45)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sidesChips({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        for (final n in const [1, 2]) ...[
          if (n > 1) const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(n),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: value == n
                    ? _gold.withValues(alpha: 0.16)
                    : _bg,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: value == n ? _gold : _line),
              ),
              child: Text(
                '${_toArabic(n)} جنب',
                style: TextStyle(
                  color: value == n ? _gold : _muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required Color color,
    required bool isOverride,
    required VoidCallback onTap,
    required VoidCallback onReset,
  }) {
    return Expanded(
      child: Material(
        color: isOverride ? color.withValues(alpha: 0.10) : _bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOverride ? color.withValues(alpha: 0.55) : _line,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isOverride ? color : _muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isOverride)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onReset,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.restart_alt_rounded,
                            size: 14,
                            color: color,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: isOverride ? color : AppPalette.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.edit_rounded,
                      size: 12,
                      color: isOverride ? color : _muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultBar({
    required Color color,
    required double width,
    required String ratioText,
    required double meters,
    bool rounded = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.straighten_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${_fmtAr(width)} م × $ratioText = ${_fmtAr(meters)} م قماش',
              style: TextStyle(
                color: AppPalette.text.withValues(alpha: 0.88),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (rounded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'لمتر كامل',
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _blackoutTypeControl(_Measurement item) {
    Widget chip(String key, String text) {
      final on = item.blackoutType == key;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            item.blackoutType = key;
            _changed();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppPalette.violet : _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: on
                    ? AppPalette.violet
                    : AppPalette.violet.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: on ? Colors.white : _muted,
                fontWeight: on ? FontWeight.w900 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Text(
          'نوع القماش',
          style: TextStyle(
            color: _muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        chip('fabric_blackout3d', 'بلاك أوت 3D'),
        const SizedBox(width: 6),
        chip('fabric_blackout_sun', 'عازل شمس'),
      ],
    );
  }

  Future<void> _editExceptionNumber({
    required String title,
    required double current,
    required double min,
    required double max,
    required ValueChanged<double> onDone,
  }) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(2));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: Text(
          title,
          style: TextStyle(
            color: AppPalette.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            color: AppPalette.text,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
          decoration: InputDecoration(
            hintText: 'القيمة',
            helperText: 'من $min إلى $max',
            helperStyle: TextStyle(color: _muted, fontSize: 11.5),
          ),
          onSubmitted: (t) =>
              Navigator.pop(ctx, _Measurement.toDouble(t)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: _muted)),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, _Measurement.toDouble(ctrl.text)),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (value == null || value <= 0) return;
    onDone(value.clamp(min, max).toDouble());
    _changed();
  }

  Widget _wheelsControl(_Measurement item, dynamic calc) {
    final manual = item.manualWheels;
    final autoWheels =
        item.heavyEnabled ? (calc.heavyWheels as int) : (calc.lightWheels as int);
    final autoLabel = item.heavyEnabled
        ? calc.heavyWheelsLabel as String
        : _toArabic(calc.lightWheels as int);

    Widget btn(IconData icon, int d) => InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () {
        final base = manual ?? autoWheels;
        item.wheels.text = (base + d).clamp(2, 400).toString();
        _changed();
      },
      child: Container(
        width: 50,
        height: 54,
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _gold.withValues(alpha: 0.45)),
        ),
        child: Icon(icon, color: _gold, size: 26),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          btn(Icons.add_rounded, 2),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  manual != null ? 'عدد يدوي' : 'حساب تلقائي',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  manual != null ? _toArabic(manual) : autoLabel,
                  style: TextStyle(
                    color: manual != null ? _gold : AppPalette.text,
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (manual != null)
                  GestureDetector(
                    onTap: () {
                      item.wheels.clear();
                      _changed();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'رجوع للحساب التلقائي',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10.5,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          btn(Icons.remove_rounded, -2),
        ],
      ),
    );
  }
}
