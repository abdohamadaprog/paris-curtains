import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// مراحل الشغل مع العميل — مصدر واحد للألوان والأسماء ومنطق الحفظ.
///
/// ١ أحمر: بدأنا الشغل
/// ٢ أصفر: جاري التحضير
/// ٣ أزرق: تم التخريم وجاهز للتركيب
/// ٤ أخضر: تمت وتم التركيب
class WorkStage {
  WorkStage._();

  static const int started = 1;
  static const int preparing = 2;
  static const int drilled = 3;
  static const int done = 4;

  static const List<int> all = [started, preparing, drilled, done];

  static const Map<int, Color> colors = {
    started: Color(0xFFFF4D5E),
    preparing: Color(0xFFFFD43B),
    drilled: Color(0xFF38BDF8),
    done: Color(0xFF22E58B),
  };

  static const Map<int, String> labels = {
    started: 'بدأنا الشغل',
    preparing: 'جاري التحضير',
    drilled: 'تم التخريم وجاهز للتركيب',
    done: 'تمت وتم التركيب',
  };

  /// مرحلة العميل من مستنده. العملاء القدام (من غير work_stage) بنحددها من
  /// installation_done: تمت = ٤، وغير كده = ١.
  static int fromData(Map<String, dynamic> data) {
    final raw = data['work_stage'];
    if (raw is num) return raw.toInt().clamp(started, done);
    return data['installation_done'] == true ? done : started;
  }

  /// الحقول اللي بتتكتب في Firestore لما المرحلة تتغيّر.
  /// بنحدّث installation_done كمان عشان الأجندة والتقارير تفضل شغالة.
  ///
  /// [doneAt]: وقت التنفيذ لو عايز تحدده بنفسك (الافتراضي: وقت السيرفر).
  static Map<String, dynamic> updateFields(int stage, {Object? doneAt}) {
    final s = stage.clamp(started, done);
    return {
      'work_stage': s,
      'installation_done': s == done,
      'installation_done_at': s == done
          ? (doneAt ?? FieldValue.serverTimestamp())
          : null,
    };
  }
}
