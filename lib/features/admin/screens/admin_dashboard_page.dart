import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../clients/screens/clients_list_page.dart';
import '../../home/home_screen.dart';
import '../../home/screens/gallery_reorder_page.dart';

import 'admin_analytics_page.dart';
import 'upload_image_page.dart';
import 'gallery_management_page.dart';
import 'installation_agenda_page.dart';
import 'promo_management_page.dart';
import 'upload_queue_page.dart';
import 'featured_works_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final LocalAuthentication auth = LocalAuthentication();
  static const Color _bg = AppColors.bgDark;
  static const Color _panel = Color(0xFF161622);
  static const Color _panel2 = Color(0xFF1E1E2C);
  static const Color _gold = AppColors.primaryGold;
  static const Color _cyan = AppColors.lightGold;
  static const Color _purple = AppColors.primaryGold;
  static const Color _green = AppColors.primaryGold;
  static const Color _white = Color(0xFFF8F5EF);
  static const Color _muted = Color(0xFFB8B5AF);

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
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildWelcome(),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    'الوصول السريع',
                    'أهم المهام في ضغطة واحدة',
                    Icons.bolt_rounded,
                    _gold,
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 520 ? 4 : 2;
                      final itemWidth =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _QuickAction(
                              title: 'إضافة عمل',
                              icon: Icons.add_photo_alternate_rounded,
                              color: _gold,
                              onTap: () => _navTo(const UploadImagePage()),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _QuickAction(
                              title: 'العملاء',
                              icon: Icons.people_alt_rounded,
                              color: _cyan,
                              onTap: () => _navTo(const ClientsListPage()),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _QuickAction(
                              title: 'الأجندة',
                              icon: Icons.calendar_month_rounded,
                              color: _purple,
                              onTap: () =>
                                  _navTo(const InstallationAgendaPage()),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _QuickAction(
                              title: 'التقارير',
                              icon: Icons.analytics_rounded,
                              color: _green,
                              onTap: () => _navTo(const AdminAnalyticsPage()),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  _sectionTitle(
                    'إدارة المعرض والمحتوى',
                    'تحكم في الصور وطريقة عرضها',
                    Icons.photo_library_rounded,
                    _cyan,
                  ),
                  const SizedBox(height: 14),

                  // بند تحديد أحدث الأعمال في الرئيسية
                  _buildFeatureCard(
                    title: 'أحدث الأعمال (25 صورة للرئيسية)',
                    subtitle: 'تحديد الصور المميزة التي تظهر في واجهة التطبيق',
                    icon: Icons.star_rounded,
                    color: _gold,
                    onTap: () => _navTo(const FeaturedWorksPage()),
                  ),

                  _buildFeatureCard(
                    title: 'إدارة المعرض',
                    subtitle: 'تعديل وحذف الصور الموجودة في المعرض',
                    icon: Icons.grid_view_rounded,
                    color: _cyan,
                    onTap: () => _navTo(const GalleryManagementPage()),
                  ),
                  _buildFeatureCard(
                    title: 'ترتيب الصور',
                    subtitle: 'تغيير ترتيب ظهور الصور',
                    icon: Icons.low_priority_rounded,
                    color: _green,
                    onTap: () => _navTo(const GalleryReorderPage()),
                  ),
                  _buildFeatureCard(
                    title: 'صور السلايدر والعروض',
                    subtitle: 'إدارة الصور الظاهرة في البانر العلوي',
                    icon: Icons.view_carousel_rounded,
                    color: _gold,
                    onTap: () => _navTo(const PromoManagementPage()),
                  ),
                  _buildFeatureCard(
                    title: 'متابعة رفع الصور',
                    subtitle: 'عرض حالة طابور الرفع وإعادة محاولة الفاشلة',
                    icon: Icons.cloud_sync_rounded,
                    color: _purple,
                    onTap: () => _navTo(const UploadQueuePage()),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(
                    'إعدادات الأمان',
                    'إعدادات البصمة وحماية البيانات',
                    Icons.admin_panel_settings_rounded,
                    _purple,
                  ),
                  const SizedBox(height: 14),
                  _SecondaryAction(
                    title: 'أمان التطبيق',
                    subtitle: 'إعدادات البصمة لحماية لوحة الإدارة',
                    icon: Icons.fingerprint_rounded,
                    color: _gold,
                    onTap: _showSecurityDialog,
                  ),
                  const SizedBox(height: 24),
                  _buildHomeButton(),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'PARIS CURTAINS • ADMIN',
                      style: TextStyle(
                        color: Color(0xFF777783),
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
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF292536), Color(0xFF191923), AppColors.bgDark],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        border: Border(bottom: BorderSide(color: _gold.withValues(alpha: 0.4))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.shield_rounded, color: _gold, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'لوحة تحكم باريس للستاير',
                      style: TextStyle(
                        fontFamily: 'Aref Ruqaa',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _gold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'إدارة المحتوى والعملاء وجدول التركيبات',
                      style: TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Image.asset(
              'assets/images/abdo.jpg',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 48,
                height: 48,
                color: _gold.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: _gold),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'أهلاً بك، م/ عبده حمادة',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _white,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'كل بيانات المعرض والعملاء والورشة محدثة وجاهزة',
                  style: TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _white,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '• $subtitle',
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: _white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: _muted,
        ),
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
          border: Border.all(color: _gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.home_rounded, color: _gold, size: 20),
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

  void _navTo(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
        await prefs.setBool('biometric_enabled', true);
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

class _QuickAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF191923),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          constraints: const BoxConstraints(minHeight: 105),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: color.withValues(alpha: 0.23)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFFF5F5F7),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SecondaryAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: const Color(0xFF161622),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white54,
          fontSize: 11,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 12,
        color: Colors.white38,
      ),
    );
  }
}
