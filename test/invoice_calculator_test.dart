import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtian_app/features/clients/screens/invoice/invoice_calculator.dart';

double _sum(List<InvoiceLine> lines) =>
    lines.fold(0.0, (total, line) => total + line.total);

InvoiceLine _line(ApartmentInvoice invoice, String key) => [
  ...invoice.fabricLines,
  ...invoice.accessoryLines,
].firstWhere((line) => line.key == key);

InvoiceLine _balconyLine(BalconyInvoice invoice, String key) => [
  ...invoice.fabricLines,
  ...invoice.accessoryLines,
].firstWhere((line) => line.key == key);

void main() {
  test('شقة: 6 شبابيك بعرض إجمالي 10.5م بنظام ويفي', () {
    final windows = List.generate(
      6,
      (index) => WindowSpec(
        title: 'شباك ${index + 1}',
        width: 1.75,
        height: 2.8,
        curtainType: 'wave',
        hasHeavy: true,
        hasLight: true,
      ),
    );

    final invoice = calculateApartmentInvoice(windows: windows);

    expect(_sum(invoice.fabricLines), 7530);
    expect(_line(invoice, 'fabric_linen').qty, 21);
    expect(_line(invoice, 'fabric_velvet').qty, 32);
    expect(_line(invoice, 'track').qty, 21);
    expect(_line(invoice, 'holder_wave').qty, 42);
    expect(_line(invoice, 'install_window').qty, 6);
    expect(_sum(invoice.accessoryLines), 7230);
    expect(invoice.grandTotal, 14760);
  });

  test('شقة مختلطة: ويفي + دابل ويفي + كبس', () {
    const windows = [
      WindowSpec(
        title: 'ويفي',
        width: 3,
        height: 2.8,
        curtainType: 'wave',
        hasHeavy: true,
        hasLight: true,
      ),
      WindowSpec(
        title: 'دابل ويفي',
        width: 2,
        height: 2.8,
        curtainType: 'double_wave',
        hasHeavy: true,
        hasLight: true,
      ),
      WindowSpec(
        title: 'كبس ثقيل وخفيف',
        width: 2.5,
        height: 2.8,
        curtainType: 'press',
        hasHeavy: true,
        hasLight: true,
      ),
      WindowSpec(
        title: 'كبس خفيف',
        width: 1,
        height: 2.8,
        curtainType: 'press',
        hasHeavy: false,
        hasLight: true,
      ),
    ];

    final invoice = calculateApartmentInvoice(windows: windows);

    expect(_sum(invoice.fabricLines), 5770);
    expect(_line(invoice, 'fabric_linen').qty, 19);
    expect(_line(invoice, 'fabric_velvet').qty, 22);
    expect(_line(invoice, 'holder_wave').qty, 12);
    expect(_line(invoice, 'holder_double').qty, 8);
    expect(_line(invoice, 'ring_unit').qty, 42);
    expect(_line(invoice, 'cantilever_forgia').qty, 6);
    expect(_sum(invoice.accessoryLines), 5395);
    expect(invoice.grandTotal, 11165);
  });

  test('بلكونة: عرض إجمالي 5م وقماش دك', () {
    const balconies = [
      BalconySpec(title: 'بلكونة', width: 5, height: 2.5, avezCount: 6),
    ];

    final invoice = calculateBalconyInvoice(
      balconies: balconies,
      fabricKey: 'fabric_dak',
    );

    expect(_balconyLine(invoice, 'fabric_dak').qty, 7.5);
    expect(_sum(invoice.fabricLines), 750);
    expect(_sum(invoice.accessoryLines), 1032.5);
    expect(_balconyLine(invoice, 'ring_unit').qty, 45);
    expect(_balconyLine(invoice, 'balc_avez').qty, 6);
    expect(invoice.grandTotal, 1782.5);
  });

  test('تقريب الأمتار لا يتأثر بأخطاء الفاصلة', () {
    expect(ceilMeters(3 * 1.1), 4);
    expect(ceilMeters(10.5 * 2), 21);
    expect(parseNumber('٢٫٥'), 2.5);
  });
}
