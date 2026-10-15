import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../clients/screens/clients_list_page.dart';
import '../../home/home_screen.dart';
import '../../home/screens/gallery_reorder_page.dart';

import '../widgets/admin_cards.dart';
import 'admin_analytics_page.dart';
import 'upload_image_page.dart';
import 'gallery_management_page.dart';
import 'installation_agenda_page.dart';
import 'promo_management_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final LocalAuthentication auth = LocalAuthentication();

  static const Color _navy = Color(0xFF17263D);
  static const Color _navyLight = Color(0xFF243B59);
  static const Color _gold = Color(0xFFC5A46D);
  static const Color _pageBackground = Color(0xFFF5F6F8);
  static const Color _textDark = Color(0xFF263449);
  static const Color _textMuted = Color(0xFF7A8797);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 36),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionTitle(
                    title: 'إدارة النظام',
                    subtitle: 'كل أدوات إدارة باريس للستائر في مكان واحد',
                    icon: Icons.dashboard_customize_rounded,
                  ),
                  const SizedBox(height: 18),

                  AdminLargeCard(
                    title: 'إضافة عمل جديد',
                    subtitle: 'رفع صور جديدة للمعرض',
                    icon: Icons.cloud_upload_rounded,
                    color: _gold,
                    onTap: () => _navTo(const UploadImagePage()),
                  ),
                  const SizedBox(height: 12),

                  AdminLargeCard(
                    title: 'قائمة العملاء',
                    subtitle: 'إدارة العملاء والمقاسات والحسابات',
                    icon: Icons.people_alt_rounded,
                    color: _navyLight,
                    onTap: () => _navTo(const ClientsListPage()),
                  ),
                  const SizedBox(height: 20),

                  _buildSectionTitle(
                    title: 'إدارة المحتوى',
                    subtitle: 'التحكم في الصور والعروض',
                    icon: Icons.photo_library_outlined,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: AdminSmallCard(
                          title: 'تعديل المعرض',
                          icon: Icons.grid_view_rounded,
                          color: _navyLight,
                          onTap: () => _navTo(const GalleryManagementPage()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AdminSmallCard(
                          title: 'صور السلايدر',
                          icon: Icons.view_carousel_rounded,
                          color: _gold,
                          onTap: () => _navTo(const PromoManagementPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: AdminSmallCard(
                          title: 'ترتيب الصور',
                          icon: Icons.low_priority_rounded,
                          color: const Color(0xFF648778),
                          onTap: () => _navTo(const GalleryReorderPage()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AdminSmallCard(
                          title: 'الأجندة',
                          icon: Icons.calendar_month_rounded,
                          color: const Color(0xFF9A8058),
                          onTap: () => _navTo(const InstallationAgendaPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildSectionTitle(
                    title: 'الأمان والتقارير',
                    subtitle: 'إعدادات الدخول ومتابعة البيانات',
                    icon: Icons.verified_user_outlined,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: AdminSmallCard(
                          title: 'الأمان',
                          icon: Icons.fingerprint_rounded,
                          color: _navyLight,
                          onTap: _showSecurityDialog,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AdminSmallCard(
                          title: 'تحليل البيانات',
                          icon: Icons.analytics_rounded,
                          color: const Color(0xFF648778),
                          onTap: () => _navTo(const AdminAnalyticsPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildHomeButton(),
                  const SizedBox(height: 20),
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_navyLight, _navy],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'PARIS CURTAINS',
                          style: TextStyle(
                            color: Color(0xFFDCC9A6),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'لوحة التحكم',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أهلاً، م/ عبدالرحمن 👋',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold, width: 1.5),
                ),
                child: const CircleAvatar(
                  radius: 29,
                  backgroundColor: _navyLight,
                  backgroundImage: AssetImage('assets/images/abdo.jpg'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: AdminStatItem(
                    label: 'العملاء',
                    collection: 'clients',
                    icon: Icons.people_outline_rounded,
                    color: Color(0xFFDCC9A6),
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: VerticalDivider(
                    color: Colors.white24,
                    thickness: 1,
                    width: 18,
                  ),
                ),
                Expanded(
                  child: AdminStatItem(
                    label: 'الصور',
                    collection: 'gallery_images',
                    icon: Icons.image_outlined,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _gold.withOpacity(0.14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _navy, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: _textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: _textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHomeButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E8ED)),
          ),
          child: const Row(
            children: [
              Icon(Icons.home_rounded, color: _navy, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'العودة لواجهة العميل',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: _textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'الخروج من لوحة الإدارة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: _textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: _navy),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'أمان التطبيق',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: _textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
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
                      color: _textDark,
                      fontSize: 14,
                    ),
                  ),
                  activeThumbColor: _gold,
                  value: isEnabled,
                  onChanged: (value) async {
                    final success = await _toggleBiometrics(value);

                    if (success) {
                      setStateDialog(() => isEnabled = value);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<bool> _toggleBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      try {
        final canCheck = await auth.canCheckBiometrics;
        final isSupported = await auth.isDeviceSupported();

        if (!canCheck && !isSupported) {
          _showSnack('البصمة غير متاحة على هذا الجهاز', Colors.redAccent);
          return false;
        }

        final authenticated = await auth.authenticate(
          localizedReason: 'تأكيد الهوية لتفعيل البصمة',
          options: const AuthenticationOptions(biometricOnly: true),
        );

        if (!authenticated) return false;

        await prefs.setBool('biometric_enabled', true);

        if (mounted) {
          _showSnack('تم تفعيل البصمة بنجاح', const Color(0xFF648778));
        }
        return true;
      } catch (_) {
        if (mounted) {
          _showSnack('تعذر تفعيل البصمة على هذا الجهاز', Colors.redAccent);
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
        backgroundColor: _navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
        ),
      ),
    );
  }
}
