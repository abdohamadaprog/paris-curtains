import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// حالة المستخدم الحالي بالنسبة للوحة الإدارة
enum AdminStatus {
  /// مفيش جلسة Firebase (أو الجلسة انتهت/اتلغت)
  signedOut,

  /// مسجّل دخول وهو أدمن (custom claim أو مستند admins/{uid})
  admin,

  /// مسجّل دخول لكن مش أدمن
  notAdmin,

  /// مقدرناش نتأكد (غالبًا مفيش نت). الأمان الحقيقي على السيرفر (Rules).
  unknown,
}

/// التحقق من صلاحية الأدمن من غير أي إيميل مكتوب في الكود.
///
/// الصلاحية بتتمنح من السيرفر بس:
///  1) custom claim اسمه `admin` على حساب المستخدم، أو
///  2) مستند `admins/{uid}` في Firestore (بيتعمل من الـ Console).
/// وقواعد Firestore بتفرض نفس الشرط، فالفحص هنا لراحة الواجهة بس.
class AdminAuthService {
  AdminAuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  /// [refresh] = true بيجدّد التوكن من السيرفر (بيكشف الجلسة الملغية
  /// أو الحساب المعطّل، وبيجيب الـ claims الأحدث).
  static Future<AdminStatus> check({bool refresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return AdminStatus.signedOut;

    try {
      final token = await user.getIdTokenResult(refresh);
      if (token.claims?['admin'] == true) return AdminStatus.admin;
    } on FirebaseAuthException catch (e) {
      if (_isDeadSession(e.code)) {
        await _auth.signOut();
        return AdminStatus.signedOut;
      }
      // مشكلة شبكة وإحنا بنجدد: نجرّب بالتوكن المخزّن
      if (refresh) return check(refresh: false);
    } catch (_) {
      if (refresh) return check(refresh: false);
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();
      return doc.exists ? AdminStatus.admin : AdminStatus.notAdmin;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return AdminStatus.notAdmin;
      return AdminStatus.unknown;
    } catch (_) {
      return AdminStatus.unknown;
    }
  }

  /// مسموح يدخل لوحة الإدارة؟ (unknown = مفيش نت، ندخله والسيرفر هو اللي بيحمي)
  static bool canEnter(AdminStatus status) =>
      status == AdminStatus.admin || status == AdminStatus.unknown;

  static bool _isDeadSession(String code) =>
      code == 'user-token-expired' ||
      code == 'user-disabled' ||
      code == 'user-not-found' ||
      code == 'invalid-user-token' ||
      code == 'requires-recent-login';

  static Future<void> signOut() => _auth.signOut();
}
