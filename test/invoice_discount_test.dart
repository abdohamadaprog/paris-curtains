import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtains/features/clients/invoice/invoice_meta.dart';

void main() {
  group('InvoiceDiscount', () {
    test('مبلغ ثابت', () {
      const d = InvoiceDiscount(value: 500);
      expect(d.amountFor(14625), 500);
    });

    test('نسبة مئوية', () {
      const d = InvoiceDiscount(type: DiscountType.percent, value: 10);
      expect(d.amountFor(14625), 1462.5);
    });

    test('الخصم مبيعدّيش الإجمالي', () {
      const amount = InvoiceDiscount(value: 99999);
      expect(amount.amountFor(1000), 1000);
      const percent = InvoiceDiscount(type: DiscountType.percent, value: 150);
      expect(percent.amountFor(1000), 1000);
    });

    test('مفيش خصم لو القيمة صفر أو الإجمالي صفر', () {
      expect(const InvoiceDiscount().amountFor(1000), 0);
      expect(const InvoiceDiscount(value: 100).amountFor(0), 0);
      expect(const InvoiceDiscount(value: -5).amountFor(1000), 0);
    });

    test('toMap / fromMap بيرجّعوا نفس الخصم', () {
      const d = InvoiceDiscount(
        type: DiscountType.percent,
        value: 7.5,
        note: 'عميل قديم',
      );
      final back = InvoiceDiscount.fromMap(d.toMap());
      expect(back.type, DiscountType.percent);
      expect(back.value, 7.5);
      expect(back.note, 'عميل قديم');
    });

    test('بيانات تالفة أو فاتورة قديمة من غير خصم = مفيش خصم', () {
      expect(InvoiceDiscount.fromMap(null).isEmpty, isTrue);
      expect(InvoiceDiscount.fromMap('abc').isEmpty, isTrue);
      expect(InvoiceDiscount.fromMap({'value': 'x'}).isEmpty, isTrue);
      expect(InvoiceDiscount.fromMap({'value': -3}).isEmpty, isTrue);
    });

    test('الحالة بتتحسب على الصافي بعد الخصم', () {
      const d = InvoiceDiscount(value: 1000);
      final net = 14625 - d.amountFor(14625);
      expect(invoiceStatusFor(total: net, paid: 13625), InvoiceStatus.paid);
      expect(invoiceStatusFor(total: net, paid: 5000), InvoiceStatus.partial);
    });
  });
}
