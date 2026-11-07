import 'package:flutter/material.dart';

import '../constants/work_stage.dart';

const String _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

String _arabicNumber(int n) => n.toString().replaceAllMapped(
  RegExp(r'[0-9]'),
  (m) => _arabicDigits[int.parse(m[0]!)],
);

/// الشكل اللي بيظهر جوه دايرة المرحلة: رقم المرحلة (١–٤)، وعلامة ✕ لو ملغي.
Widget stageMark(int stage, Color color, {double size = 18}) {
  if (WorkStage.isCancelled(stage)) {
    return Icon(Icons.close_rounded, color: color, size: size + 4);
  }
  return Text(
    _arabicNumber(stage),
    style: TextStyle(
      color: color,
      fontWeight: FontWeight.w900,
      fontSize: size,
    ),
  );
}

/// نص المرحلة في القوايم: "٢ • جاري التحضير" أو "ملغي" من غير رقم.
String stageMenuLabel(int stage) {
  final label = WorkStage.labels[stage] ?? '';
  return WorkStage.isCancelled(stage)
      ? label
      : '${_arabicNumber(stage)} • $label';
}

/// تأكيد إلغاء الشغلانة قبل ما تتحفظ (عشان الضغطة الغلط متبوّظش شغل عميل).
/// بترجّع true لو المستخدم أكّد.
Future<bool> confirmCancelWork(
  BuildContext context, {
  String? clientName,
}) async {
  final name = (clientName ?? '').trim();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('إلغاء الشغلانة؟'),
      content: Text(
        name.isEmpty
            ? 'هتتحط الشغلانة على إنها ملغية ومش هتظهر في الأجندة. '
                  'تقدر ترجّعها لأي مرحلة بعدين.'
            : 'شغلانة "$name" هتتحط على إنها ملغية ومش هتظهر في الأجندة. '
                  'تقدر ترجّعها لأي مرحلة بعدين.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('لأ، سيبها'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: WorkStage.colors[WorkStage.cancelled],
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('أيوه، ألغيها'),
        ),
      ],
    ),
  );
  return ok == true;
}
