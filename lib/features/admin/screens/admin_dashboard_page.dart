import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/work_stage.dart';
import '../../clients/list/clients_list_page.dart';
import '../../auth/login_page.dart';
import '../../home/home_screen.dart';
import 'gallery_reorder_page.dart';

import '../../auth/admin_auth_service.dart';
import 'admin_analytics_page.dart';
import 'upload_image_page.dart';
import 'gallery_management_page.dart';
import 'installation_agenda_page.dart';
import 'promo_management_page.dart';
import 'upload_queue_page.dart';
import 'featured_works_page.dart';

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
  static const Color _bg = Color(0xFF0F172A);
  static const Color _panel = Color(0xFF1E293B);
  static const Color _panel2 = Color(0xFF273449);
  static const Color _line = Color(0xFF334155);
  static const Color _gold = AppColors.primaryGold;
  static const Color _sky = Color(0xFF38BDF8);
  static const Color _violet = Color(0xFFA78BFA);
  static const Color _green = Color(0xFF22E58B);
  static const Color _white = Color(0xFFF1F5F9);
  static const Color _muted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    // لوحة الإدارة مبتتفتحش من غير جلسة أدمن سليمة (حتى لو اتفتحت بالبصمة)
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifySession());
  }

  Future<void> _verifySession() async {
    final status = await AdminAuthService.check();
    if (!mounted || AdminAuthService.canEnter(status)) return;
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
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
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
      decoration: const BoxDecoration(
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
            child: const Icon(Icons.shield_rounded, color: _gold, size: 25),
          ),
          const SizedBox(width: 14),
          const Expanded(
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
            style: const TextStyle(fontSize: 12, color: _muted),
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
            child: ClipOval(
              child: Image.asset(
                'assets/images/abdo.jpg',
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 46,
                  height: 46,
                  color: _gold.withValues(alpha: 0.2),
                  child: const Icon(Icons.person, color: _gold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
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
          style: const TextStyle(
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
              const Divider(color: _line, height: 1, indent: 66, endIndent: 14),
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
        child: const Row(
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
        title: const Text(
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
                  title: const Text(
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
            child: const Text(
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
          style: const TextStyle(fontFamily: 'Cairo', color: _white),
        ),
      ),
    );
  }
}


/// شريط مراحل الشغل: عدد العملاء في كل مرحلة بلون نيون، واضغط تفتح العملاء مفلترين
class _StageStrip extends StatefulWidget {
  const _StageStrip({required this.onTapStage, required this.refreshToken});

  final ValueChanged<int> onTapStage;
  final int refreshToken;

  @override
  State<_StageStrip> createState() => _StageStripState();
}

class _StageStripState extends State<_StageStrip> {
  static const Map<int, Color> _colors = WorkStage.colors;
  static const Map<int, String> _labels = {
    1: 'بدأنا الشغل',
    2: 'تحضير',
    3: 'جاهز للتركيب',
    4: 'تمت',
  };

  Map<int, int>? _counts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _StageStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  /// بدل ما نحمّل كل العملاء (قراءة لكل مستند)، بنستخدم count() (قراءة واحدة
  /// تقريبًا لكل ١٠٠٠ مستند). العملاء القدام من غير work_stage بيتحسبوا:
  /// تمت = installation_done، والباقي = مرحلة ١ (نفس WorkStage.fromData).
  Future<void> _load() async {
    try {
      final col = FirebaseFirestore.instance.collection('clients');
      final results = await Future.wait([
        col.count().get(),
        col.where('work_stage', isEqualTo: WorkStage.preparing).count().get(),
        col.where('work_stage', isEqualTo: WorkStage.drilled).count().get(),
        col.where('installation_done', isEqualTo: true).count().get(),
      ]);
      final total = results[0].count ?? 0;
      final preparing = results[1].count ?? 0;
      final drilled = results[2].count ?? 0;
      final done = results[3].count ?? 0;
      final started = total - preparing - drilled - done;
      if (!mounted) return;
      setState(() {
        _counts = {
          1: started < 0 ? 0 : started,
          2: preparing,
          3: drilled,
          4: done,
        };
      });
    } catch (_) {
      // لو فشل (مفيش نت) بنسيب القيم القديمة أو "…"
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts ?? const <int, int>{};
    final loaded = _counts != null;
    final onTapStage = widget.onTapStage;

    return Row(
      children: [
        for (final stage in const [1, 2, 3, 4])
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: stage == 4 ? 0 : 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTapStage(stage),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      _colors[stage]!.withValues(alpha: 0.10),
                      const Color(0xFF1E293B),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _colors[stage]!.withValues(alpha: 0.65),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _colors[stage]!.withValues(alpha: 0.28),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        loaded ? _ar(counts[stage]) : '…',
                        style: TextStyle(
                          color: _colors[stage],
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _labels[stage]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}


class _QuickAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF1F5F9),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GroupRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}
