import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtains/features/clients/invoice/invoice_calculator.dart';

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
    expect(_line(invoice, 'holder_wave').qty, 18);
    expect(_line(invoice, 'install_window').qty, 6);
    expect(_sum(invoice.accessoryLines), 7395);
    expect(invoice.grandTotal, 14925);
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
    expect(_line(invoice, 'holder_wave').qty, 4);
    expect(_line(invoice, 'holder_double').qty, 3);
    expect(_line(invoice, 'ring_unit').qty, 93);
    expect(_line(invoice, 'cantilever_forgia').qty, 4);
    expect(_sum(invoice.accessoryLines), 6040);
    expect(invoice.grandTotal, 11810);
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

  // قاعدة الحوامل المعتمدة: 1م = 2 • حتى 2.5م = 3 • 3م = 4 • 4م = 5
  test('عدد حوامل الويفي لكل شباك', () {
    expect(calcWaveHoldersForWindow(0.5), 2);
    expect(calcWaveHoldersForWindow(1), 2);
    expect(calcWaveHoldersForWindow(1.75), 3);
    expect(calcWaveHoldersForWindow(2), 3);
    expect(calcWaveHoldersForWindow(2.5), 3);
    expect(calcWaveHoldersForWindow(3), 4);
    expect(calcWaveHoldersForWindow(3.5), 4);
    expect(calcWaveHoldersForWindow(4), 5);
    expect(calcWaveHoldersForWindow(5), 6);
  });

  // ===================== استثناءات القماش =====================

  test('استثناء: إلغاء الثقيل + ويفي خفيف + بلاك أوت تحته', () {
    const windows = [
      WindowSpec(
        title: 'شباك',
        width: 3,
        curtainType: 'wave',
        hasHeavy: false,
        hasLight: true,
        hasBlackout: true,
        blackoutType: 'fabric_blackout3d',
      ),
    ];

    final invoice = calculateApartmentInvoice(windows: windows);

    expect(_line(invoice, 'fabric_linen').qty, 6);
    expect(_line(invoice, 'fabric_blackout3d').qty, 3);
    expect(_line(invoice, 'sew_blackout').qty, 3);
    // تراك واحد بس (الخفيف) + شريط ويفي يتبع الخفيف + مفيش كسرات
    expect(_line(invoice, 'track').qty, 3);
    expect(_line(invoice, 'wave_tape').qty, 6);
    expect(_line(invoice, 'holder_wave').qty, 4);
    expect(() => _line(invoice, 'fabric_velvet'), throwsStateError);
    expect(() => _line(invoice, 'kasrat'), throwsStateError);
  });

  test('استثناء: عرض/نسبة مخصصين لكل طبقة + بلاك أوت عازل', () {
    const windows = [
      WindowSpec(
        width: 4,
        curtainType: 'wave',
        hasHeavy: true,
        hasLight: true,
        heavyWidth: 3,
        heavyRatio: 2,
        lightWidth: 4,
        lightRatio: 3,
        hasBlackout: true,
        blackoutType: 'fabric_blackout_sun',
        blackoutWidth: 2.8,
      ),
    ];

    final invoice = calculateApartmentInvoice(windows: windows);

    expect(_line(invoice, 'fabric_velvet').qty, 6); // 3 × 2
    expect(_line(invoice, 'fabric_linen').qty, 12); // 4 × 3
    expect(_line(invoice, 'fabric_blackout_sun').qty, 3); // 2.8 → 3
    expect(_line(invoice, 'sew_blackout').qty, 3);
    expect(_line(invoice, 'track').qty, 7); // 3 + 4
    expect(_line(invoice, 'wave_tape').qty, 6); // يتبع الثقيل
    expect(_line(invoice, 'kasrat').qty, 12); // يتبع الخفيف
    expect(_line(invoice, 'holder_wave').qty, 5); // أوسع طبقة 4م
    expect(_line(invoice, 'fabric_velvet').note, contains('استثناء'));
    expect(_line(invoice, 'fabric_blackout_sun').note, contains('استثناء'));
  });

  test('استثناء: كبس خفيف بدون ثقيل', () {
    const windows = [
      WindowSpec(
        width: 2,
        curtainType: 'press',
        hasHeavy: false,
        hasLight: true,
      ),
    ];

    final invoice = calculateApartmentInvoice(windows: windows);

    expect(_line(invoice, 'fabric_linen').qty, 4);
    expect(_line(invoice, 'pipe_press').qty, 2);
    expect(_line(invoice, 'cantilever_forgia').qty, 2);
    expect(_line(invoice, 'qamqam_forgia').qty, 2);
    expect(_line(invoice, 'press_tape').qty, 4);
    expect(_line(invoice, 'ring_unit').qty, 28);
    expect(() => _line(invoice, 'fabric_velvet'), throwsStateError);
  });

  test('استثناء: بلاك أوت لوحده من غير ثقيل ولا خفيف', () {
    const windows = [
      WindowSpec(
        width: 2.8,
        curtainType: 'wave',
        hasHeavy: false,
        hasLight: false,
        hasBlackout: true,
      ),
    ];

    final invoice = calculateApartmentInvoice(windows: windows);

    expect(_line(invoice, 'fabric_blackout3d').qty, 3);
    expect(_line(invoice, 'sew_blackout').qty, 3);
    expect(_line(invoice, 'track').qty, 2.8);
    expect(() => _line(invoice, 'wave_tape'), throwsStateError);
  });

  test('القراءة من البيانات المحفوظة: القيم الغايبة = الافتراضي', () {
    final spec = WindowSpec.fromMap({
      'width': 3,
      'method': 'wave',
      'light_layers': 1,
      'velvet_sides': 2,
    });

    expect(spec.hasHeavy, true);
    expect(spec.hasLight, true);
    expect(spec.heavyWidth, isNull);
    expect(spec.lightWidth, isNull);
    expect(spec.hasBlackout, false);
    expect(spec.heavyWidthValue, 3);
    expect(spec.lightWidthValue, 3);
  });
}
