part of 'invoice_page.dart';

// ديالوج التعديل السريع الذكي
extension _InvoiceQuickEdit on _InvoicePageState {
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
      backgroundColor: const Color(0xFF1E293B),
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
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFC5A059)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _arNum(controller.text),
                            style: const TextStyle(
                              color: Color(0xFFC5A059),
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
                        fillColor: const Color(0xFF0F172A),
                        hintText: 'أو اكتب القيمة مباشرة',
                        hintStyle: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF334155),
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
                              backgroundColor: const Color(0xFFC5A059),
                              foregroundColor: const Color(0xFF0F172A),
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
              ? const Color(0xFFC5A059).withValues(alpha: 0.18)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPositive
                ? const Color(0xFFC5A059)
                : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isPositive ? const Color(0xFFC5A059) : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ============================ سجل الدفعات ============================
}
