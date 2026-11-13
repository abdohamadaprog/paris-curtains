// تستات الجزء الإداري من الفاتورة: الخصم، الحالة، الدفعات، رقم الفاتورة.

import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtains/features/clients/invoice/invoice_meta.dart';

void main() {
  group('الخصم', () {
    test('خصم مبلغ ثابت', () {
      const d = InvoiceDiscount(type: DiscountType.amount, value: 250);
      expect(d.amountFor(1000), 250);
    });

    test('خصم نسبة مئوية', () {
      const d = InvoiceDiscount(type: DiscountType.percent, value: 10);
      expect(d.amountFor(1000), 100);
      expect(d.amountFor(14625), 1462.5);
    });

    test('الخصم مش بيتعدى الإجمالي', () {
      const d = InvoiceDiscount(type: DiscountType.percent, value: 150);
      expect(d.amountFor(1000), 1000);

      const d2 = InvoiceDiscount(type: DiscountType.amount, value: 5000);
      expect(d2.amountFor(300), 300);
    });

    test('مفيش خصم: القيمة صفر أو الإجمالي صفر', () {
      expect(const InvoiceDiscount().amountFor(1000), 0);
      const d = InvoiceDiscount(type: DiscountType.amount, value: 100);
      expect(d.amountFor(0), 0);
    });

    test('قيمة سالبة أو تالفة = مفيش خصم', () {
      const d = InvoiceDiscount(type: DiscountType.amount, value: -50);
      expect(d.isEmpty, isTrue);
      expect(d.amountFor(1000), 0);
    });

    test('fromMap بترجع خصم فاضي للبيانات التالفة', () {
      expect(InvoiceDiscount.fromMap(null).isEmpty, isTrue);
      expect(InvoiceDiscount.fromMap('x').isEmpty, isTrue);
      expect(InvoiceDiscount.fromMap({'value': 0}).isEmpty, isTrue);
      expect(InvoiceDiscount.fromMap({'value': -5}).isEmpty, isTrue);
    });

    test('fromMap بتقرا النوع والقيمة والملاحظة', () {
      final d = InvoiceDiscount.fromMap({
        'type': 'percent',
        'value': 15,
        'note': 'عرض افتتاح',
      });
      expect(d.type, DiscountType.percent);
      expect(d.value, 15);
      expect(d.note, 'عرض افتتاح');
    });

    test('الدورة الكاملة: حفظ واسترجاع', () {
      const original = InvoiceDiscount(
        type: DiscountType.percent,
        value: 12.5,
        note: 'اتفاق',
      );
      final restored = InvoiceDiscount.fromMap(original.toMap());
      expect(restored.type, original.type);
      expect(restored.value, original.value);
      expect(restored.note, original.note);
    });
  });

  group('حالة الفاتورة', () {
    test('مفيش دفعات = لم يُدفع', () {
      expect(invoiceStatusFor(total: 1000, paid: 0), InvoiceStatus.unpaid);
    });

    test('دفعة أقل من الإجمالي = جزئي', () {
      expect(invoiceStatusFor(total: 1000, paid: 500), InvoiceStatus.partial);
    });

    test('دفعة تساوي الإجمالي = مدفوعة', () {
      expect(invoiceStatusFor(total: 1000, paid: 1000), InvoiceStatus.paid);
      // فروق الكسور الصغيرة بتتسامح
      expect(invoiceStatusFor(total: 1000, paid: 1000.004), InvoiceStatus.paid);
    });

    test('دفعة أكتر من الإجمالي = مدفوع زيادة', () {
      expect(invoiceStatusFor(total: 1000, paid: 1200), InvoiceStatus.overpaid);
    });

    test('إجمالي صفر مع دفعة = مدفوع زيادة', () {
      expect(invoiceStatusFor(total: 0, paid: 100), InvoiceStatus.overpaid);
    });

    test('كل حالة ليها ليبل عربي', () {
      for (final s in InvoiceStatus.values) {
        expect(invoiceStatusLabel(s), isNotEmpty);
      }
    });
  });

  group('الدفعات', () {
    test('مجموع الدفعات بيتقرّب لأقرب قرش', () {
      final now = DateTime(2026, 1, 1);
      final payments = [
        InvoicePayment(amount: 100.333, date: now),
        InvoicePayment(amount: 200.333, date: now),
      ];
      expect(sumPayments(payments), 300.67);
    });

    test('مجموع الدفعات', () {
      final now = DateTime(2026, 1, 1);
      final payments = [
        InvoicePayment(amount: 500, date: now),
        InvoicePayment(amount: 250.5, date: now),
      ];
      expect(sumPayments(payments), 750.5);
    });

    test('fromMap بيرفض المبالغ الصفرية أو السالبة', () {
      expect(InvoicePayment.fromMap(null), isNull);
      expect(InvoicePayment.fromMap({'amount': 0}), isNull);
      expect(InvoicePayment.fromMap({'amount': -10}), isNull);
      expect(InvoicePayment.fromMap('x'), isNull);
    });

    test('fromMap بيقرا kvالدورة كاملة', () {
      final now = DateTime(2026, 3, 15);
      final p = InvoicePayment(amount: 1200, date: now, note: 'عربون');
      final restored = InvoicePayment.fromMap(p.toMap());
      expect(restored, isNotNull);
      expect(restored!.amount, 1200);
      expect(restored.note, 'عربون');
      expect(restored.date, now);
    });
  });

  group('رقم الفاتورة', () {
    test('الصيغة: PC-يوم شهر سنة-آخر 4 حروف من العميل', () {
      final n = newInvoiceNumber(DateTime(2026, 10, 30), 'ABC-DEFG');
      expect(n, 'PC-261030-DEFG');
    });

    test('لو معرّف العميل قصير بيتكمّل أصفار', () {
      final n = newInvoiceNumber(DateTime(2026, 1, 5), 'AB');
      expect(n, 'PC-260105-00AB');
    });

    test('الرقم ثابت لنفس اليوم والعميل', () {
      final a = newInvoiceNumber(DateTime(2026, 1, 5), 'CLIENT123');
      final b = newInvoiceNumber(DateTime(2026, 1, 5, 23, 59), 'CLIENT123');
      expect(a, b);
    });
  });
}
