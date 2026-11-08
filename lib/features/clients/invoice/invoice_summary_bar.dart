part of 'invoice_page.dart';

// الشريط المالي السفلي (الإجمالي والمدفوع والمتبقي والخصم)
extension _InvoiceSummaryBar on _InvoicePageState {
  Widget _buildBottomSummaryBar() {
    final apt = _aptTotal;
    final balc = _balcTotal;
    final combined = _combinedTotal;
    final discountAmount = _discountAmount;
    final remaining = roundMoney(combined - _depositPaid);
    final owes = remaining > 0;
    final remainColor = owes ? const Color(0xFFEF4444) : _kGreen;

    Widget block({
      required String label,
      required String value,
      required Color color,
      VoidCallback? onTap,
      Color? border,
      IconData? trailing,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border ?? _kLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 4),
                      Icon(trailing, size: 12, color: _kMuted),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '$value ج',
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _kPanel,
        border: Border(top: BorderSide(color: _kLine, width: 1.5)),
        boxShadow: [
          BoxShadow(color: Colors.black38, offset: Offset(0, -3), blurRadius: 8),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  block(
                    label: 'الإجمالي',
                    value: _money(combined),
                    color: AppPalette.text,
                  ),
                  const SizedBox(width: 8),
                  block(
                    label: 'المدفوع',
                    value: _money(_depositPaid),
                    color: _kGreen,
                    onTap: _openDepositDialog,
                    trailing: Icons.edit_rounded,
                  ),
                  const SizedBox(width: 8),
                  block(
                    label: owes ? 'المتبقي' : 'خالص',
                    value: _money(remaining.abs()),
                    color: remainColor,
                    border: remainColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
              if (_hasApt && _hasBalc)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'الشقة ${_money(apt)} ج  +  البلكونة ${_money(balc)} ج',
                    style: TextStyle(color: _kMuted, fontSize: 11.5),
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _openDiscountDialog,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        size: 14,
                        color: discountAmount > 0 ? _kGold : _kMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        discountAmount > 0
                            ? 'خصم ${_money(discountAmount)} ج من ${_money(_subtotal)} ج  (تعديل)'
                            : 'إضافة خصم',
                        style: TextStyle(
                          color: discountAmount > 0 ? _kGold : _kMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================ ديالوج التعديل السريع الذكي ============================
}
