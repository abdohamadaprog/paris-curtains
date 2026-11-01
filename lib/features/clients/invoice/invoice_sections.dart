part of 'invoice_page.dart';

// تبويبات الشقة والبلكونة وبنود الفاتورة (الكروت والصفوف)
extension _InvoiceSectionsUi on _InvoicePageState {
  Widget _buildApartmentTab() {
    if (!_hasApt) {
      return _buildEmptyState(
        icon: Icons.curtains_rounded,
        title: 'مفيش مقاسات للشقة',
        sub: 'ضيف مقاسات الشبابيك من صفحة المقاسات الأول',
      );
    }
    final invoice = _getApartmentInvoice();
    final ex = _aptExcluded;
    final acc = _sumIncluded(invoice.accessoryLines, ex);
    final fab = _sumIncluded(invoice.fabricLines, ex);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        // الإكسسوارات الأول
        _buildSectionCard(
          title: 'الإكسسوارات والمصنعية',
          icon: Icons.hardware_rounded,
          lines: invoice.accessoryLines,
          totalLabel: 'إجمالي الإكسسوارات',
          totalVal: acc,
          isBalcony: false,
          isFabric: false,
          showAdd: true,
        ),
        const SizedBox(height: 14),
        // وبعدها القماش
        _buildSectionCard(
          title: 'القماش',
          icon: Icons.texture_rounded,
          lines: invoice.fabricLines,
          totalLabel: 'إجمالي القماش',
          totalVal: fab,
          isBalcony: false,
          isFabric: true,
        ),
        const SizedBox(height: 14),
        _buildTabTotalCard(
          label: 'إجمالي الشقة',
          accessories: acc,
          fabric: fab,
          hasAccessories: _anyIncluded(invoice.accessoryLines, ex),
          hasFabric: _anyIncluded(invoice.fabricLines, ex),
        ),
      ],
    );
  }

  // ============================ تبويب البلكونة ============================

  Widget _buildBalconyTab() {
    if (!_hasBalc) {
      return _buildEmptyState(
        icon: Icons.balcony_rounded,
        title: 'مفيش مقاسات للبلكونة',
        sub: 'ضيف أضلاع البلكونة من صفحة المقاسات الأول',
      );
    }
    final invoice = _getBalconyInvoice();
    final ex = _balcExcluded;
    final acc = _sumIncluded(invoice.accessoryLines, ex);
    final fab = _sumIncluded(invoice.fabricLines, ex);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        // الإكسسوارات الأول
        _buildSectionCard(
          title: 'الإكسسوارات والمصنعية',
          icon: Icons.hardware_rounded,
          lines: invoice.accessoryLines,
          totalLabel: 'إجمالي الإكسسوارات',
          totalVal: acc,
          isBalcony: true,
          isFabric: false,
          showAdd: true,
        ),
        const SizedBox(height: 14),
        // وبعدها القماش — اضغط على اسم القماش عشان تغيّر النوع
        _buildSectionCard(
          title: 'القماش',
          icon: Icons.texture_rounded,
          lines: invoice.fabricLines,
          totalLabel: 'إجمالي القماش',
          totalVal: fab,
          isBalcony: true,
          isFabric: true,
        ),
        const SizedBox(height: 14),
        _buildTabTotalCard(
          label: 'إجمالي البلكونة',
          accessories: acc,
          fabric: fab,
          hasAccessories: _anyIncluded(invoice.accessoryLines, ex),
          hasFabric: _anyIncluded(invoice.fabricLines, ex),
        ),
      ],
    );
  }

  /// اسم القماش في البلكونة: اضغط عليه تختار النوع من قايمة صغيرة
  Widget _buildFabricPicker(InvoiceLine line) {
    return PopupMenuButton<String>(
      tooltip: 'غيّر نوع القماش',
      color: _kPanel,
      onSelected: (key) {
        _rebuild(() => _balconyFabricKey = key);
        _scheduleAutoSave();
      },
      itemBuilder: (_) => [
        for (final e in kBalconyFabrics.entries)
          PopupMenuItem<String>(
            value: e.key,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  e.key == _balconyFabricKey
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: e.key == _balconyFabricKey ? _kGold : _kMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  e.value,
                  style: TextStyle(
                    color: e.key == _balconyFabricKey ? _kGold : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${_money(_customPrices[e.key] ?? defaultPrices()[e.key] ?? 0)} ج/م',
                  style: const TextStyle(color: _kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              line.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded, color: _kGold, size: 22),
        ],
      ),
    );
  }

  // ============================ تعديل البنود ============================

  double _sumIncluded(List<InvoiceLine> lines, Set<String> excluded) {
    return roundMoney(
      lines
          .where((l) => !excluded.contains(l.key))
          .fold(0.0, (acc, l) => acc + l.total),
    );
  }

  bool _anyIncluded(List<InvoiceLine> lines, Set<String> excluded) =>
      lines.any((l) => !excluded.contains(l.key));

  void _toggleLine(String key, {required bool isBalcony}) {
    final set = isBalcony ? _balcExcluded : _aptExcluded;
    _rebuild(() {
      if (!set.remove(key)) set.add(key);
    });
    _scheduleAutoSave();
  }

  /// لو في أي بند داخل → استبعد الكل، ولو مفيش → ضمّن الكل
  void _toggleSection(List<InvoiceLine> lines, {required bool isBalcony}) {
    final set = isBalcony ? _balcExcluded : _aptExcluded;
    final anyIn = lines.any((l) => !set.contains(l.key));
    _rebuild(() {
      for (final l in lines) {
        if (anyIn) {
          set.add(l.key);
        } else {
          set.remove(l.key);
        }
      }
    });
    _scheduleAutoSave();
  }

  void _editQty(String key, double current, {required bool isBalcony, required bool isFabric}) {
    _openQuickEdit(
      title: isFabric ? 'تعديل أمتار القماش' : 'تعديل الكمية',
      current: current,
      unit: isFabric ? 'متر' : '',
      onSave: (v) {
        _rebuild(() {
          (isBalcony ? _balcQtyOverride : _aptQtyOverride)[key] = v;
        });
        _scheduleAutoSave();
      },
    );
  }

  void _editPrice(String key, double current, {required bool isBalcony, required bool isFabric}) {
    _openQuickEdit(
      title: isFabric ? 'تعديل سعر المتر' : 'تعديل سعر الوحدة',
      current: current,
      unit: 'ج.م',
      onSave: (v) {
        _rebuild(() {
          (isBalcony ? _balcPriceOverride : _aptPriceOverride)[key] = v;
        });
        _scheduleAutoSave();
      },
    );
  }

  void _removeCustomLine(String key, {required bool isBalcony}) {
    _rebuild(() {
      if (isBalcony) {
        _balcCustomLines.removeWhere((l) => l.key == key);
        _balcExcluded.remove(key);
        _balcQtyOverride.remove(key);
        _balcPriceOverride.remove(key);
      } else {
        _aptCustomLines.removeWhere((l) => l.key == key);
        _aptExcluded.remove(key);
        _aptQtyOverride.remove(key);
        _aptPriceOverride.remove(key);
      }
    });
    _scheduleAutoSave();
  }

  // ============================ كارت القسم والجدول ============================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<InvoiceLine> lines,
    required String totalLabel,
    required double totalVal,
    required bool isBalcony,
    required bool isFabric,
    bool showAdd = false,
  }) {
    final excluded = isBalcony ? _balcExcluded : _aptExcluded;
    final includedCount = lines.where((l) => !excluded.contains(l.key)).length;
    final visible = _hideExcluded
        ? lines.where((l) => !excluded.contains(l.key)).toList()
        : lines;

    if (visible.isEmpty && !showAdd) return const SizedBox.shrink();

    // أيقونة "تحديد الكل": كله داخل / بعضه / ولا حاجة
    final allIn = lines.isNotEmpty && includedCount == lines.length;
    final noneIn = includedCount == 0;

    return Container(
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // عنوان القسم
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
            child: Row(
              children: [
                Icon(icon, color: _kGold, size: 19),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: _kGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const Spacer(),
                if (lines.isNotEmpty)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _toggleSection(lines, isBalcony: isBalcony),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Text(
                            allIn ? 'الكل' : (noneIn ? 'بدون' : 'جزء'),
                            style: const TextStyle(color: _kMuted, fontSize: 12),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            allIn
                                ? Icons.check_circle_rounded
                                : noneIn
                                ? Icons.radio_button_unchecked
                                : Icons.remove_circle_outline_rounded,
                            size: 21,
                            color: noneIn ? _kMuted : _kGold,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: _kLine, height: 1),

          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              const Divider(color: _kLine, height: 1, indent: 14, endIndent: 14),
            _buildLineRow(
              visible[i],
              included: !excluded.contains(visible[i].key),
              onToggle: () =>
                  _toggleLine(visible[i].key, isBalcony: isBalcony),
              onQty: () => _editQty(
                visible[i].key,
                visible[i].qty,
                isBalcony: isBalcony,
                isFabric: isFabric,
              ),
              onPrice: () => _editPrice(
                visible[i].key,
                visible[i].unitPrice,
                isBalcony: isBalcony,
                isFabric: isFabric,
              ),
              onDelete: visible[i].manual
                  ? () =>
                        _removeCustomLine(visible[i].key, isBalcony: isBalcony)
                  : null,
              nameWidget: (isBalcony && isFabric)
                  ? _buildFabricPicker(visible[i])
                  : null,
            ),
          ],

          if (showAdd) ...[
            if (visible.isNotEmpty) const Divider(color: _kLine, height: 1),
            InkWell(
              onTap: () => _openAddCustomLineDialog(isBalcony: isBalcony),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 18, color: _kGold),
                    SizedBox(width: 6),
                    Text(
                      'إضافة بند',
                      style: TextStyle(
                        color: _kGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // إجمالي القسم (المحدد فقط)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Text(
                  totalLabel,
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_money(totalVal)} ج.م',
                  style: TextStyle(
                    color: noneIn ? _kMuted : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortUnit(String unit) => unit == 'متر' ? 'م' : unit;

  /// سطر واحد للبند:  ✓ الاسم  |  الكمية × السعر  |  الإجمالي
  /// الدايرة على اليمين = داخل في الحساب ولا لأ. اضغط الكمية أو السعر للتعديل.
  Widget _buildLineRow(
    InvoiceLine line, {
    required bool included,
    required VoidCallback onToggle,
    required VoidCallback onQty,
    required VoidCallback onPrice,
    VoidCallback? onDelete,
    Widget? nameWidget,
  }) {
    Widget chip(String text, VoidCallback onTap) => InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );

    final unit = _shortUnit(line.unit);
    final qtyText = unit.isEmpty
        ? _fmtQty(line.qty)
        : '${_fmtQty(line.qty)} $unit';

    return Row(
      children: [
        // دايرة التحديد (داخل في الإجمالي ولا لأ)
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Icon(
              included
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 23,
              color: included ? _kGold : _kMuted,
            ),
          ),
        ),
        Expanded(
          child: Opacity(
            opacity: included ? 1 : 0.4,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Row(
                children: [
                  Expanded(
                    child:
                        nameWidget ??
                        Text(
                          line.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                  ),
                  const SizedBox(width: 6),
                  chip(qtyText, onQty),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '×',
                      style: TextStyle(color: _kMuted, fontSize: 13),
                    ),
                  ),
                  chip(_money(line.unitPrice), onPrice),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 58),
                    child: Text(
                      '${_money(line.total)} ج',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: _kGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        decoration: included ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onDelete != null)
          IconButton(
            tooltip: 'حذف البند',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFEF4444),
              size: 19,
            ),
          ),
      ],
    );
  }

  /// ملخص التبويب (آخر القائمة): بيعرض الأقسام اللي فيها بنود محددة بس
  Widget _buildTabTotalCard({
    required String label,
    required double accessories,
    required double fabric,
    required bool hasAccessories,
    required bool hasFabric,
  }) {
    Widget row(String l, double v, {bool big = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            l,
            style: TextStyle(
              color: big ? Colors.white : _kMuted,
              fontSize: big ? 15.5 : 13.5,
              fontWeight: big ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_money(v)} ج.م',
            style: TextStyle(
              color: big ? _kGold : Colors.white,
              fontSize: big ? 18 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(
        children: [
          if (hasAccessories) row('إجمالي الإكسسوارات', accessories),
          if (hasFabric) row('إجمالي القماش', fabric),
          if (hasAccessories || hasFabric)
            const Divider(color: _kLine, height: 14),
          row(label, roundMoney(accessories + fabric), big: true),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String sub,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: _kLine),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              style: const TextStyle(color: _kMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================ الشريط المالي السفلي ============================
  // الإجمالي (شقة + بلكونة) | العربون (اضغط للتعديل) | المتبقي
}
