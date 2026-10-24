import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtian_app/features/clients/screens/invoice/invoice_calculator.dart';

double _sum(List<AutoLine> lines, Map<String, double> p) =>
    lines.fold(0.0, (a, l) => a + l.qty * (p[l.priceKey] ?? 0));

AutoLine _line(InvoiceAuto r, String key) =>
    [...r.fabric, ...r.accessories].firstWhere((l) => l.key == key);

void main() {
  test('شقة: 6 شبابيك 10.5م ويفي بكتان = 14,995 (الكوبشة 250)', () {
    final p = defaultPrices()..['kobsha'] = 250;
    final ws = List.generate(6, (_) => const WindowSpec(1.75, 'wave', true));
    final r = calcApartment(ws, p);
    expect(_sum(r.fabric, p), 7530);
    expect(_sum(r.accessories, p), 7465);
    expect(_line(r, 'linen').qty, 21);
    expect(_line(r, 'velvet').qty, 32);
    expect(_line(r, 'holder_wave').qty, 21);
    expect(_line(r, 'install').qty, 6);
  });

  test('شقة مختلطة: ويفي + دابل ويفي + كبس', () {
    final p = defaultPrices()..['kobsha'] = 200;
    final ws = [
      const WindowSpec(3.0, 'wave', true),
      const WindowSpec(2.0, 'doubleWave', true),
      const WindowSpec(2.5, 'press', true),
      const WindowSpec(1.0, 'press', false),
    ];
    final r = calcApartment(ws, p);
    expect(_sum(r.fabric, p), 5810);
    expect(_sum(r.accessories, p), 6210); // 5740 + كابولي 4×50 + قمقم 6×45
    expect(_line(r, 'rings').qty, 98);
    expect(_line(r, 'cantilever').qty, 4);
    expect(_line(r, 'holder_double').qty, 4);
  });

  test('بلكونة 3+1+1 دك', () {
    final p = defaultPrices();
    final r = calcBalcony(
      [
        const BalconySpec([3, 1, 1]),
      ],
      'fabric_dak',
      p,
    );
    expect(_line(r, 'balc_fabric').qty, 7.5);
    expect(_sum(r.fabric, p), 750);
    expect(_sum(r.accessories, p), 1032.5);
    expect(_line(r, 'balc_rings').qty, 45);
    expect(_line(r, 'balc_avez').qty, 6);
  });

  test('تقريب الأمتار لا يتأثر بأخطاء الفاصلة', () {
    expect(ceilMeters(3 * 1.1), 4);
    expect(ceilMeters(10.5 * 2), 21);
    expect(parseNumber('٢٫٥'), 2.5);
  });
}
