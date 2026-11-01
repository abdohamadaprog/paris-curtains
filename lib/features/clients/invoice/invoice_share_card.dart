import 'package:flutter/material.dart';

/// كارت الفاتورة اللي بيتحوّل لصورة (باللوجو) ويتبعت للعميل.
/// مفيش فيه أي حساب: كل القيم بتوصله جاهزة كنصوص من صفحة الفاتورة.

const Color _paper = Color(0xFFFFFBF3);
const Color _ink = Color(0xFF1F2937);
const Color _inkMuted = Color(0xFF6B7280);
const Color _gold = Color(0xFFB8893A);
const Color _goldSoft = Color(0xFFF3E7CC);
const Color _line = Color(0xFFE5D9BF);
const Color _green = Color(0xFF15803D);
const Color _red = Color(0xFFB91C1C);

/// عرض الكارت الثابت (الصورة بتطلع بنفس الشكل على أي موبايل)
const double kInvoiceCardWidth = 600;

class ShareLine {
  const ShareLine({
    required this.label,
    required this.detail,
    required this.total,
  });

  /// اسم البند
  final String label;

  /// مثال: ٢١ متر × ٧٥ ج
  final String detail;

  /// إجمالي البند (نص جاهز)
  final String total;
}

class ShareSection {
  const ShareSection({
    required this.title,
    required this.lines,
    required this.total,
  });

  final String title;
  final List<ShareLine> lines;
  final String total;
}

class SharePayment {
  const SharePayment({
    required this.date,
    required this.amount,
    this.note = '',
  });

  final String date;
  final String amount;
  final String note;
}

class InvoiceShareData {
  const InvoiceShareData({
    required this.clientName,
    required this.sections,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.owes,
    this.number,
    this.date,
    this.phone,
    this.subtotal,
    this.discount,
    this.discountNote = '',
    this.payments = const [],
  });

  final String clientName;
  final String? phone;
  final String? number;
  final String? date;
  final List<ShareSection> sections;

  /// بيظهروا بس لو فيه خصم
  final String? subtotal;
  final String? discount;
  final String discountNote;

  final String total;
  final String paid;
  final String remaining;
  final bool owes;
  final List<SharePayment> payments;
}

class InvoiceShareCard extends StatelessWidget {
  const InvoiceShareCard({super.key, required this.data});

  final InvoiceShareData data;

  static const String _font = 'Cairo';

  TextStyle _t(
    double size, {
    Color color = _ink,
    FontWeight weight = FontWeight.w500,
    double? height,
  }) => TextStyle(
    fontFamily: _font,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: kInvoiceCardWidth,
        color: _paper,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 8, color: _gold),
            _header(),
            _clientBlock(),
            for (final s in data.sections) _section(s),
            _totals(),
            if (data.payments.isNotEmpty) _payments(),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        children: [
          Image.asset('assets/images/logo.png', height: 130, fit: BoxFit.contain),
          const SizedBox(height: 6),
          Text('فاتورة', style: _t(20, color: _gold, weight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _clientBlock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _goldSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'العميل: ${data.clientName}',
                  style: _t(15, weight: FontWeight.w800),
                ),
              ),
              if (data.number != null)
                Text(data.number!, style: _t(12, color: _inkMuted)),
            ],
          ),
          if ((data.phone ?? '').isNotEmpty || data.date != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  if ((data.phone ?? '').isNotEmpty)
                    Expanded(
                      child: Text(
                        'الهاتف: ${data.phone}',
                        style: _t(12.5, color: _inkMuted),
                      ),
                    )
                  else
                    const Spacer(),
                  if (data.date != null)
                    Text(
                      'التاريخ: ${data.date}',
                      style: _t(12.5, color: _inkMuted),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(ShareSection s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 4, height: 18, color: _gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.title,
                  style: _t(15, color: _gold, weight: FontWeight.w800),
                ),
              ),
              Text(
                '${s.total} ج',
                style: _t(14, color: _gold, weight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: _line),
          for (final l in s.lines) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.label, style: _t(13.5, weight: FontWeight.w700)),
                        const SizedBox(height: 1),
                        Text(l.detail, style: _t(11.5, color: _inkMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${l.total} ج', style: _t(13.5, weight: FontWeight.w800)),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),
          ],
        ],
      ),
    );
  }

  Widget _totals() {
    Widget row(String label, String value, {Color? color, bool big = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: _t(big ? 16 : 13.5, color: color ?? _ink, weight: big ? FontWeight.w900 : FontWeight.w600),
              ),
            ),
            Text(
              '$value ج',
              style: _t(big ? 19 : 14.5, color: color ?? _ink, weight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    final hasDiscount = data.discount != null && data.subtotal != null;
    final note = data.discountNote.trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold, width: 1.4),
      ),
      child: Column(
        children: [
          if (hasDiscount) ...[
            row('الإجمالي قبل الخصم', data.subtotal!, color: _inkMuted),
            row(
              note.isEmpty ? 'خصم' : 'خصم ($note)',
              '-${data.discount!}',
              color: _green,
            ),
            const Divider(height: 10, color: _line),
          ],
          row('الإجمالي', data.total, color: _gold, big: true),
          row('المدفوع', data.paid, color: _green),
          const Divider(height: 10, color: _line),
          row(
            data.owes ? 'المتبقي' : 'خالص',
            data.remaining,
            color: data.owes ? _red : _green,
            big: true,
          ),
        ],
      ),
    );
  }

  Widget _payments() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('سجل الدفعات', style: _t(13, color: _inkMuted, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          for (final p in data.payments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.note.isEmpty ? p.date : '${p.date} • ${p.note}',
                      style: _t(12, color: _inkMuted),
                    ),
                  ),
                  Text('${p.amount} ج', style: _t(12.5, weight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: Column(
        children: [
          const Divider(height: 1, color: _line),
          const SizedBox(height: 12),
          Text(
            'شكرًا لثقتكم بنا ✨',
            style: _t(14, color: _gold, weight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text('باريس للستائر — Paris Curtains', style: _t(11.5, color: _inkMuted)),
        ],
      ),
    );
  }
}
