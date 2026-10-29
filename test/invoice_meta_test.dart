import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtian_app/features/clients/invoice/invoice_calculator.dart';
import 'package:paris_curtian_app/features/clients/invoice/invoice_meta.dart';

void main() {
  group('invoiceStatusFor', () {
    test('لا دفعات = لم يُدفع', () {
      expect(invoiceStatusFor(total: 1000, paid: 0), InvoiceStatus.unpaid);
    });

    test('دفع جزئي', () {
      expect(invoiceStatusFor(total: 1000, paid: 400), InvoiceStatus.partial);
    });

    test('مدفوعة بالكامل (مع تجاهل كسور التقريب)', () {
      expect(invoiceStatusFor(total: 1000, paid: 1000), InvoiceStatus.paid);
      expect(invoiceStatusFor(total: 1000.004, paid: 1000), InvoiceStatus.paid);
    });

    test('مدفوع زيادة', () {
      expect(invoiceStatusFor(total: 1000, paid: 1200), InvoiceStatus.overpaid);
    });
  });

  group('payments', () {
    test('المجموع', () {
      final payments = [
        InvoicePayment(amount: 500, date: DateTime(2026, 1, 1)),
        InvoicePayment(amount: 250.5, date: DateTime(2026, 1, 5)),
      ];
      expect(sumPayments(payments), 750.5);
      expect(sumPayments(const []), 0);
    });

    test('تحويل من/إلى Map', () {
      final original = InvoicePayment(
        amount: 300,
        date: DateTime(2026, 3, 9),
        note: 'عربون',
      );
      final restored = InvoicePayment.fromMap(original.toMap());
      expect(restored, isNotNull);
      expect(restored!.amount, 300);
      expect(restored.note, 'عربون');
      expect(restored.date, DateTime(2026, 3, 9));
    });

    test('بيانات تالفة بترجع null', () {
      expect(InvoicePayment.fromMap(null), isNull);
      expect(InvoicePayment.fromMap({'amount': -5, 'date': Timestamp.now()}), isNull);
      expect(InvoicePayment.fromMap({'amount': 100}), isNull);
    });
  });

  group('رقم الفاتورة', () {
    test('الشكل ثابت', () {
      expect(
        newInvoiceNumber(DateTime(2026, 10, 30), 'abCdEfGhIjKlMnA7k2'),
        'PC-261030-A7K2',
      );
    });

    test('معرّف قصير بيتكمّل بأصفار', () {
      expect(newInvoiceNumber(DateTime(2026, 1, 2), 'x1'), 'PC-260102-00X1');
    });
  });

  test('frozenPrices بتحتفظ بالتعديل وبتكمّل الباقي من الافتراضي', () {
    final frozen = frozenPrices({'holder_wave': 99});
    expect(frozen['holder_wave'], 99);
    expect(frozen['holder_double'], defaultPrices()['holder_double']);
    expect(frozen.length, defaultPrices().length);
  });
}
