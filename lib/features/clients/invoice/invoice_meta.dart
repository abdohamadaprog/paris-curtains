import 'package:cloud_firestore/cloud_firestore.dart';

import 'invoice_calculator.dart';

/// بيانات الفاتورة "الإدارية": رقم الفاتورة، سجل الدفعات، الحالة.
/// منطق بحت (من غير واجهة) عشان يتختبر بسهولة.

/// دفعة واحدة من العميل (عربون، دفعة تانية، تسوية...).
class InvoicePayment {
  const InvoicePayment({
    required this.amount,
    required this.date,
    this.note = '',
  });

  final double amount;
  final DateTime date;
  final String note;

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'date': Timestamp.fromDate(date),
    'note': note,
  };

  /// بيرجّع null لو البيانات تالفة أو المبلغ مش موجب.
  static InvoicePayment? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final amountRaw = raw['amount'];
    final amount = amountRaw is num ? amountRaw.toDouble() : 0.0;
    if (amount <= 0 || amount.isNaN || amount.isInfinite) return null;

    final dateRaw = raw['date'];
    DateTime? date;
    if (dateRaw is Timestamp) {
      date = dateRaw.toDate();
    } else if (dateRaw is DateTime) {
      date = dateRaw;
    }
    if (date == null) return null;

    return InvoicePayment(
      amount: amount,
      date: date,
      note: (raw['note'] ?? '').toString(),
    );
  }
}

/// نوع الخصم: مبلغ ثابت أو نسبة مئوية.
enum DiscountType { amount, percent }

/// خصم على الفاتورة (بيتحط يدويًا لبعض العملاء).
/// الخصم بيتحسب على إجمالي الفاتورة قبل الخصم، ومبيعدّيش الإجمالي نفسه.
class InvoiceDiscount {
  const InvoiceDiscount({
    this.type = DiscountType.amount,
    this.value = 0,
    this.note = '',
  });

  final DiscountType type;
  final double value;
  final String note;

  bool get isEmpty => value <= 0 || value.isNaN || value.isInfinite;

  /// قيمة الخصم بالجنيه على [subtotal] (من صفر لحد الإجمالي).
  double amountFor(double subtotal) {
    if (isEmpty || subtotal <= 0) return 0;
    final raw = type == DiscountType.percent ? subtotal * value / 100 : value;
    final capped = raw < 0 ? 0.0 : (raw > subtotal ? subtotal : raw);
    return roundMoney(capped);
  }

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'value': value,
    'note': note,
  };

  /// بيرجّع "مفيش خصم" لو البيانات ناقصة أو تالفة.
  static InvoiceDiscount fromMap(dynamic raw) {
    if (raw is! Map) return const InvoiceDiscount();
    final v = raw['value'];
    final value = v is num ? v.toDouble() : 0.0;
    if (value <= 0 || value.isNaN || value.isInfinite) {
      return const InvoiceDiscount();
    }
    return InvoiceDiscount(
      type: raw['type'] == 'percent' ? DiscountType.percent : DiscountType.amount,
      value: value,
      note: (raw['note'] ?? '').toString(),
    );
  }
}

/// حالة الدفع.
enum InvoiceStatus { unpaid, partial, paid, overpaid }

String invoiceStatusLabel(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.unpaid:
      return 'لم يُدفع بعد';
    case InvoiceStatus.partial:
      return 'دفع جزئي';
    case InvoiceStatus.paid:
      return 'مدفوعة بالكامل';
    case InvoiceStatus.overpaid:
      return 'مدفوع زيادة';
  }
}

InvoiceStatus invoiceStatusFor({required double total, required double paid}) {
  final t = roundMoney(total);
  final p = roundMoney(paid);
  if (p <= 0) return InvoiceStatus.unpaid;
  if (t <= 0) return InvoiceStatus.overpaid;
  if ((p - t).abs() < 0.005) return InvoiceStatus.paid;
  return p < t ? InvoiceStatus.partial : InvoiceStatus.overpaid;
}

double sumPayments(List<InvoicePayment> payments) =>
    roundMoney(payments.fold<double>(0, (acc, p) => acc + p.amount));

/// رقم الفاتورة: PC-يومالشهرالسنة-آخر 4 حروف من معرّف العميل.
/// مثال: PC-261030-A7K2. (فاتورة واحدة لكل عميل، فالرقم ثابت بعد أول حفظ.)
String newInvoiceNumber(DateTime now, String clientId) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${two(now.year % 100)}${two(now.month)}${two(now.day)}';
  final clean = clientId.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final suffix = clean.length >= 4
      ? clean.substring(clean.length - 4)
      : clean.padLeft(4, '0');
  return 'PC-$date-$suffix';
}

/// لقطة الأسعار: الأسعار الافتراضية + أي تعديل. بتتحفظ مع الفاتورة عشان
/// تغيير الأسعار الافتراضية بعد كده ميغيّرش الفواتير القديمة.
Map<String, double> frozenPrices(Map<String, double> custom) => {
  ...defaultPrices(),
  ...custom,
};
