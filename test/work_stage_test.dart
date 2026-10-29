import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtian_app/core/constants/work_stage.dart';

void main() {
  group('WorkStage.fromData', () {
    test('بيقرا work_stage لو موجود', () {
      expect(WorkStage.fromData({'work_stage': 2}), 2);
      expect(WorkStage.fromData({'work_stage': 3}), 3);
    });

    test('بيقصّ القيم اللي برا المدى ١ إلى ٤', () {
      expect(WorkStage.fromData({'work_stage': 9}), 4);
      expect(WorkStage.fromData({'work_stage': 0}), 1);
      expect(WorkStage.fromData({'work_stage': -3}), 1);
    });

    test('عميل قديم من غير work_stage: تمت = ٤', () {
      expect(WorkStage.fromData({'installation_done': true}), 4);
    });

    test('عميل قديم لسه شغال = ١', () {
      expect(WorkStage.fromData({}), 1);
      expect(WorkStage.fromData({'installation_done': false}), 1);
    });

    test('work_stage مش رقم: بيتجاهل ويرجع للقديم', () {
      expect(
        WorkStage.fromData({'work_stage': 'x', 'installation_done': true}),
        4,
      );
    });
  });

  group('WorkStage.updateFields', () {
    test('مرحلة غير مكتملة: installation_done = false ومفيش وقت تنفيذ', () {
      for (final stage in [1, 2, 3]) {
        final fields = WorkStage.updateFields(stage);
        expect(fields['work_stage'], stage);
        expect(fields['installation_done'], false);
        expect(fields['installation_done_at'], isNull);
      }
    });

    test('المرحلة ٤: installation_done = true ووقت التنفيذ بيتحط', () {
      final fields = WorkStage.updateFields(4, doneAt: 'ts');
      expect(fields['work_stage'], 4);
      expect(fields['installation_done'], true);
      expect(fields['installation_done_at'], 'ts');
    });

    test('مرحلة برا المدى بتتقصّ', () {
      expect(WorkStage.updateFields(0)['work_stage'], 1);
      expect(WorkStage.updateFields(7, doneAt: 'ts')['work_stage'], 4);
    });
  });

  test('كل مرحلة ليها لون واسم', () {
    for (final stage in WorkStage.all) {
      expect(WorkStage.colors[stage], isNotNull);
      expect(WorkStage.labels[stage], isNotEmpty);
    }
  });
}
