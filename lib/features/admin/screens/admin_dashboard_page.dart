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

import '../../auth/admin_auth_service.dart';
import '../../clients/invoice/price_settings_page.dart';
import '../../../core/config/app_features.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sync_status_service.dart';
import '../../../core/utils/digits.dart';
import '../services/local_backup_service.dart';
import '../../../core/widgets/sync_status_banner.dart';
import 'backup_page.dart';
import 'telegram_backup_page.dart';
import 'admin_analytics_page.dart';
import 'gallery_hub_page.dart';
import 'installation_agenda_page.dart';

part 'dashboard_stage_strip.dart';
part 'dashboard_widgets.dart';

String _ar(Object? n) => toArabicDigits(n);

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  /// عدّادات المراحل + مواعيد النهارده. null = لسه بيتحمّل.
  Map<int, int>? _stageCounts;
  int _appointmentsToday = 0;
  int _openJobs = 0;
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
    _loadCounts();
    // لوحة الإدارة مبتتفتحش من غير جلسة أدمن سليمة (حتى لو اتفتحت بالبصمة)
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifySession());
  }

  /// أرقام الداشبورد كلها من count() (قراءة واحدة تقريبًا لكل ١٠٠٠ مستند)
  /// بدل تحميل كل العملاء. العملاء القدام من غير work_stage بيتحسبوا:
  /// تمت = installation_done، والباقي = مرحلة ١ (نفس WorkStage.fromData).
  Future<void> _loadCounts() async {
    try {
      final col = FirebaseFirestore.instance.collection('clients');
      final now = DateTime.now();
      final dayStart = Timestamp.fromDate(
        DateTime(now.year, now.month, now.day),
      );
      final dayEnd = Timestamp.fromDate(
        DateTime(now.year, now.month, now.day + 1),
      );
      final results = await Future.wait([
        col.count().get(),
        col.where('work_stage', isEqualTo: WorkStage.preparing).count().get(),
        col.where('work_stage', isEqualTo: WorkStage.drilled).count().get(),
        col.where('installation_done', isEqualTo: true).count().get(),
        col.where('work_stage', isEqualTo: WorkStage.cancelled).count().get(),
        col
            .where('installation_date', isGreaterThanOrEqualTo: dayStart)
            .where('installation_date', isLessThan: dayEnd)
            .count()
            .get(),
      ]);
      final total = results[0].count ?? 0;
      final preparing = results[1].count ?? 0;
      final drilled = results[2].count ?? 0;
      final done = results[3].count ?? 0;
      final cancelled = results[4].count ?? 0;
      final started = total - preparing - drilled - done - cancelled;
      final open = total - done - cancelled;
      if (!mounted) return;
      setState(() {
        _stageCounts = {
          1: started < 0 ? 0 : started,
          2: preparing,
          3: drilled,
          4: done,
          5: cancelled,
        };
        _appointmentsToday = results[5].count ?? 0;
        _openJobs = open < 0 ? 0 : open;
      });
    } catch (_) {
      // لو فشل (مفيش نت) بنسيب القيم القديمة أو "…"
    }
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
                  const SizedBox(height: 16),
                  _TodaySummary(
                    loading: _stageCounts == null,
                    appointments: _appointmentsToday,
                    openJobs: _openJobs,
                    onTapAppointments: () =>
                        _navTo(const InstallationAgendaPage()),
                    onTapOpenJobs: () => _navTo(const ClientsListPage()),
                    onTapPending: _showPendingInfo,
                  ),
                  const SizedBox(height: 22),
                  _sectionTitle('حالة الشغل', Icons.local_fire_department_rounded),
                  const SizedBox(height: 12),
                  _StageStrip(
                    counts: _stageCounts,
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
                            'عميل جديد',
                            'تسجيل مقاسات من أول خطوة',
                            Icons.person_add_alt_1_rounded,
                            _gold,
                            const ClientsListPage(autoAdd: true),
                          ),
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
                            'التقارير',
                            'أرقام الشغل',
                            Icons.insights_rounded,
                            _green,
                            const AdminAnalyticsPage(),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  _sectionTitle('إدارة', Icons.settings_rounded),
                  const SizedBox(height: 12),
                  _buildGroup([
                    _GroupRow(
                      title: 'المعرض والمحتوى',
                      subtitle: 'رفع الصور والترتيب والسلايدر',
                      icon: Icons.photo_library_rounded,
                      color: _gold,
                      onTap: () => _navTo(const GalleryHubPage()),
                    ),
                    _GroupRow(
                      title: 'ثوابت الحساب',
                      subtitle: 'أسعار الفواتير',
                      icon: Icons.price_change_rounded,
                      color: _sky,
                      onTap: () => _navTo(const PriceSettingsPage()),
                    ),
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
                  ]),
                  const SizedBox(height: 18),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
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
          PopupMenuButton<String>(
            tooltip: 'القائمة',
            color: _panel,
            icon: Icon(Icons.more_vert_rounded, color: _muted),
            onSelected: (value) {
              switch (value) {
                case 'search':
                  _openSearch();
                case 'security':
                  _showSecurityDialog();
                case 'home':
                  _goHome();
                case 'logout':
                  _signOut();
              }
            },
            itemBuilder: (_) => [
              _menuItem('search', Icons.search_rounded, 'بحث عن عميل', _sky),
              _menuItem(
                'security',
                Icons.fingerprint_rounded,
                'أمان التطبيق (البصمة)',
                _gold,
              ),
              _menuItem(
                'home',
                Icons.storefront_rounded,
                'الواجهة الرئيسية',
                _violet,
              ),
              _menuItem(
                'logout',
                Icons.logout_rounded,
                'تسجيل الخروج',
                AppColors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: _white,
            ),
          ),
        ],
      ),
    );
  }

  /// بحث سريع: بتكتب اسم العميل أو رقمه، وبيفتح قائمة العملاء على النتيجة.
  Future<void> _openSearch() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: Row(
          children: [
            Icon(Icons.search_rounded, color: _gold, size: 20),
            const SizedBox(width: 8),
            Text(
              'بحث عن عميل',
              style: TextStyle(
                color: _gold,
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
          style: TextStyle(color: _white, fontFamily: 'Cairo'),
          decoration: InputDecoration(
            hintText: 'الاسم أو رقم التليفون',
            hintStyle: TextStyle(color: _muted, fontFamily: 'Cairo'),
            filled: true,
            fillColor: _panel2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _line),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('إلغاء', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text('بحث', style: TextStyle(color: _gold)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || query == null) return;
    await _navTo(ClientsListPage(initialQuery: query));
  }

  /// تعديلات مستنية الرفع: تطمين + إمكانية المحاولة دلوقتي.
  void _showPendingInfo() {
    final sync = SyncStatus.instance;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: Text(
          'التعديلات المستنية',
          style: TextStyle(color: _gold, fontFamily: 'Cairo'),
        ),
        content: Text(
          sync.hasPending
              ? '${_ar(sync.pendingCount)} تعديل اتحفظ على الجهاز ولسه ماوصلش للسيرفر.\n'
                    'هيترفع لوحده أول ما النت يرجع — متقلقش، بياناتك مش ضايعة.'
              : 'كل حاجة متزامنة مع السيرفر. مفيش أي تعديل مستني الرفع.',
          style: TextStyle(
            color: _white,
            fontFamily: 'Cairo',
            fontSize: 13,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('تمام', style: TextStyle(color: _gold)),
          ),
        ],
      ),
    );
  }

  String get _adminName {
    final user = AdminAuthService.currentUser;
    final name = (user?.displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = (user?.email ?? '').trim();
    if (email.isNotEmpty) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty) return prefix;
    }
    return 'صاحب المحل';
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
                  'أهلاً بك، $_adminName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  /// بيفتح الصفحة، ولما نرجع منها بنحدّث الأرقام (لأن العدّادات count()
  /// مش stream حي على كل العملاء).
  Future<void> _navTo(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _loadCounts();
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
