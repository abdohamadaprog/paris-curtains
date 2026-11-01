import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtian_app/features/clients/invoice/invoice_calculator.dart';

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
  tearDown(PriceOverrides.clear);

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
    // قاعدة الكوابيل (invoice_calculator.dart): 1.75م = 3 كوابيل للشباك
    // (القاعدة القديمة كانت 4 لكل متر = 42، وده كان أغلى بـ 960 ج).
    expect(_line(invoice, 'holder_wave').qty, 18);
    expect(_line(invoice, 'install_window').qty, 6);
    // الإكسسوارات = مسار 1575 + حوامل 720 + شريط ويفي 1760 + تجهيز 640
    //   + كسرات 315 + تركيب 600 + خياطة (خفيف 21م × 25 + ثقيل 32م × 30 = 1485)
    expect(_line(invoice, 'sew_light').qty, 21);
    expect(_line(invoice, 'sew_heavy').qty, 32);
    expect(_sum(invoice.accessoryLines), 7095);
    expect(invoice.grandTotal, 14625);
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
    // ويفي 3م = 4 كوابيل • دابل ويفي 2م = 3 كوابيل
    expect(_line(invoice, 'holder_wave').qty, 4);
    expect(_line(invoice, 'holder_double').qty, 3);
    // شريط الكبس = 2.5×2.5 + 2.5×2 + 1×2 = 13.25م × 7 حلقات للمتر = 93 حلقة
    expect(_line(invoice, 'ring_unit').qty, 93);
    // كابولي الكبس: شباكين كل واحد ≤ 3م = 2 كابولي → 4
    expect(_line(invoice, 'cantilever_forgia').qty, 4);
    expect(_sum(invoice.accessoryLines), 5840);
    expect(invoice.grandTotal, 11610);
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

  test('ثوابت الحساب: تعديل السعر العام بيتطبّق على الفواتير الجديدة', () {
    const windows = [
      WindowSpec(
        title: 'شباك',
        width: 2,
        height: 2.8,
        curtainType: 'wave',
        hasHeavy: true,
        hasLight: true,
      ),
    ];

    final before = calculateApartmentInvoice(windows: windows);
    expect(_line(before, 'install_window').unitPrice, 100);

    PriceOverrides.set({'install_window': 150, 'fabric_velvet': 200});
    final after = calculateApartmentInvoice(windows: windows);
    expect(_line(after, 'install_window').unitPrice, 150);
    expect(_line(after, 'fabric_velvet').unitPrice, 200);
    // سعر الكتان ماتغيرش لأنه مش معدّل
    expect(_line(after, 'fabric_linen').unitPrice, 130);

    // سعر مخصص لفاتورة بعينها بيكسب على السعر العام
    final custom = calculateApartmentInvoice(
      windows: windows,
      customPrices: {'install_window': 175},
    );
    expect(_line(custom, 'install_window').unitPrice, 175);
  });

  test('قاعدة كوابيل الويفي', () {
    expect(calcWaveHoldersForWindow(0), 0);
    expect(calcWaveHoldersForWindow(-1), 0);
    expect(calcWaveHoldersForWindow(0.8), 2);
    expect(calcWaveHoldersForWindow(1.0), 2);
    expect(calcWaveHoldersForWindow(1.01), 3);
    expect(calcWaveHoldersForWindow(2.5), 3);
    expect(calcWaveHoldersForWindow(2.51), 4);
    expect(calcWaveHoldersForWindow(3.5), 4);
    expect(calcWaveHoldersForWindow(4.5), 5);
  });

  test('تقريب الأمتار لا يتأثر بأخطاء الفاصلة', () {
    expect(ceilMeters(3 * 1.1), 4);
    expect(ceilMeters(10.5 * 2), 21);
    expect(parseNumber('٢٫٥'), 2.5);
  });
}
