import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// مراحل الشغل مع العميل — مصدر واحد للألوان والأسماء ومنطق الحفظ.
///
/// ١ أحمر: بدأنا الشغل
/// ٢ أصفر: جاري التحضير
/// ٣ أزرق: تم التخريم وجاهز للتركيب
/// ٤ أخضر: تمت وتم التركيب
/// ٥ رمادي: ملغي (الشغلانة اتلغت)
///
/// المرحلة ٥ مش جزء من مسار الشغل (١ ← ٤): هي حالة نهائية بتتحط على أي
/// عميل في أي وقت، وبترجع منها لأي مرحلة لو العميل غيّر رأيه.
class WorkStage {
  WorkStage._();

  static const int started = 1;
  static const int preparing = 2;
  static const int drilled = 3;
  static const int done = 4;
  static const int cancelled = 5;

  /// كل المراحل بالترتيب (المسار ثم الإلغاء).
  static const List<int> all = [started, preparing, drilled, done, cancelled];

  /// مراحل المسار الطبيعي بس (من غير الإلغاء).
  static const List<int> flow = [started, preparing, drilled, done];

  static const Map<int, Color> colors = {
    started: Color(0xFFFF4D5E),
    preparing: Color(0xFFFFD43B),
    drilled: Color(0xFF38BDF8),
    done: Color(0xFF22E58B),
    cancelled: Color(0xFF8E99A8),
  };

  static const Map<int, String> labels = {
    started: 'بدأنا الشغل',
    preparing: 'جاري التحضير',
    drilled: 'تم التخريم وجاهز للتركيب',
    done: 'تمت وتم التركيب',
    cancelled: 'ملغي',
  };

  /// اسم مختصر للأماكن الضيقة (شريط الداشبورد والفلاتر).
  static const Map<int, String> shortLabels = {
    started: 'بدأنا الشغل',
    preparing: 'تحضير',
    drilled: 'جاهز للتركيب',
    done: 'تمت',
    cancelled: 'ملغي',
  };

  /// الشغلانة اتلغت؟
  static bool isCancelled(int stage) => stage == cancelled;

  /// الشغلانة لسه شغالة (لا خلصت ولا اتلغت)؟
  static bool isOpen(int stage) => stage < done;

  /// مرحلة العميل من مستنده. العملاء القدام (من غير work_stage) بنحددها من
  /// installation_done: تمت = ٤، وغير كده = ١.
  ///
  /// القواعد (firestore.rules) بتمنع أي قيمة برا ١–٥، والـ clamp هنا حماية
  /// إضافية بس.
  static int fromData(Map<String, dynamic> data) {
    final raw = data['work_stage'];
    if (raw is num) return raw.toInt().clamp(started, cancelled);
    return data['installation_done'] == true ? done : started;
  }

  /// الحقول اللي بتتكتب في Firestore لما المرحلة تتغيّر.
  /// بنحدّث installation_done كمان عشان الأجندة والتقارير تفضل شغالة.
  ///
  /// - المرحلة ٤: installation_done = true ووقت التنفيذ.
  /// - المرحلة ٥ (ملغي): installation_done = false ووقت الإلغاء في
  ///   cancelled_at (عشان العميل الملغي ميتحسبش "تم" ولا "شغال").
  /// - أي مرحلة تانية: بنمسح cancelled_at لو العميل كان ملغي قبل كده.
  ///
  /// [doneAt]: وقت التنفيذ لو عايز تحدده بنفسك (الافتراضي: وقت السيرفر).
  /// [forCreate]: لازم تبقى true لما الحقول رايحة لمستند جديد (`add`)،
  /// لأن `FieldValue.delete()` مينفعش غير مع update/set(merge).
  static Map<String, dynamic> updateFields(
    int stage, {
    Object? doneAt,
    bool forCreate = false,
  }) {
    final s = stage.clamp(started, cancelled);
    return {
      'work_stage': s,
      'installation_done': s == done,
      'installation_done_at': s == done
          ? (doneAt ?? FieldValue.serverTimestamp())
          : null,
      if (s == cancelled)
        'cancelled_at': FieldValue.serverTimestamp()
      else if (!forCreate)
        'cancelled_at': FieldValue.delete(),
    };
  }
}
