import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// دور المستخدم جوه لوحة الإدارة.
///
/// الدور بيتحدد من حقل `role` في `admins/{uid}` على السيرفر.
/// **غياب الحقل = owner** عشان كل الحسابات القديمة تفضل شغالة زي ما هي.
enum AdminRole {
  /// صاحب المحل: كل حاجة
  owner,

  /// مدير: كل حاجة ما عدا الأسعار والنسخ الاحتياطي وحذف صور المعرض
  manager,

  /// فني: يقيس ويغيّر مراحل الشغل، من غير فلوس ولا أسعار ولا معرض
  worker;

  String get label {
    switch (this) {
      case AdminRole.owner:
        return 'صاحب المحل';
      case AdminRole.manager:
        return 'مدير';
      case AdminRole.worker:
        return 'فني';
    }
  }

  /// تعديل ثوابت الحساب (الأسعار) — للمالك بس.
  bool get canManagePrices => this == AdminRole.owner;

  /// النسخ الاحتياطي والاسترجاع وقناة تليجرام — للمالك بس.
  bool get canManageBackup => this == AdminRole.owner;

  /// حذف صور المعرض نهائيًا — للمالك بس.
  bool get canDeleteGallery => this == AdminRole.owner;

  /// رفع وتعديل صور المعرض — للمالك والمدير.
  bool get canManageGallery => this != AdminRole.worker;

  /// الفاتورة والفلوس — الفني ميشوفهاش (في الواجهة).
  bool get canSeeInvoice => this != AdminRole.worker;

  /// تقارير الأرقام — الفني مش محتاجها.
  bool get canSeeAnalytics => this != AdminRole.worker;
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
    await _restoreRole();
    final status = await _check(refresh: refresh);
    final user = _auth.currentUser;
    if (user == null) return status;
    if (status == AdminStatus.admin) {
      await _remember(user.uid);
    } else if (status == AdminStatus.unknown && !await _isRemembered(user.uid)) {
      // مفيش نت ومحدش أكّد قبل كده إن الحساب ده أدمن: منفتحش لوحة الإدارة.
      return AdminStatus.notAdmin;
    }
    return status;
  }

  static const String _prefKey = 'verified_admin_uid';

  static AdminRole? _cachedRole;

  /// دور المستخدم الحالي. لغاية ما يتقرأ من السيرفر/الكاش = مالك،
  /// وده نفس سلوك النسخ القديمة اللي مفيهاش أدوار.
  static AdminRole get role => _cachedRole ?? AdminRole.owner;

  /// تحويل قيمة حقل `role` لدور معروف.
  /// – فاضي أو مش موجود = مالك (توافق مع الحسابات القديمة)
  /// – أي قيمة غير معروفة = فني (أقل صلاحية، أحسن من منح صلاحية بالغلط)
  static AdminRole parseRole(Object? raw) {
    switch ((raw ?? '').toString().trim().toLowerCase()) {
      case '':
      case 'owner':
        return AdminRole.owner;
      case 'manager':
        return AdminRole.manager;
      case 'worker':
        return AdminRole.worker;
      default:
        return AdminRole.worker;
    }
  }

  static String _rolePrefKey(String uid) => 'admin_role_v1_$uid';

  /// كاش الدور على الجهاز: لوحة الإدارة بتفتح أوفلاين بنفس صلاحيات آخر مرة.
  static Future<void> _restoreRole() async {
    if (_cachedRole != null) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_rolePrefKey(uid));
      if (saved != null && saved.isNotEmpty) {
        _cachedRole = parseRole(saved);
      }
    } catch (_) {}
  }

  static void _applyRole(String uid, Object? raw) {
    final parsed = parseRole(raw);
    if (_cachedRole == parsed) return;
    _cachedRole = parsed;
    unawaited(_saveRole(uid, parsed));
  }

  static Future<void> _saveRole(String uid, AdminRole role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rolePrefKey(uid), role.name);
    } catch (_) {}
  }

  static Future<void> _remember(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, uid);
    } catch (_) {}
  }

  static Future<bool> _isRemembered(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKey) == uid;
    } catch (_) {
      return false;
    }
  }

  static Future<AdminStatus> _check({bool refresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return AdminStatus.signedOut;

    var adminByClaim = false;
    try {
      final token = await user.getIdTokenResult(refresh);
      adminByClaim = token.claims?['admin'] == true;
    } on FirebaseAuthException catch (e) {
      if (_isDeadSession(e.code)) {
        await _auth.signOut();
        return AdminStatus.signedOut;
      }
      // مشكلة شبكة وإحنا بنجدد: نجرّب بالتوكن المخزّن
      if (refresh) return _check(refresh: false);
    } catch (_) {
      if (refresh) return _check(refresh: false);
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();
      if (!doc.exists) {
        return adminByClaim ? AdminStatus.admin : AdminStatus.notAdmin;
      }
      // الدور جاي من نفس المستند اللي بيأكد إنه أدمن.
      _applyRole(user.uid, doc.data()?['role']);
      return AdminStatus.admin;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return AdminStatus.notAdmin;
      // مفيش نت: لو الـ claim بيقول أدمن نكمّل، والدور بيتقرأ من الكاش.
      return adminByClaim ? AdminStatus.admin : AdminStatus.unknown;
    } catch (_) {
      return adminByClaim ? AdminStatus.admin : AdminStatus.unknown;
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

  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}
    _cachedRole = null;
    await _auth.signOut();
  }
}
