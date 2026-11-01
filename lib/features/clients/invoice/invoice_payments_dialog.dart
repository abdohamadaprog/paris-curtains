part of 'invoice_page.dart';

// ديالوج الدفعات (العربون) وديالوج الخصم
extension _InvoicePaymentsDialogs on _InvoicePageState {
  String _fmtDate(DateTime d) => _arNum('${d.day}/${d.month}/${d.year}');

  void _openDepositDialog() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final total = _combinedTotal;
            final remaining = roundMoney(total - _depositPaid);
            final status = invoiceStatusFor(total: total, paid: _depositPaid);

            void addPayment() {
              final v = _safeNum(amountCtrl.text);
              if (v <= 0) return;
              _rebuild(() {
                _payments.add(
                  InvoicePayment(
                    amount: v,
                    date: DateTime.now(),
                    note: noteCtrl.text.trim(),
                  ),
                );
                _depositPaid = sumPayments(_payments);
              });
              _scheduleAutoSave();
              amountCtrl.clear();
              noteCtrl.clear();
              setDialogState(() {});
            }

            Future<void> removePayment(int index) async {
              final ok = await showDialog<bool>(
                context: ctx,
                builder: (c) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: AlertDialog(
                    backgroundColor: _kPanel,
                    title: const Text(
                      'حذف الدفعة؟',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(color: _kMuted),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text(
                          'حذف',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (ok != true) return;
              _rebuild(() {
                _payments.removeAt(index);
                _depositPaid = sumPayments(_payments);
              });
              _scheduleAutoSave();
              setDialogState(() {});
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: _kPanel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: const [
                    Icon(Icons.payments_rounded, color: _kGreen),
                    SizedBox(width: 8),
                    Text(
                      'سجل الدفعات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الإجمالي ${_money(total)} • المدفوع ${_money(_depositPaid)}'
                          ' • ${remaining > 0 ? 'المتبقي ${_money(remaining)}' : 'خالص'}',
                          style: const TextStyle(color: _kMuted, fontSize: 12.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invoiceStatusLabel(status),
                          style: TextStyle(
                            color: status == InvoiceStatus.paid
                                ? _kGreen
                                : _kGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_payments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'لسه مفيش دفعات مسجّلة.',
                              style: TextStyle(color: _kMuted, fontSize: 13),
                            ),
                          ),
                        for (var i = 0; i < _payments.length; i++)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${_money(_payments[i].amount)} ج.م',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              [
                                _fmtDate(_payments[i].date),
                                if (_payments[i].note.isNotEmpty)
                                  _payments[i].note,
                              ].join('  •  '),
                              style: const TextStyle(
                                color: _kMuted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'حذف الدفعة',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFEF4444),
                              ),
                              onPressed: () => removePayment(i),
                            ),
                          ),
                        const Divider(color: _kLine),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: _kBg,
                            hintText: 'مبلغ الدفعة الجديدة',
                            hintStyle: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                            suffixText: 'ج.م',
                            suffixStyle: const TextStyle(
                              color: _kGreen,
                              fontWeight: FontWeight.bold,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _kLine),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: _kBg,
                            hintText: 'ملاحظة (اختياري) مثال: عربون',
                            hintStyle: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _kLine),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: addPayment,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(
                              'إضافة دفعة',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kGreen,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'تم',
                      style: TextStyle(color: _kMuted),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================ ديالوج الخصم ============================

  void _openDiscountDialog() {
    final valueCtrl = TextEditingController(
      text: _discount.isEmpty
          ? ''
          : (_discount.value == _discount.value.roundToDouble()
                ? _discount.value.toInt().toString()
                : _discount.value.toString()),
    );
    final noteCtrl = TextEditingController(text: _discount.note);
    var type = _discount.type;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final subtotal = _subtotal;
            final preview = InvoiceDiscount(
              type: type,
              value: _safeNum(valueCtrl.text),
              note: '',
            ).amountFor(subtotal);

            Widget typeChip(String label, DiscountType t) {
              final selected = type == t;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setDialogState(() => type = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? _kGold : _kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? _kGold : _kLine),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? _kBg : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            InputDecoration deco(String hint) => InputDecoration(
              filled: true,
              fillColor: _kBg,
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kLine),
              ),
            );

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: _kPanel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'خصم على الفاتورة',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإجمالي قبل الخصم: ${_money(subtotal)} ج.م',
                        style: const TextStyle(color: _kMuted, fontSize: 12.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          typeChip('مبلغ (ج.م)', DiscountType.amount),
                          const SizedBox(width: 8),
                          typeChip('نسبة (%)', DiscountType.percent),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: valueCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          color: _kGold,
                          fontWeight: FontWeight.bold,
                        ),
                        onChanged: (_) => setDialogState(() {}),
                        decoration: deco(
                          type == DiscountType.percent
                              ? 'نسبة الخصم'
                              : 'مبلغ الخصم',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: deco('ملاحظة (اختياري) مثال: عميل قديم'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        preview > 0
                            ? 'الخصم ${_money(preview)} ج ← الصافي ${_money(roundMoney(subtotal - preview))} ج'
                            : 'اكتب قيمة الخصم',
                        style: TextStyle(
                          color: preview > 0 ? _kGreen : _kMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (!_discount.isEmpty)
                    TextButton(
                      onPressed: () {
                        _rebuild(() => _discount = const InvoiceDiscount());
                        _scheduleAutoSave();
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'إزالة الخصم',
                        style: TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء', style: TextStyle(color: _kMuted)),
                  ),
                  TextButton(
                    onPressed: () {
                      final v = _safeNum(valueCtrl.text);
                      _rebuild(() {
                        _discount = v <= 0
                            ? const InvoiceDiscount()
                            : InvoiceDiscount(
                                type: type,
                                value: v,
                                note: noteCtrl.text.trim(),
                              );
                      });
                      _scheduleAutoSave();
                      Navigator.pop(ctx);
                    },
                    child: const Text('حفظ', style: TextStyle(color: _kGold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================ ديالوج إضافة بند مخصص ============================
}
