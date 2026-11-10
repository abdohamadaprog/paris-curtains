part of 'paris_client_measurements_page.dart';

extension _MeasurementCardShell on _ParisClientMeasurementsPageState {
  // ============================================================================
  // كارت المقاس (النسخة المدمجة الأصلية) — بيتظبط عشان يبان تقريبًا ٥ كروت
  // على الشاشة الواحدة:
  //   • سطر ١: تفعيل + اسم المقاس + شارة الاستثناء + أدوات.
  //   • سطر ٢: بادج المقاس (العرض) + حبّات القماش (ثقيل/خفيف/بلاك أوت).
  //   • سطر ٣: الارتفاع + تغيير الطراز/السقف بلمسة.
  //   • سطر ٤: الخياطة (ثقيل/خفيف).
  //   • سطر ٥: الأجناب + العجل/الشريط.
  // ============================================================================
  Widget _cardShell(
    _Measurement item,
    int index, {
    required double zoom,
    required double reveal,
    required bool popup,
    bool bare = false,
  }) {
    final k = ((zoom - _compactZoom) / (1 - _compactZoom)).clamp(0.0, 1.0);
    final double gap = 0.25 + 3 * k;
    final double pv = 2.0 + 5 * k;
    final double pb = 2.5 * k;
    final double btnH = 22 + 6 * k;
    // نحترم حجم خط النظام مع حد أدنى مقروء وحد أقصى يمنع تضخّم الكارت.
    final systemScale = MediaQuery.textScalerOf(context).scale(1.0);
    final textScale = (zoom * systemScale).clamp(0.90, 1.20).toDouble();

    final calc = item.calculation;
    final wheelsLine = _wheelsLine(item, calc);
    final sewing = _sewingLine(item, calc);
    final disabled = !item.enabled;
    final wVal = _Measurement.toDouble(item.width.text);
    final hVal = _Measurement.toDouble(item.height.text);

    // ستايل الشطب على كامل نصوص الكارت عند التعطيل
    final cardDecoration = disabled ? TextDecoration.lineThrough : null;
    final cardDecorColor = disabled
        ? AppPalette.redStrong.withValues(alpha: 0.8)
        : null;

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: DefaultTextStyle.merge(
        style: TextStyle(height: 1.15 + 0.2 * k),
        child: Container(
          decoration: bare
              ? null
              : BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: AppPalette.isDark
                        ? const [Color(0xFF25344A), Color(0xFF1A2434)]
                        : const [Color(0xFFFFFFFF), Color(0xFFFDFAF4)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                    top: BorderSide(
                      color: disabled ? _line : _gold.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                    left: BorderSide(
                      color: disabled
                          ? _line.withValues(alpha: 0.7)
                          : _gold.withValues(alpha: 0.18),
                    ),
                    right: BorderSide(
                      color: disabled
                          ? _line.withValues(alpha: 0.7)
                          : _gold.withValues(alpha: 0.18),
                    ),
                    bottom: BorderSide(
                      color: disabled
                          ? _line.withValues(alpha: 0.7)
                          : _gold.withValues(alpha: 0.18),
                    ),
                  ),
                  boxShadow: disabled
                      ? const []
                      : [
                          BoxShadow(
                            color: AppPalette.isDark
                                ? Colors.black.withValues(alpha: 0.20)
                                : _gold.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
          child: InkWell(
            onTap: () => _openCard(item),
            borderRadius: BorderRadius.circular(16),
            child: Opacity(
              opacity: disabled ? 0.5 : 1.0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: pv),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ========================================================
                      // السطر ١: [تفعيل] [اسم المقاس] [شارة استثناء] [أدوات]
                      // ========================================================
                      Row(
                        children: [
                          // زر التفعيل / التعطيل السريع
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              _rebuild(() => item.enabled = !item.enabled);
                              _triggerAutoSave();
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item.enabled
                                    ? _gold.withValues(alpha: 0.14)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: item.enabled
                                      ? _gold.withValues(alpha: 0.40)
                                      : _line,
                                ),
                              ),
                              child: Icon(
                                item.enabled
                                    ? Icons.check_rounded
                                    : Icons.circle_outlined,
                                color: item.enabled
                                    ? _gold
                                    : AppPalette.text.withValues(alpha: 0.30),
                                size: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // اسم المقاس
                          Expanded(
                            child: Row(
                              children: [
                                const Text(
                                  '🌟',
                                  style: TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.name.text.trim().isEmpty
                                        ? 'مقاس بدون اسم'
                                        : item.name.text.trim(),
                                    style: TextStyle(
                                      color: disabled
                                          ? AppPalette.text.withValues(
                                              alpha: 0.54,
                                            )
                                          : (AppPalette.isDark
                                                ? AppPalette.goldLight
                                                : _gold),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      decoration: cardDecoration,
                                      decorationColor: cardDecorColor,
                                      decorationThickness: 2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.hasException) ...[
                                  const SizedBox(width: 5),
                                  Tooltip(
                                    message: item.exceptionSummary,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppPalette.violet.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: AppPalette.violet.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'استثناء',
                                        style: TextStyle(
                                          color: AppPalette.violet,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // أدوات سريعة
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: BoxConstraints.tightFor(
                              width: 28,
                              height: btnH,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: popup ? 'طي التعديل' : 'تعديل تفصيلي',
                            icon: Icon(
                              popup
                                  ? Icons.keyboard_arrow_up
                                  : Icons.edit_note_rounded,
                              color: _neon,
                              size: 21,
                            ),
                            onPressed: () => _openCard(item),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: BoxConstraints.tightFor(
                              width: 26,
                              height: btnH,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'حذف المقاس',
                            icon: Icon(
                              Icons.delete_outline,
                              color: AppPalette.redStrong,
                              size: 18,
                            ),
                            onPressed: () => _deleteMeasurement(index),
                          ),
                          popup
                              ? const SizedBox(width: 22)
                              : ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: Icon(
                                      Icons.drag_indicator,
                                      color: AppPalette.text.withValues(
                                        alpha: 0.38,
                                      ),
                                      size: 20,
                                    ),
                                  ),
                                ),
                        ],
                      ),

                      SizedBox(height: gap),

                      // ========================================================
                      // السطر ٢: [المقاس] ⬅️ [أمتار القماش]
                      // ========================================================
                      Row(
                        children: [
                          // بادج المقاس (العرض)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: pb + 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: [
                                  _gold.withValues(alpha: 0.20),
                                  _gold.withValues(alpha: 0.07),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _gold.withValues(alpha: 0.38),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '📌',
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _toArabic(
                                    item.width.text.trim().isNotEmpty
                                        ? item.width.text.trim()
                                        : _fmt(wVal),
                                  ),
                                  style: TextStyle(
                                    color: AppPalette.text,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 25,
                                    height: 1.05,
                                    decoration: cardDecoration,
                                    decorationColor: cardDecorColor,
                                  ),
                                ),
                                Text(
                                  ' م',
                                  style: TextStyle(
                                    color: _neon,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.5,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Text(
                                  '📌',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 6),

                          Expanded(
                            child: Wrap(
                              alignment: WrapAlignment.start,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 0,
                              runSpacing: 2,
                              children: [
                                const Text(
                                  '⬅️',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 5),
                                ..._fabricPills(
                                  item,
                                  calc,
                                  pb,
                                  cardDecoration,
                                  cardDecorColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: gap),

                      // ========================================================
                      // السطر ٣: [الارتفاع] + [الطراز] + [السقف]
                      // ========================================================
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 5,
                          runSpacing: 2,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: pb,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.insetAlt,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: _line.withValues(alpha: 0.85),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '📩 ',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'ارتفاع ${_toArabic(item.height.text.trim().isNotEmpty ? item.height.text.trim() : _fmt(hVal))} م',
                                    style: TextStyle(
                                      color: AppPalette.text,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      decoration: cardDecoration,
                                      decorationColor: cardDecorColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _quickSelectMenu<_WorkMethod>(
                              label: item.method.label,
                              icon: _methodIcon(item.method),
                              color: _gold,
                              items: _WorkMethod.values,
                              itemLabel: (v) => v.label,
                              onSelected: (val) {
                                _rebuild(() => item.method = val);
                                _triggerAutoSave();
                              },
                              cardDecoration: cardDecoration,
                              cardDecorColor: cardDecorColor,
                            ),
                            _quickSelectMenu<_CeilingType>(
                              label: item.ceiling.label,
                              icon: Icons.home_rounded,
                              color: _muted,
                              items: _CeilingType.values,
                              itemLabel: (v) => v.label,
                              onSelected: (val) {
                                _rebuild(() => item.ceiling = val);
                                _triggerAutoSave();
                              },
                              cardDecoration: cardDecoration,
                              cardDecorColor: cardDecorColor,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: gap + 1),
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _gold.withValues(alpha: 0.0),
                              _gold.withValues(alpha: 0.22),
                              _gold.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: gap + 1),

                      // ========================================================
                      // السطر ٤: خياطة ثقيل / خفيف
                      // ========================================================
                      if (sewing != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: pb,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _gold.withValues(alpha: 0.16),
                            ),
                          ),
                          child: sewing,
                        ),

                      SizedBox(height: gap),

                      // ========================================================
                      // السطر ٥: الأجناب + العجل/الشريط
                      // ========================================================
                      Container(
                        padding: EdgeInsets.symmetric(vertical: pb),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                _sidesLine(item),
                                style: TextStyle(
                                  color: AppPalette.cream,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  decoration: cardDecoration,
                                  decorationColor: cardDecorColor,
                                ),
                              ),
                              if (item.method != _WorkMethod.press &&
                                  wheelsLine.isNotEmpty) ...[
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: AppPalette.text.withValues(
                                      alpha: 0.54,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  wheelsLine,
                                  style: TextStyle(
                                    color: AppPalette.amber,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    decoration: cardDecoration,
                                    decorationColor: cardDecorColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _methodIcon(_WorkMethod method) {
    if (method == _WorkMethod.wave) return Icons.waves_rounded;
    if (method == _WorkMethod.doubleWave) return Icons.layers_rounded;
    return Icons.compress_rounded;
  }

  /// سطر الخياطة (ثقيل/خفيف) — بيرجع null لو مفيش طبقات شغّالة.
  Widget? _sewingLine(_Measurement item, _Calculation calc) {
    final parts = <Widget>[];
    if (item.heavyEnabled) {
      parts.add(
        Text(
          '🪡 خياطة ثقيل ${_fmtAr(calc.heavyHeight)} م',
          style: TextStyle(
            color: AppPalette.amberSoft,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }
    if (item.lightLayers > 0) {
      if (parts.isNotEmpty) {
        parts.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '•',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      }
      parts.add(
        Text(
          '🪡 خياطة خفيف ${_fmtAr(calc.lightHeight)} م',
          style: TextStyle(
            color: AppPalette.mint,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }
    if (parts.isEmpty) return null;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: parts,
    );
  }

  /// سطر الأجناب: قطيفة/كتان/بلاك أوت.
  String _sidesLine(_Measurement item) {
    final heavy = item.heavyEnabled
        ? '${_toArabic(item.velvetSides)} قطيفة'
        : 'بدون قطيفة';
    final light = item.lightLayers > 0
        ? '${_toArabic(item.lightSides)} كتان خفيف'
        : 'بدون خفيف';
    final blackout = item.blackoutEnabled ? ' + بلاك أوت' : '';
    return '$heavy + $light$blackout';
  }

  /// سطر العجل والشريط: بيتغيّر لو الثقيل متلغي أو مفيش خفيف.
  String _wheelsLine(_Measurement item, _Calculation calc) {
    final h = item.heavyEnabled;
    final l = item.lightLayers > 0;
    if (!h && !l) return '';

    final wheels = (h && l)
        ? '${calc.heavyWheelsLabel} + ${_toArabic(calc.lightWheels)} عجلة'
        : h
        ? '${calc.heavyWheelsLabel} عجلة'
        : '${_toArabic(calc.lightWheels)} عجلة';
    final tape = (h && l)
        ? 'شريط ${_fmtAr(calc.heavyTapeMeters)} م + ${_fmtAr(calc.lightTapeMeters)} م'
        : h
        ? 'شريط ${_fmtAr(calc.heavyTapeMeters)} م'
        : 'شريط ${_fmtAr(calc.lightTapeMeters)} م';
    return '$wheels = ${_fmtAr(calc.wheelsFabricMeters)} م • $tape';
  }

  /// حبّات القماش الظاهرة على الكارت (ثقيل / خفيف / بلاك أوت)
  List<Widget> _fabricPills(
    _Measurement item,
    _Calculation calc,
    double pb,
    TextDecoration? decoration,
    Color? decorationColor,
  ) {
    final pills = <Widget>[];

    void add(String text, Color color) {
      if (pills.isNotEmpty) {
        pills.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '+',
              style: TextStyle(
                color: AppPalette.text.withValues(alpha: 0.54),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        );
      }
      pills.add(_meterPill(text, color, pb, decoration, decorationColor));
    }

    if (item.heavyEnabled) {
      add('${_fmtAr(calc.heavyMeters)} م ثقيل', AppPalette.amber);
    }
    if (item.lightLayers > 0) {
      add('${_fmtAr(calc.lightMeters)} م خفيف', AppPalette.skyLight);
    }
    if (item.blackoutEnabled) {
      add('${_fmtAr(calc.blackoutMeters)} م بلاك أوت', AppPalette.violet);
    }
    return pills;
  }

  /// حبّة ملوّنة لعدد الأمتار (ثقيل / خفيف / بلاك أوت)
  Widget _meterPill(
    String text,
    Color color,
    double pb,
    TextDecoration? decoration,
    Color? decorationColor,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 1 + pb),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 14,
          decoration: decoration,
          decorationColor: decorationColor,
        ),
      ),
    );
  }
}
