import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/work_stage.dart';
import '../../clients/list/clients_list_page.dart';
import '../../auth/login_page.dart';
import '../../home/home_screen.dart';
import 'gallery_reorder_page.dart';

import '../../auth/admin_auth_service.dart';
import '../../clients/invoice/price_settings_page.dart';
import '../../../core/config/app_features.dart';
import '../../../core/services/notification_service.dart';
import '../services/local_backup_service.dart';
import '../../../core/widgets/sync_status_banner.dart';
import 'backup_page.dart';
import 'telegram_backup_page.dart';
import 'admin_analytics_page.dart';
import 'upload_image_page.dart';
import 'gallery_management_page.dart';
import 'installation_agenda_page.dart';
import 'promo_management_page.dart';
import 'upload_queue_page.dart';
import 'featured_works_page.dart';

part 'dashboard_stage_strip.dart';
part 'dashboard_widgets.dart';

String _ar(Object? n) => (n ?? '').toString().replaceAllMapped(
  RegExp(r'[0-9]'),
  (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
);

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _stageRefresh = 0;
  final LocalAuthentication auth = LocalAuthentication();

  // نفس ألوان الفاتورة والمقاسات
  static Color get _bg => AppPalette.bg;
  static Color get _panel => AppPalette.panel;
  static Color get _panel2 => AppPalette.panel2;
  static Color get _line => AppPalette.line;
  static Color get _gold => AppPalette.gold;
  static Color get _sky => AppPalette.sky;
  static Color get _violet => AppPalette.violet;
  static Color get _green => AppPalette.green;
  static Color get _white => AppPalette.text;
  static Color get _muted => AppPalette.muted;

  @override
  void initState() {
    super.initState();
    // لوحة الإدارة مبتتفتحش من غير جلسة أدمن سليمة (حتى لو اتفتحت بالبصمة)
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifySession());
  }

  /// الوضع المجاني: لو عدّى أسبوع من آخر نسخة يدوية، نفكّر الأدمن.
  Future<void> _maybeRemindBackup() async {
    final last = await LocalBackupService.lastBackupAt();
    final stale =
        last == null || DateTime.now().difference(last) > const Duration(days: 7);
    if (!stale || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(
          last == null
              ? 'لسه معملتش نسخة احتياطية لبياناتك. اعمل واحدة دلوقتي.'
              : 'عدّى أكتر من أسبوع على آخر نسخة احتياطية.',
          textAlign: TextAlign.center,
        ),
        action: SnackBarAction(
          label: 'نسخة الآن',
          onPressed: () => _navTo(const BackupPage()),
        ),
      ),
    );
  }

  Future<void> _verifySession() async {
    final status = await AdminAuthService.check();
    if (!mounted) return;
    if (AdminAuthService.canEnter(status)) {
      if (AppFeatures.cloudFunctionsEnabled) {
        // تسجيل جهاز الأدمن لتنبيهات الأجندة (بيطلب إذن الإشعارات أول مرة)
        NotificationService.registerAdminDevice();
      } else {
        _maybeRemindBackup();
      }
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _signOut() async {
    await AdminAuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // يعيد البناء عند تغيير الثيم
    return Scaffold(
      backgroundColor: _bg,
      // زرار عايم: عميل جديد من أول شاشة بضغطة واحدة
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navTo(const ClientsListPage(autoAdd: true)),
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
        label: const Text(
          'عميل جديد',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            const SliverToBoxAdapter(child: SyncStatusBanner()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildWelcome(),
                  const SizedBox(height: 22),
                  _sectionTitle('حالة الشغل', Icons.local_fire_department_rounded),
                  const SizedBox(height: 12),
                  _StageStrip(
                    refreshToken: _stageRefresh,
                    onTapStage: (stage) =>
                        _navTo(ClientsListPage(initialStage: stage)),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('الوصول السريع', Icons.bolt_rounded),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 520 ? 4 : 2;
                      final itemWidth =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      Widget tile(
                        String title,
                        String sub,
                        IconData icon,
                        Color color,
                        Widget page,
                      ) => SizedBox(
                        width: itemWidth,
                        child: _QuickAction(
                          title: title,
                          subtitle: sub,
                          icon: icon,
                          color: color,
                          onTap: () => _navTo(page),
                        ),
                      );
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          tile(
                            'العملاء',
                            'المقاسات والفواتير',
                            Icons.groups_rounded,
                            _sky,
                            const ClientsListPage(),
                          ),
                          tile(
                            'الأجندة',
                            'مواعيد التركيب',
                            Icons.event_available_rounded,
                            _violet,
                            const InstallationAgendaPage(),
                          ),
                          tile(
                            'إضافة عمل',
                            'صور للمعرض',
                            Icons.add_photo_alternate_rounded,
                            _gold,
                            const UploadImagePage(),
                          ),
                          tile(
                            'التقارير',
                            'أرقام الشغل',
                            Icons.insights_rounded,
                            _green,
                            const AdminAnalyticsPage(),
                          ),
                          tile(
                            'ثوابت الحساب',
                            'أسعار الفواتير',
                            Icons.price_change_rounded,
                            _gold,
                            const PriceSettingsPage(),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  _sectionTitle(
                    'المعرض والمحتوى',
                    Icons.photo_library_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildGroup([
                    _GroupRow(
                      title: 'أحدث الأعمال',
                      subtitle: '٢٥ صورة مميزة في الواجهة الرئيسية',
                      icon: Icons.auto_awesome_rounded,
                      color: _gold,
                      onTap: () => _navTo(const FeaturedWorksPage()),
                    ),
                    _GroupRow(
                      title: 'إدارة المعرض',
                      subtitle: 'تعديل وحذف صور المعرض',
                      icon: Icons.collections_rounded,
                      color: _sky,
                      onTap: () => _navTo(const GalleryManagementPage()),
                    ),
                    _GroupRow(
                      title: 'ترتيب الصور',
                      subtitle: 'تغيير ترتيب ظهور الصور',
                      icon: Icons.swap_vert_rounded,
                      color: _violet,
                      onTap: () => _navTo(const GalleryReorderPage()),
                    ),
                    _GroupRow(
                      title: 'السلايدر والعروض',
                      subtitle: 'صور البانر العلوي',
                      icon: Icons.view_carousel_rounded,
                      color: _gold,
                      onTap: () => _navTo(const PromoManagementPage()),
                    ),
                    _GroupRow(
                      title: 'متابعة رفع الصور',
                      subtitle: 'طابور الرفع وإعادة المحاولة',
                      icon: Icons.cloud_upload_rounded,
                      color: _green,
                      onTap: () => _navTo(const UploadQueuePage()),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _sectionTitle('الأمان', Icons.admin_panel_settings_rounded),
                  const SizedBox(height: 12),
                  _buildGroup([
                    _GroupRow(
                      title: 'النسخ الاحتياطي والأرشيف',
                      subtitle: AppFeatures.cloudFunctionsEnabled
                          ? 'نسخة تلقائية يوميًا واسترجاع العملاء المحذوفين'
                          : 'نسخة احتياطية يدوية واسترجاع العملاء المحذوفين',
                      icon: Icons.cloud_done_rounded,
                      color: _green,
                      onTap: () => _navTo(const BackupPage()),
                    ),
                    _GroupRow(
                      title: 'نسخة تليجرام',
                      subtitle: 'صور المعرض والمقاسات والفواتير على قناتك',
                      icon: Icons.send_rounded,
                      color: _sky,
                      onTap: () => _navTo(const TelegramBackupPage()),
                    ),
                    _GroupRow(
                      title: 'أمان التطبيق',
                      subtitle: 'البصمة لحماية لوحة الإدارة',
                      icon: Icons.fingerprint_rounded,
                      color: _gold,
                      onTap: _showSecurityDialog,
                    ),
                    _GroupRow(
                      title: 'تسجيل الخروج',
                      subtitle: 'إنهاء الجلسة وقفل لوحة الإدارة',
                      icon: Icons.logout_rounded,
                      color: AppColors.danger,
                      onTap: _signOut,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _buildHomeButton(),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'PARIS CURTAINS • ADMIN',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.shield_rounded, color: _gold, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لوحة تحكم باريس للستائر',
                  style: TextStyle(
                    fontFamily: 'Aref Ruqaa',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _gold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'المحتوى • العملاء • التركيبات',
                  style: TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),
          Text(
            _ar('${now.day}/${now.month}/${now.year}'),
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold, width: 1.5),
            ),
            child: Container(
              width: 46,
              height: 46,
              color: _gold.withValues(alpha: 0.2),
              child: Icon(Icons.person, color: _gold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً بك، م/ عبده حمادة',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: _white,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'كل بيانات المعرض والعملاء والورشة جاهزة',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: _gold),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: _white,
          ),
        ),
      ],
    );
  }

  /// مجموعة صفوف جوه كارت واحد بفواصل (بدل كارت لكل حاجة)
  Widget _buildGroup(List<_GroupRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(color: _line, height: 1, indent: 66, endIndent: 14),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _buildHomeButton() {
    return InkWell(
      onTap: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _panel2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_rounded, color: _gold, size: 20),
            SizedBox(width: 8),
            Text(
              'الرجوع للواجهة الرئيسية للتطبيق',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بيفتح الصفحة، ولما نرجع منها بنحدّث عدّاد المراحل
  /// (لأن العدّاد بقى count() مش stream حي على كل العملاء).
  Future<void> _navTo(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() => _stageRefresh++);
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _panel,
        title: Text(
          'أمان التطبيق',
          style: TextStyle(color: _gold, fontFamily: 'Cairo'),
        ),
        content: FutureBuilder<bool>(
          future: SharedPreferences.getInstance().then(
            (prefs) => prefs.getBool('biometric_enabled') ?? false,
          ),
          builder: (context, snapshot) {
            bool isEnabled = snapshot.data ?? false;
            return StatefulBuilder(
              builder: (context, setStateDialog) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'الدخول بالبصمة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: _white,
                      fontSize: 13,
                    ),
                  ),
                  activeThumbColor: _gold,
                  value: isEnabled,
                  onChanged: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : (value) async {
                          final success = await _toggleBiometrics(value);
                          if (success) {
                            setStateDialog(() {
                              isEnabled = value;
                            });
                          }
                        },
                );
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إغلاق',
              style: TextStyle(color: _gold, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _toggleBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      final user = AdminAuthService.currentUser;
      if (user == null) {
        _showSnack('سجّل دخول بالبريد الأول', AppColors.danger);
        return false;
      }
      try {
        final canCheck = await auth.canCheckBiometrics;
        final isSupported = await auth.isDeviceSupported();
        if (!mounted) return false;
        if (!canCheck && !isSupported) {
          _showSnack('البصمة غير متاحة على هذا الجهاز', AppColors.danger);
          return false;
        }
        final authenticated = await auth.authenticate(
          localizedReason: 'تأكيد الهوية لتفعيل البصمة',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (!authenticated) return false;
        // نربط البصمة بالحساب المسجّل دخول دلوقتي (بتفتح قفل جلسته بس)
        await prefs.setBool('biometric_enabled', true);
        await prefs.setString('biometric_uid', user.uid);
        if (mounted) {
          _showSnack('تم تفعيل البصمة بنجاح', _green);
        }
        return true;
      } catch (_) {
        if (mounted) {
          _showSnack('تعذر تفعيل البصمة على هذا الجهاز', AppColors.danger);
        }
        return false;
      }
    } else {
      await prefs.setBool('biometric_enabled', false);
      await prefs.remove('biometric_uid');
      if (mounted) {
        _showSnack('تم إلغاء تفعيل البصمة', _gold);
      }
      return true;
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _panel2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        content: Text(
          message,
          style: TextStyle(fontFamily: 'Cairo', color: _white),
        ),
      ),
    );
  }
}
