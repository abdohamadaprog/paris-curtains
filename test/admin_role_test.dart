// اختبارات الأدوار: مين يقدر يشوف/يعدّل إيه جوه لوحة الإدارة.
//
// الدور مخزّن في حقل `role` داخل admins/{uid}. الأهم: الحسابات القديمة
// اللي مفيهاش الحقل تفضل "صاحب المحل" زي ما كانت.

import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtains/features/auth/admin_auth_service.dart';

void main() {
  group('parseRole', () {
    test('غياب الدور = صاحب المحل (توافق مع الحسابات القديمة)', () {
      expect(AdminAuthService.parseRole(null), AdminRole.owner);
      expect(AdminAuthService.parseRole(''), AdminRole.owner);
      expect(AdminAuthService.parseRole('   '), AdminRole.owner);
      expect(AdminAuthService.parseRole('owner'), AdminRole.owner);
    });

    test('الأدوار المعروفة بتتقرا صح مهما كان حالة الحروف والمسافات', () {
      expect(AdminAuthService.parseRole('manager'), AdminRole.manager);
      expect(AdminAuthService.parseRole('Manager '), AdminRole.manager);
      expect(AdminAuthService.parseRole('WORKER'), AdminRole.worker);
    });

    test('أي قيمة غريبة = فني (أقل صلاحية) مش مالك', () {
      expect(AdminAuthService.parseRole('superadmin'), AdminRole.worker);
      expect(AdminAuthService.parseRole(123), AdminRole.worker);
    });
  });

  group('صلاحيات صاحب المحل', () {
    const role = AdminRole.owner;
    test('كل حاجة', () {
      expect(role.canManagePrices, isTrue);
      expect(role.canManageBackup, isTrue);
      expect(role.canDeleteGallery, isTrue);
      expect(role.canManageGallery, isTrue);
      expect(role.canSeeInvoice, isTrue);
      expect(role.canSeeAnalytics, isTrue);
    });
  });

  group('صلاحيات المدير', () {
    const role = AdminRole.manager;
    test('شغل العملاء والمعرض بدون أسعار ولا حذف ولا نسخ احتياطي', () {
      expect(role.canManagePrices, isFalse);
      expect(role.canManageBackup, isFalse);
      expect(role.canDeleteGallery, isFalse);
      expect(role.canManageGallery, isTrue);
      expect(role.canSeeInvoice, isTrue);
      expect(role.canSeeAnalytics, isTrue);
    });
  });

  group('صلاحيات الفني', () {
    const role = AdminRole.worker;
    test('مقاسات ومراحل بس: مفيش فلوس ولا أسعار ولا معرض', () {
      expect(role.canManagePrices, isFalse);
      expect(role.canManageBackup, isFalse);
      expect(role.canDeleteGallery, isFalse);
      expect(role.canManageGallery, isFalse);
      expect(role.canSeeInvoice, isFalse);
      expect(role.canSeeAnalytics, isFalse);
    });
  });

  test('كل دور له اسم عربي', () {
    for (final role in AdminRole.values) {
      expect(role.label, isNotEmpty);
    }
  });
}
