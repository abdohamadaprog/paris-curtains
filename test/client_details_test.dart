import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtian_app/features/clients/data/client_details_repository.dart';

void main() {
  group('ClientDetails.fromMap', () {
    test('بيقرا القوائم الثلاث', () {
      final d = ClientDetails.fromMap({
        'measurements': [
          {'name': 'الصالون', 'width': 3.0},
        ],
        'balconies': [
          {'parts': '3+2'},
          {'parts': '4'},
        ],
        'deleted_cards': [
          {'type': 'measurement'},
        ],
      });
      expect(d.measurements.length, 1);
      expect(d.balconies.length, 2);
      expect(d.deletedCards.length, 1);
      expect(d.isLegacy, false);
    });

    test('بيتجاهل العناصر اللي مش Map وبيتحمّل الحقول الناقصة', () {
      final d = ClientDetails.fromMap({
        'measurements': [
          {'name': 'ok'},
          'bad',
          3,
          null,
        ],
        'balconies': 'not a list',
      });
      expect(d.measurements.length, 1);
      expect(d.balconies, isEmpty);
      expect(d.deletedCards, isEmpty);
    });

    test('علامة القديم (legacy) بتتنقل', () {
      expect(ClientDetails.fromMap({}, isLegacy: true).isLegacy, true);
    });
  });

  group('ClientDetails.isEmpty و signature', () {
    test('فاضي لو مفيش أي بيانات', () {
      expect(const ClientDetails().isEmpty, true);
      expect(
        ClientDetails.fromMap({
          'measurements': [
            {'name': 'x'},
          ],
        }).isEmpty,
        false,
      );
    });

    test('نفس البيانات = نفس البصمة، واختلاف بسيط = بصمة مختلفة', () {
      final a = ClientDetails.fromMap({
        'measurements': [
          {'name': 'الصالون', 'width': 3.0},
        ],
      });
      final b = ClientDetails.fromMap({
        'measurements': [
          {'name': 'الصالون', 'width': 3.0},
        ],
      });
      final c = ClientDetails.fromMap({
        'measurements': [
          {'name': 'الصالون', 'width': 3.05},
        ],
      });
      expect(a.signature, b.signature);
      expect(a.signature, isNot(c.signature));
    });
  });
}
