part of '../paris_client_measurements_page.dart';

extension _MeasurementEditPanel on _ParisClientMeasurementsPageState {
  // لوحة التعديل: بتنزل تحت الكارت المكبّر
  Widget _editPanel(_Measurement item) {
    final calc = item.calculation;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF07080D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _gold.withValues(alpha: 0.35),
                  width: 1.15,
                ),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    // الصف الأول: اسم الغرفة والعرض والارتفاع
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: item.name,
                            onChanged: (_) {
                              _rebuild(() {});
                              _triggerAutoSave();
                            },
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                              labelText: 'اسم الغرفة',
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: item.width,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) {
                              _rebuild(() {});
                              _triggerAutoSave();
                            },
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                              labelText: 'العرض (م)',
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: item.height,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) {
                              _rebuild(() {});
                              _triggerAutoSave();
                            },
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                              labelText: 'الارتفاع (م)',
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // الصف الثاني: طراز الشغل ونوع السقف بشكل مريح
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<_WorkMethod>(
                            initialValue: item.method,
                            isDense: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                              labelText: 'طراز الشغل',
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                            dropdownColor: _panel,
                            items: _WorkMethod.values
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      v.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                _rebuild(() => item.method = val);
                                _triggerAutoSave();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonFormField<_CeilingType>(
                            initialValue: item.ceiling,
                            isDense: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                              labelText: 'نوع السقف',
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                            dropdownColor: _panel,
                            items: _CeilingType.values
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      v.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                _rebuild(() => item.ceiling = val);
                                _triggerAutoSave();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // عدد العجل: تلقائي من جدول المقاس، أو يدوي لو كتبت رقم
                    if (item.method != _WorkMethod.press) ...[
                      TextField(
                        controller: item.wheels,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'عدد العجل (فاضي = حساب تلقائي)',
                          hintText: 'تلقائي: ${calc.heavyWheelsLabel}',
                          helperText:
                              'قماش العجل ${_fmtAr(calc.wheelsFabricMeters)} م (العجل × 0.148)',
                          helperStyle: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFFFFD45A),
                          ),
                          labelStyle: const TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                          border: const OutlineInputBorder(),
                          suffixIcon: item.wheels.text.trim().isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'رجوع للحساب التلقائي',
                                  icon: const Icon(Icons.refresh, size: 18),
                                  onPressed: () {
                                    item.wheels.clear();
                                    _rebuild(() {});
                                    _triggerAutoSave();
                                  },
                                ),
                        ),
                        onChanged: (_) {
                          _rebuild(() {});
                          _triggerAutoSave();
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    // الصف الثالث: تحديد الأجناب والستارة الخفيفة بدون أي اختناق أو تجاوز بكسلات
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'أجناب قطيفة:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text(
                                  '١ جنب',
                                  style: TextStyle(fontSize: 10.5),
                                ),
                                selected: item.velvetSides == 1,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                onSelected: (_) {
                                  _rebuild(() => item.velvetSides = 1);
                                  _triggerAutoSave();
                                },
                              ),
                              const SizedBox(width: 4),
                              ChoiceChip(
                                label: const Text(
                                  '٢ جنب',
                                  style: TextStyle(fontSize: 10.5),
                                ),
                                selected: item.velvetSides == 2,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                onSelected: (_) {
                                  _rebuild(() => item.velvetSides = 2);
                                  _triggerAutoSave();
                                },
                              ),
                            ],
                          ),
                        ),

                        InkWell(
                          onTap: () {
                            _rebuild(
                              () => item.lightLayers = item.lightLayers > 0
                                  ? 0
                                  : 1,
                            );
                            _triggerAutoSave();
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: item.lightLayers > 0
                                  ? const Color(0x228AE9C1)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.lightLayers > 0
                                    ? const Color(0xFF8AE9C1)
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.lightLayers > 0
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 16,
                                  color: item.lightLayers > 0
                                      ? const Color(0xFF8AE9C1)
                                      : Colors.white38,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'ستارة خفيفة (كتان)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: item.lightLayers > 0
                                        ? const Color(0xFF8AE9C1)
                                        : Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (item.lightLayers > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'أجناب الخفيف:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                for (final n in const [1, 2]) ...[
                                  ChoiceChip(
                                    label: Text(
                                      '${_toArabic(n)} جنب',
                                      style: const TextStyle(fontSize: 10.5),
                                    ),
                                    selected: item.lightSides == n,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    onSelected: (_) {
                                      _rebuild(() => item.lightSides = n);
                                      _triggerAutoSave();
                                    },
                                  ),
                                  if (n == 1) const SizedBox(width: 4),
                                ],
                              ],
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () {
                            _closeCard();
                            Future.delayed(const Duration(milliseconds: 900), () {
                              if (mounted) _duplicateMeasurement(item);
                            });
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text(
                            'تكرار الكارت',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _neon,
                            side: const BorderSide(color: Colors.white24),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
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
