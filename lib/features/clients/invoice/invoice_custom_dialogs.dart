part of 'invoice_page.dart';

// بند مخصص + أسعار الفاتورة + صفحة ثوابت الحساب
extension _InvoiceCustomDialogs on _InvoicePageState {
  void _openAddCustomLineDialog({required bool isBalcony}) {
    final labelCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'قطعة');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isBalcony
                  ? 'إضافة بند لفاتورة البلكونة'
                  : 'إضافة بند لفاتورة الشقة',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'اسم البند',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'الكمية',
                            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: unitCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'الوحدة (متر/قطعة..)',
                            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'سعر الوحدة (ج.م)',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final label = labelCtrl.text.trim();
                  if (label.isEmpty) return;
                  final q = _safeNum(qtyCtrl.text);
                  final p = _safeNum(priceCtrl.text);
                  final key = 'custom_${DateTime.now().millisecondsSinceEpoch}';

                  final line = InvoiceLine(
                    key: key,
                    label: label,
                    unit: unitCtrl.text.trim(),
                    qty: q <= 0 ? 1 : q,
                    unitPrice: p,
                    manual: true,
                  );

                  _rebuild(() {
                    if (isBalcony) {
                      _balcCustomLines.add(line);
                    } else {
                      _aptCustomLines.add(line);
                    }
                  });
                  _scheduleAutoSave();

                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A059),
                  foregroundColor: const Color(0xFF0F172A),
                ),
                child: const Text(
                  'إضافة البند',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================ صفحة ثوابت الحساب (الأسعار العامة) ============================

  Future<void> _openGlobalPrices() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PriceSettingsPage()),
    );
    if (changed == true && mounted) _rebuild(() {});
  }

  // ============================ ديالوج الأسعار الافتراضية ============================

  void _openPriceSettings() {
    final localCopy = Map<String, double>.from(defaultPrices())
      ..addAll(_customPrices);

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
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.75,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF475569),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Icons.tune_rounded, color: Color(0xFFC5A059)),
                        SizedBox(width: 8),
                        Text(
                          'تعديل قائمة الأسعار الافتراضية',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: kPriceDefs.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: Color(0xFF334155), height: 1),
                        itemBuilder: (_, i) {
                          final def = kPriceDefs[i];
                          final current = localCopy[def.key] ?? def.value;
                          return ListTile(
                            dense: true,
                            title: Text(
                              def.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'الوحدة: ${def.unit}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              child: Text(
                                '${_money(current)} ج',
                                style: const TextStyle(
                                  color: Color(0xFFC5A059),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onTap: () {
                              _openQuickEdit(
                                title: 'تعديل سعر: ${def.label}',
                                current: current,
                                unit: 'ج/${def.unit}',
                                onSave: (v) {
                                  localCopy[def.key] = v;
                                  setModalState(() {});
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
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
                              _rebuild(() {
                                _customPrices.clear();
                                _customPrices.addAll(localCopy);
                              });
                              _scheduleAutoSave();
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC5A059),
                              foregroundColor: const Color(0xFF0F172A),
                            ),
                            child: const Text(
                              'تطبيق الأسعار الجديدة',
                              style: TextStyle(fontWeight: FontWeight.bold),
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

  // ============================ صورة الفاتورة (باللوجو) ============================
}
