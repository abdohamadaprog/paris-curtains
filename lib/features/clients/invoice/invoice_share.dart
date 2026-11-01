part of 'invoice_page.dart';

// مشاركة الفاتورة: صورة باللوجو ونص واتساب
extension _InvoiceShare on _InvoicePageState {
  /// بيجهّز بيانات الفاتورة كنصوص جاهزة ويفتح معاينة الصورة.
  /// البنود المستبعدة مش بتظهر (زي نص الفاتورة).
  void _openInvoiceImage() {
    ShareLine toLine(InvoiceLine l) => ShareLine(
      label: l.label,
      detail: '${_fmtQty(l.qty)} ${l.unit} × ${_money(l.unitPrice)} ج',
      total: _money(l.total),
    );

    List<ShareLine> picked(
      List<InvoiceLine> acc,
      List<InvoiceLine> fab,
      Set<String> ex,
    ) => [
      ...acc,
      ...fab,
    ].where((l) => !ex.contains(l.key)).map(toLine).toList();

    final sections = <ShareSection>[];
    if (_hasApt) {
      final inv = _getApartmentInvoice();
      final lines = picked(inv.accessoryLines, inv.fabricLines, _aptExcluded);
      if (lines.isNotEmpty) {
        sections.add(
          ShareSection(
            title: 'ستائر الشقة',
            lines: lines,
            total: _money(_aptTotal),
          ),
        );
      }
    }
    if (_hasBalc) {
      final inv = _getBalconyInvoice();
      final lines = picked(inv.accessoryLines, inv.fabricLines, _balcExcluded);
      if (lines.isNotEmpty) {
        sections.add(
          ShareSection(
            title: 'ستائر البلكونة',
            lines: lines,
            total: _money(_balcTotal),
          ),
        );
      }
    }

    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'مفيش بنود في الفاتورة لسه',
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    final total = _combinedTotal;
    final remaining = roundMoney(total - _depositPaid);
    final hasDiscount = _discountAmount > 0;
    final issued = _issuedAt;
    final phone = widget.phone;

    final data = InvoiceShareData(
      clientName: widget.clientName,
      phone: (phone == null || phone.isEmpty) ? null : _arNum(phone),
      number: _invoiceNumber,
      date: issued == null ? null : _fmtDate(issued),
      sections: sections,
      subtotal: hasDiscount ? _money(_subtotal) : null,
      discount: hasDiscount ? _money(_discountAmount) : null,
      discountNote: _discount.note,
      total: _money(total),
      paid: _money(_depositPaid),
      remaining: _money(remaining.abs()),
      owes: remaining > 0,
      payments: [
        for (final p in _payments)
          SharePayment(
            date: _fmtDate(p.date),
            amount: _money(p.amount),
            note: p.note,
          ),
      ],
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvoiceImagePage(data: data)),
    );
  }

  // ============================ مشاركة نص الفاتورة (واتساب) ============================

  void _shareAsText() {
    final aptInv = _getApartmentInvoice();
    final balcInv = _getBalconyInvoice();
    final combined = _combinedTotal;
    final remaining = roundMoney(combined - _depositPaid);

    String fmt(InvoiceLine l) =>
        '• ${l.label}: ${_fmtQty(l.qty)} ${l.unit} × ${_money(l.unitPrice)} = ${_money(l.total)} ج';

    // الإكسسوارات الأول وبعدها القماش — والبنود المستبعدة مش بتظهر
    List<InvoiceLine> picked(
      List<InvoiceLine> acc,
      List<InvoiceLine> fab,
      Set<String> ex,
    ) => [...acc, ...fab].where((l) => !ex.contains(l.key)).toList();

    final b = StringBuffer();
    b.writeln('━━━━━━━━━━━━━━━━━━━━');
    b.writeln('✨ ستائر باريس — PARIS CURTAINS ✨');
    b.writeln('━━━━━━━━━━━━━━━━━━━━');
    if (_invoiceNumber != null) {
      b.writeln('🧾 رقم الفاتورة: $_invoiceNumber');
    }
    if (_issuedAt != null) {
      final d = _issuedAt!;
      b.writeln('📅 التاريخ: ${_arNum('${d.day}/${d.month}/${d.year}')}');
    }
    b.writeln('👤 العميل: ${widget.clientName}');
    if (widget.phone != null && widget.phone!.isNotEmpty) {
      b.writeln('📱 الهاتف: ${_arNum(widget.phone!)}');
    }
    b.writeln('━━━━━━━━━━━━━━━━━━━━');

    final aptLines = _hasApt
        ? picked(aptInv.accessoryLines, aptInv.fabricLines, _aptExcluded)
        : <InvoiceLine>[];
    if (aptLines.isNotEmpty) {
      b.writeln('🏠 [ستائر الشقة]');
      for (final l in aptLines) {
        b.writeln(fmt(l));
      }
      b.writeln('🔹 إجمالي الشقة: ${_money(_aptTotal)} ج.م');
      b.writeln('');
    }

    final balcLines = _hasBalc
        ? picked(balcInv.accessoryLines, balcInv.fabricLines, _balcExcluded)
        : <InvoiceLine>[];
    if (balcLines.isNotEmpty) {
      b.writeln('🌿 [ستائر البلكونة]');
      for (final l in balcLines) {
        b.writeln(fmt(l));
      }
      b.writeln('🔹 إجمالي البلكونة: ${_money(_balcTotal)} ج.م');
      b.writeln('');
    }

    b.writeln('━━━━━━━━━━━━━━━━━━━━');
    if (_discountAmount > 0) {
      b.writeln('🧮 الإجمالي قبل الخصم: ${_money(_subtotal)} ج.م');
      final note = _discount.note.trim();
      b.writeln(
        '🏷️ خصم${note.isEmpty ? '' : ' ($note)'}: -${_money(_discountAmount)} ج.م',
      );
    }
    b.writeln('💰 الحساب الإجمالي: ${_money(combined)} ج.م');
    b.writeln('💵 المدفوع: ${_money(_depositPaid)} ج.م');
    b.writeln('⚖️ المتبقي الصافي: ${_money(remaining)} ج.م');
    b.writeln('━━━━━━━━━━━━━━━━━━━━');
    b.writeln('شكراً لثقتكم بنا ✨ ستائر باريس ترحب بكم دائماً');

    Clipboard.setData(ClipboardData(text: b.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ نص الفاتورة! جاهز للإرسال على واتساب 📲',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _kGold,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
