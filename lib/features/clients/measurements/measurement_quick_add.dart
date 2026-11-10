part of 'paris_client_measurements_page.dart';

// ============================================================================
// الإضافة السريعة (Quick Add)
//   • بتخليك تضيف كذا مقاس (٥ / ١٠ / ١٥ ...) بضغطة واحدة بدل ما تدخل بيانات
//     كل مقاس لوحده.
//   • كل المقاسات الجديدة بتاخد نفس العرض/الارتفاع/الطراز/السقف، وبعدها
//     تقدر تعدّل أي كارت لوحده من الشاشة.
// ============================================================================

class _QuickAddResult {
  const _QuickAddResult({
    required this.count,
    required this.width,
    required this.height,
    required this.method,
    required this.ceiling,
  });

  final int count;
  final double width;
  final double height;
  final _WorkMethod method;
  final _CeilingType ceiling;
}

extension _MeasurementQuickAdd on _ParisClientMeasurementsPageState {
  Future<void> _openQuickAdd() async {
    final last = _measurements.isEmpty ? null : _measurements.last;
    final result = await showModalBottomSheet<_QuickAddResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _QuickAddSheet(
        initialWidth: last == null
            ? 3.00
            : _Measurement.toDouble(last.width.text),
        initialHeight: last == null
            ? 2.95
            : _Measurement.toDouble(last.height.text),
        initialMethod: last?.method ?? _WorkMethod.wave,
        initialCeiling: last?.ceiling ?? _CeilingType.kaboli,
      ),
    );
    if (result == null || !mounted) return;
    _applyQuickAdd(result);
  }

  void _applyQuickAdd(_QuickAddResult r) {
    final base = _measurements.isEmpty ? null : _measurements.last;
    _rebuild(() {
      for (var n = 0; n < r.count; n++) {
        final item = _buildMeasurement(like: base);
        item.name.text = 'شباك ${_toArabic(_measurements.length + 1)}';
        item.width.text = r.width.toStringAsFixed(2);
        item.height.text = r.height.toStringAsFixed(2);
        item.method = r.method;
        item.ceiling = r.ceiling;
        _measurements.add(item);
      }
    });
    _triggerAutoSave();
    _scrollToEnd(_aptScroll);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تمت إضافة ${_toArabic(r.count)} مقاسات — اضغط على أي كارت لتعديل عرضه',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet({
    required this.initialWidth,
    required this.initialHeight,
    required this.initialMethod,
    required this.initialCeiling,
  });

  final double initialWidth;
  final double initialHeight;
  final _WorkMethod initialMethod;
  final _CeilingType initialCeiling;

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  int _count = 10;
  late double _width = widget.initialWidth <= 0 ? 3.00 : widget.initialWidth;
  late double _height = widget.initialHeight <= 0 ? 2.95 : widget.initialHeight;
  late _WorkMethod _method = widget.initialMethod;
  late _CeilingType _ceiling = widget.initialCeiling;

  void _bumpWidth(double d) {
    setState(() => _width = (_width + d).clamp(0.1, 20.0).toDouble());
  }

  void _bumpHeight(double d) {
    setState(() => _height = (_height + d).clamp(0.1, 20.0).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(top: 44),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _line)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppPalette.isDark ? 0.35 : 0.10,
              ),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // مقبض السحب
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // العنوان
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.playlist_add_rounded,
                          color: _gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إضافة سريعة',
                              style: TextStyle(
                                color: AppPalette.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'ضيف كذا مقاس بسرعة بنفس الإعدادات',
                              style: TextStyle(color: _muted, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: _muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // عدد المقاسات
                  _label('عدد المقاسات'),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final n in const [3, 5, 10, 15, 20])
                        _choiceChip(
                          label: _toArabic(n),
                          on: _count == n,
                          onTap: () => setState(() => _count = n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // العرض والارتفاع
                  Row(
                    children: [
                      Expanded(
                        child: _numberBox(
                          label: 'العرض الافتراضي',
                          value: _width,
                          onMinus: () => _bumpWidth(-0.05),
                          onPlus: () => _bumpWidth(0.05),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numberBox(
                          label: 'الارتفاع',
                          value: _height,
                          onMinus: () => _bumpHeight(-0.05),
                          onPlus: () => _bumpHeight(0.05),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // الطراز
                  _label('طريقة التعليق'),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in _WorkMethod.values)
                        _choiceChip(
                          label: m.label,
                          on: _method == m,
                          onTap: () => setState(() => _method = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // السقف
                  _label('نوع السقف'),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _CeilingType.values)
                        _choiceChip(
                          label: c.label,
                          on: _ceiling == c,
                          onTap: () => setState(() => _ceiling = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ملخص
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: _gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هيتضاف ${_toArabic(_count)} مقاسات «${_method.label}» بارتفاع ${_fmtAr(_height)} م، وتقدر تعدّل عرض كل واحد بعد كده.',
                            style: TextStyle(
                              color: AppPalette.textSoft,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // زر الإضافة
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(
                        _QuickAddResult(
                          count: _count,
                          width: _width,
                          height: _height,
                          method: _method,
                          ceiling: _ceiling,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _bg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.playlist_add_rounded, size: 21),
                      label: Text(
                        'إضافة ${_toArabic(_count)} مقاسات',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _muted,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool on,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? _gold : _bg.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? _gold : _line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? _bg : AppPalette.text,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _numberBox({
    required String label,
    required double value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _stepBtn(Icons.remove_rounded, onMinus),
              Expanded(
                child: Center(
                  child: Text(
                    '${_fmtAr(value)} م',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              _stepBtn(Icons.add_rounded, onPlus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _line),
        ),
        child: Icon(icon, size: 18, color: _gold),
      ),
    );
  }
}
