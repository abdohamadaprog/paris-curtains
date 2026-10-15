import 'package:flutter/material.dart';

import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../clients/screens/clients_list_page.dart';
import '../../home/home_screen.dart';

import '../../home/screens/gallery_reorder_page.dart'; // ✅ للترتيب

import '../widgets/admin_cards.dart'; // كروت الأدمن
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          _buildHeader(), // الهيدر الثابت
          // القائمة السفلية
          Padding(
            padding: const EdgeInsets.only(top: 290),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                Text(
                  "إدارة النظام",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                // 1. الكروت الكبيرة
                AdminLargeCard(
                  title: "إضافة عمل جديد",
                  subtitle: "رفع صور للمعارض",
                  icon: Icons.cloud_upload_rounded,
                  color: AppColors.neonGold,
                  onTap: () => _navTo(const UploadImagePage()),
                ),
                AdminLargeCard(
                  title: "قائمة العملاء",
                  subtitle: "إدارة المقاسات والحسابات",
                  icon: Icons.assignment_ind_rounded,
                  color: AppColors.neonCyan,
                  onTap: () => _navTo(const ClientsListPage()),
                ),

                const SizedBox(height: 10),

                // 2. الصف الثالث: تعديل المعرض + السلايدر
                Row(
                  children: [
                    Expanded(
                      child: AdminSmallCard(
                        title: "تعديل المعرض",
                        icon: Icons.grid_view_rounded,
                        color: AppColors.neonPurple,
                        onTap: () => _navTo(const GalleryManagementPage()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminSmallCard(
                        title: "صور السلايدر",
                        icon: Icons.view_carousel_rounded,
                        color: Colors.pinkAccent,
                        onTap: () => _navTo(const PromoManagementPage()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 3. الصف الرابع: الترتيب + الأجندة
                Row(
                  children: [
                    Expanded(
                      child: AdminSmallCard(
                        title: "ترتيب الصور",
                        icon: Icons.low_priority_rounded,
                        color: AppColors.neonGreen,
                        onTap: () => _navTo(const GalleryReorderPage()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminSmallCard(
                        title: "الأجندة",
                        icon: Icons.calendar_month_rounded,
                        color: AppColors.neonOrange,
                        onTap: () => _navTo(const InstallationAgendaPage()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 4. الصف الخامس (الجديد): الأمان + التحليل
                Row(
                  children: [
                    Expanded(
                      child: AdminSmallCard(
                        title: "الأمان",
                        icon: Icons.fingerprint,
                        color: Colors.blueGrey,
                        onTap: _showSecurityDialog,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminSmallCard(
                        title: "تحليل البيانات", // ✅ الزر الجديد
                        icon: Icons.pie_chart_rounded,
                        color: Colors.tealAccent,
                        onTap: () => _navTo(const AdminAnalyticsPage()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // 5. زر الخروج (عريض في الآخر)
                AdminLargeCard(
                  title: "خروج للهوم",
                  subtitle: "العودة لواجهة العميل",
                  icon: Icons.home_rounded,
                  color: Colors.red,
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  ),
                ),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- دوال مساعدة ---
  Widget _buildHeader() {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF1A237E), AppColors.bgDark],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(50)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: AppColors.neonGold.withOpacity(0.05),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -30,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: AppColors.neonCyan.withOpacity(0.05),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "لوحة التحكم",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            "أهلاً، م/ عبدالرحمن 👋",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.neonGold,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonGold.withOpacity(0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const CircleAvatar(
                          radius: 30, // كبرناها سنة بسيطة
                          backgroundImage: AssetImage("assets/images/abdo.jpg"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // كارت العدادات
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const AdminStatItem(
                          label: "العملاء",
                          collection: "clients",
                          icon: Icons.people_outline,
                          color: AppColors.neonCyan,
                        ),
                        Container(width: 1, height: 30, color: Colors.white12),
                        const AdminStatItem(
                          label: "الصور",
                          collection: "gallery_images",
                          icon: Icons.image_outlined,
                          color: AppColors.neonGold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navTo(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.neonCyan),
        ),
        title: Row(
          children: [
            const Icon(Icons.security, color: AppColors.neonCyan),
            const SizedBox(width: 10),
            Text(
              "أمان التطبيق",
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
            ),
          ],
        ),
        content: FutureBuilder<bool>(
          future: SharedPreferences.getInstance().then(
            (p) => p.getBool('biometric_enabled') ?? false,
          ),
          builder: (context, snapshot) {
            bool isEnabled = snapshot.data ?? false;
            return StatefulBuilder(
              builder: (context, setStateDialog) => SwitchListTile(
                title: Text(
                  "الدخول بالبصمة",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
                ),
                activeThumbColor: AppColors.neonGold,
                value: isEnabled,
                onChanged: (val) async {
                  await _toggleBiometrics(val);
                  setStateDialog(() => isEnabled = val);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      if (await auth.canCheckBiometrics &&
          await auth.authenticate(
            localizedReason: 'تفعيل البصمة',
            options: const AuthenticationOptions(biometricOnly: true),
          )) {
        await prefs.setBool('biometric_enabled', true);
        _showSnack("تم التفعيل ✅", AppColors.neonGreen);
      }
    } else {
      await prefs.setBool('biometric_enabled', false);
      _showSnack("تم الإلغاء", AppColors.neonOrange);
    }
    setState(() {});
  }

  void _showSnack(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: TextStyle(fontFamily: 'Cairo', color: Colors.black),
          ),
          backgroundColor: color,
        ),
      );
    }
  }
}
