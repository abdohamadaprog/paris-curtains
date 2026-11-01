import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// تنبيهات أجندة التركيب (إشعارات Firebase).
///
/// الأدمن لما يفتح لوحة الإدارة، التطبيق بيسجّل توكن جهازه في admin_devices،
/// والـ Cloud Functions (agendaEvening / agendaMorning) بتبعت لكل الأجهزة دي:
/// تركيبات بكرة الساعة ٧ مساءً، وتركيبات النهاردة الساعة ٨ صباحًا.
class NotificationService {
  NotificationService._();

  static bool _listening = false;

  /// بتطلب إذن الإشعارات (أندرويد ١٣+) وتسجّل توكن الجهاز. مبترميش أخطاء.
  static Future<void> registerAdminDevice() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notifications permission denied');
        return;
      }

      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);

      if (!_listening) {
        _listening = true;
        messaging.onTokenRefresh.listen(_saveToken);
      }
    } catch (e) {
      debugPrint('registerAdminDevice failed: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('admin_devices')
          .doc(token)
          .set({
            'token': token,
            'uid': user.uid,
            'platform': defaultTargetPlatform.name,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Saving FCM token failed: $e');
    }
  }
}
