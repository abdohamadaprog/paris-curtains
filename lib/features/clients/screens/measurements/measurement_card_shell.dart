part of '../paris_client_measurements_page.dart';

extension _MeasurementCardShell on _ParisClientMeasurementsPageState {
  Widget _cardShell(
    _Measurement item,
    int index, {
    required double zoom,
    required double reveal,
    required bool popup,
    bool bare = false,
  }) {
    final k = ((zoom - _compactZoom) / (1 - _compactZoom)).clamp(0.0, 1.0);
    final double gap = 0.5 + 3 * k;
    final double pv = 2.5 + 4.5 * k;
    final double pb = 2.5 * k;
    final double btnH = 22 + 6 * k;

    final calc = item.calculation;
    final disabled = !item.enabled;
    final wVal = _Measurement.toDouble(item.width.text);
    final hVal = _Measurement.toDouble(item.height.text);

    // ستايل الشطب على كامل نصوص الكارت عند التعطيل
    final cardDecoration = disabled ? TextDecoration.lineThrough : null;
    final cardDecorColor = disabled
        ? Colors.redAccent.withValues(alpha: 0.8)
        : null;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(zoom)),
      child: DefaultTextStyle.merge(
      style: TextStyle(height: 1.05 + 0.3 * k),
      child: Container(
      decoration: bare
          ? null
          : BoxDecoration(
        color: const Color(0xFF0C0E14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: disabled ? Colors.white24 : _gold.withValues(alpha: 0.4),
          width: 1.15,
        ),
        boxShadow: disabled
            ? const []
            : [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.09),
                  blurRadius: 7,
                  spreadRadius: 0.3,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // النقر المتكرر (3 نقرات) يكرر الكارت، والنقر الفردي يفتح التعديل
          InkWell(
            onTap: () => popup ? _closeCard() : _openCard(item),
            borderRadius: BorderRadius.circular(10),
            child: Opacity(
              opacity: disabled ? 0.45 : 1.0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: pv),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ========================================================
                      // السطر 1: [صح] [اسم المقاس في مكانه المميز] [أدوات]
                      // ========================================================
                      Row(
                        children: [
                          // زر التفعيل / التعطيل السريع (يشطب كامل الكلام)
                          InkWell(
                            onTap: () {
                              _rebuild(() => item.enabled = !item.enabled);
                              _triggerAutoSave();
                            },
                            child: Icon(
                              item.enabled
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked,
                              color: item.enabled ? _gold : Colors.white30,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // اسم المقاس في مكانه المميز مع أيقونات باريس
                          Expanded(
                            child: Row(
                              children: [
                                const Text(
                                  '🌟',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.name.text.isEmpty
                                        ? 'مقاس بدون اسم'
                                        : item.name.text,
                                    style: TextStyle(
                                      color: disabled ? Colors.white54 : _gold,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      decoration: cardDecoration,
                                      decorationColor: cardDecorColor,
                                      decorationThickness: 2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '🌟 🪟',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                          // أدوات سريعة
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: BoxConstraints.tightFor(width: 28, height: btnH),
                            padding: EdgeInsets.zero,
                            tooltip: popup ? 'طي التعديل' : 'تعديل تفصيلي',
                            icon: Icon(
                              popup ? Icons.keyboard_arrow_up : Icons.edit_note_rounded,
                              color: _neon,
                              size: 21,
                            ),
                            onPressed: () => popup ? _closeCard() : _openCard(item),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: BoxConstraints.tightFor(width: 26, height: btnH),
                            padding: EdgeInsets.zero,
                            tooltip: 'حذف المقاس',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            onPressed: () {
                              if (popup) {
                                final i = _measurements.indexOf(item);
                                _rebuild(() {
                                  _expandedId = null;
                                  _closing = false;
                                });
                                if (i >= 0) _deleteMeasurement(i);
                              } else {
                                _deleteMeasurement(index);
                              }
                            },
                          ),
                          popup
                              ? const SizedBox(width: 22)
                              : ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(
                                Icons.drag_indicator,
                                color: Colors.white38,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: gap),

                      // ========================================================
                      // السطر 2: [بند المقاس يمين] ⬅️⬅️ [٦ متر ثقيل + ٤ متر خفيف]
                      // ========================================================
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // بند المقاس على اليمين في بادج بارز
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 7, vertical: pb),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '📌',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _toArabic(
                                      item.width.text.trim().isNotEmpty
                                          ? item.width.text.trim()
                                          : _fmt(wVal),
                                    ),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15.5,
                                      decoration: cardDecoration,
                                      decorationColor: cardDecorColor,
                                    ),
                                  ),
                                  const Text(
                                    ' م',
                                    style: TextStyle(
                                      color: _neon,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '📌',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 6),

                            // إيموشن السهم مرتين يوضح اتجاه الكلام
                            const Text('⬅️⬅️', style: TextStyle(fontSize: 13)),

                            const SizedBox(width: 6),

                            // كتابة (٦ متر ثقيل + ٤ متر خفيف) بالخط الواضح الصريح
                            Text(
                              '${_fmtAr(calc.heavyMeters)} متر ثقيل',
                              style: TextStyle(
                                color: const Color(0xFFFFD45A),
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                decoration: cardDecoration,
                                decorationColor: cardDecorColor,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Text(
                                '+',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${_fmtAr(calc.lightMeters)} متر خفيف',
                              style: TextStyle(
                                color: const Color(0xFF70D6FF),
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                decoration: cardDecoration,
                                decorationColor: cardDecorColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: gap),

                      // ========================================================
                      // السطر 3: [الارتفاع كذا م] + [اختيار الويفي بسهولة] + [اختيار كابولي بسهولة]
                      // ========================================================
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // نص الارتفاع بترتيب عربي صحيح (الكلمة أولاً ثم الرقم)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: pb),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '📩 ',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    'الارتفاع ${_toArabic(item.height.text.trim().isNotEmpty ? item.height.text.trim() : _fmt(hVal))} م',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      decoration: cardDecoration,
                                      decorationColor: cardDecorColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 6),

                            // اختيار طراز الويفي / كبس / دابل ويفي بلمسة واحدة سهلة
                            _quickSelectMenu<_WorkMethod>(
                              label: item.method.label,
                              icon: '🪟',
                              items: _WorkMethod.values,
                              itemLabel: (v) => v.label,
                              onSelected: (val) {
                                _rebuild(() => item.method = val);
                                _triggerAutoSave();
                              },
                              cardDecoration: cardDecoration,
                              cardDecorColor: cardDecorColor,
                            ),

                            const SizedBox(width: 6),

                            // اختيار نوع السقف (كابولي / بيت ستارة) بلمسة واحدة سهلة
                            _quickSelectMenu<_CeilingType>(
                              label: item.ceiling.label,
                              icon: '🏠',
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

                      SizedBox(height: gap),

                      // ========================================================
                      // السطر 4: خياطة ثقيل كذا م • خياطة خفيف كذا م (بالتفصيل والتنسيق العربي السليم)
                      // ========================================================
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: pb),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.2),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🪡', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                'خياطة ثقيل ${_fmtAr(calc.heavyHeight)} م',
                                style: TextStyle(
                                  color: const Color(0xFFFFE082),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: cardDecoration,
                                  decorationColor: cardDecorColor,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '•',
                                  style: TextStyle(
                                    color: _gold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Text('🪡', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                'خياطة خفيف ${_fmtAr(calc.lightHeight)} م',
                                style: TextStyle(
                                  color: const Color(0xFF8AE9C1),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: cardDecoration,
                                  decorationColor: cardDecorColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: gap),

                      // ========================================================
                      // السطر 5: نظام الخياطة (الأجناب) والعجل والشريط مدمجين في سطر واحد
                      // ========================================================
                      Container(
                        padding: EdgeInsets.symmetric(vertical: pb),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 0,
                          children: [
                            // نظام الخياطة والأجناب
                            Text(
                              '${_toArabic(item.velvetSides)} ج قطيفة "${item.method.label}" + ${item.lightLayers > 0 ? '${_toArabic(item.lightSides)} ج كتان خفيف' : "بدون خفيف"}',
                              style: TextStyle(
                                color: const Color(0xFFF1E6D2),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                decoration: cardDecoration,
                                decorationColor: cardDecorColor,
                              ),
                            ),

                            if (item.method != _WorkMethod.press) ...[
                            const Text(
                              '•',
                              style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // العجل والشريط
                            Text(
                              '${calc.heavyWheelsLabel} + ${_toArabic(calc.lightWheels)} عجلة = ${_fmtAr(calc.wheelsFabricMeters)} م قماش • شريط ${_fmtAr(calc.heavyTapeMeters)} م + ${_fmtAr(calc.lightTapeMeters)} م',
                              style: TextStyle(
                                color: const Color(0xFFFFD45A),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                decoration: cardDecoration,
                                decorationColor: cardDecorColor,
                              ),
                            ),

                            ],
                            const Text('✅ 📌', style: TextStyle(fontSize: 11)),
                          ],
                        )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ====================================================================
          // لوحة التعديل التفصيلي المنسدلة (تفتح اختيارياً عند الرغبة في تعديل المقاسات يدوياً)
          // ====================================================================
        ],
      ),
    )));
  }
}
