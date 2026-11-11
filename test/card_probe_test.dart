import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtains/card_probe.dart';

void main() {
  testWidgets('probe renders without exception', (tester) async {
    await tester.pumpWidget(const CardProbeApp());
    await tester.pump(const Duration(milliseconds: 300));
    final ex = tester.takeException();
    // ignore: avoid_print
    print('EXCEPTION => $ex');
    expect(ex, isNull);
  });
}
