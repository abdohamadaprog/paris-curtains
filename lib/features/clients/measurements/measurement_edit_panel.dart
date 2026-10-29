part of 'paris_client_measurements_page.dart';

extension _MeasurementEditPanel on _ParisClientMeasurementsPageState {
  // لوحة التعديل: بتنزل تحت الكارت المكبّر
  // أزرار + و− للعرض والارتفاع، واختيارات بضغطة واحدة بدل القوايم المنسدلة.
  Widget _editPanel(_Measurement item) {
    final calc = item.calculation;

    void changed(VoidCallback fn) {
      _rebuild(fn);
      _triggerAutoSave();
    }

    InputDecoration fieldDeco({String? label, String? hint, Widget? suffix}) {
      return InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _bg,
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 12, color: _muted),
        hintStyle: const TextStyle(fontSize: 12, color: _muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _gold, width: 1.4),
        ),
      );
    }

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: _muted,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    // + / − بخطوة ٠٫٠٥ والرقم نفسه ينفع تكتبه بالكيبورد
    Widget stepper(String label, TextEditingController c) {
      void bump(double delta) {
        final cur = _Measurement.toDouble(c.text);
        final next = (((cur + delta) * 100).round() / 100)
            .clamp(0.0, 99.0)
            .toDouble();
        c.text = next.toStringAsFixed(2);
        changed(() {});
      }

      Widget btn(IconData icon, double delta) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => bump(delta),
        child: Container(
          width: 36,
          height: 46,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _line),
          ),
          child: Icon(icon, color: _gold, size: 20),
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(label),
          Row(
            children: [
              btn(Icons.add_rounded, 0.05),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: c,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  onChanged: (_) => changed(() {}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: fieldDeco(),
                ),
              ),
              const SizedBox(width: 4),
              btn(Icons.remove_rounded, -0.05),
            ],
          ),
        ],
      );
    }

    // اختيار بضغطة واحدة (شرايح بدل القوايم المنسدلة)
    Widget segmented<T>({
      required List<T> values,
      required T selected,
      required String Function(T) label,
      required ValueChanged<T> onChanged,
    }) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            for (final v in values)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == selected ? _gold : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      label(v),
                      style: TextStyle(
                        color: v == selected ? _bg : _muted,
                        fontWeight: v == selected
                            ? FontWeight.w900
                            : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final lightValue = item.lightLayers > 0 ? item.lightSides : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sectionLabel('اسم الغرفة'),
            TextField(
              controller: item.name,
              onChanged: (_) => changed(() {}),
              style: const TextStyle(
                color: _gold,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
              decoration: fieldDeco(hint: 'مثال: الصالون'),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: stepper('العرض (م)', item.width)),
                const SizedBox(width: 10),
                Expanded(child: stepper('الارتفاع (م)', item.height)),
              ],
            ),

            sectionLabel('طراز الشغل'),
            segmented<_WorkMethod>(
              values: _WorkMethod.values,
              selected: item.method,
              label: (v) => v.label,
              onChanged: (v) => changed(() => item.method = v),
            ),

            sectionLabel('نوع السقف'),
            segmented<_CeilingType>(
              values: _CeilingType.values,
              selected: item.ceiling,
              label: (v) => v.label,
              onChanged: (v) => changed(() => item.ceiling = v),
            ),

            sectionLabel('القطيفة (الستارة التقيلة)'),
            segmented<int>(
              values: const [1, 2],
              selected: item.velvetSides,
              label: (v) => '${_toArabic(v)} جنب',
              onChanged: (v) => changed(() => item.velvetSides = v),
            ),

            sectionLabel('الكتان (الستارة الخفيفة)'),
            segmented<int>(
              values: const [0, 1, 2],
              selected: lightValue,
              label: (v) => v == 0 ? 'بدون' : '${_toArabic(v)} جنب',
              onChanged: (v) => changed(() {
                if (v == 0) {
                  item.lightLayers = 0;
                } else {
                  item.lightLayers = 1;
                  item.lightSides = v;
                }
              }),
            ),

            // عدد العجل: تلقائي من جدول المقاس، أو يدوي لو كتبت رقم
            if (item.method != _WorkMethod.press) ...[
              sectionLabel('عدد العجل (فاضي = حساب تلقائي)'),
              TextField(
                controller: item.wheels,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onChanged: (_) => changed(() {}),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
                decoration: fieldDeco(
                  hint: 'تلقائي: ${calc.heavyWheelsLabel}',
                  suffix: item.wheels.text.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'رجوع للحساب التلقائي',
                          icon: const Icon(Icons.refresh, size: 18, color: _gold),
                          onPressed: () {
                            item.wheels.clear();
                            changed(() {});
                          },
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 2),
                child: Text(
                  'قماش العجل ${_fmtAr(calc.wheelsFabricMeters)} م (العجل × 0.148)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFFFD45A),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                _closeCard();
                Future.delayed(const Duration(milliseconds: 900), () {
                  if (mounted) _duplicateMeasurement(item);
                });
              },
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: const Text(
                'تكرار المقاس',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: BorderSide(color: _gold.withValues(alpha: 0.5)),
                minimumSize: const Size(0, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // قائمة منبثقة سريعة بلمسة واحدة للاختيار المباشر
  // ============================================================================
  Widget _quickSelectMenu<T>({
    required String label,
    required String icon,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T> onSelected,
    TextDecoration? cardDecoration,
    Color? cardDecorColor,
  }) {
    return PopupMenuButton<T>(
      tooltip: 'تغيير سريع',
      color: _panel,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _gold.withValues(alpha: 0.3)),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => items
          .map(
            (e) => PopupMenuItem<T>(
              value: e,
              height: 38,
              child: Text(
                itemLabel(e),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFF163820),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: const Color(0xFF28A745).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✅ $icon ', style: const TextStyle(fontSize: 11)),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF98E2A8),
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                decoration: cardDecoration,
                decorationColor: cardDecorColor,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF98E2A8),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
