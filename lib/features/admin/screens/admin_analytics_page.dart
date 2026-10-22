import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fl_chart/fl_chart.dart'; // ✅ مكتبة الرسوم
import '../../../core/constants/app_colors.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  // متغيرات لحفظ الأرقام
  int _totalClients = 0;
  int _activeJobs = 0;
  int _archivedJobs = 0;

  // إحصائيات الأنواع
  final Map<String, int> _categoryCounts = {
    "ويفي": 0,
    "بلتكانة": 0,
    "مواسير": 0,
    "حلقات كبس": 0,
    "إكسسوارات": 0,
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  Future<void> _calculateStats() async {
    try {
      // 1. حساب العملاء (حالي وأرشيف)
      var clientSnap = await FirebaseFirestore.instance
          .collection('clients')
          .get();
      _totalClients = clientSnap.docs.length;

      DateTime today = DateTime.now();
      today = DateTime(today.year, today.month, today.day); // تصفير الوقت

      for (var doc in clientSnap.docs) {
        var data = doc.data();
        final done = data['installation_done'] == true;
        if (done) {
          _archivedJobs++;
        } else if (data['installation_date'] != null) {
          DateTime installDate = (data['installation_date'] as Timestamp)
              .toDate();
          if (installDate.isBefore(today)) {
            _archivedJobs++;
          } else {
            _activeJobs++;
          }
        } else {
          _activeJobs++;
        }
      }

      // 2. حساب أنواع الصور (عشان نعرف أكتر نوع مطلوب)
      var gallerySnap = await FirebaseFirestore.instance
          .collection('gallery_images')
          .get();
      for (var doc in gallerySnap.docs) {
        String cat = doc.data()['category'] ?? "عام";
        // توحيد المسميات لو فيه قديم
        if (cat == "بلتكانات") cat = "بلتكانة";

        if (_categoryCounts.containsKey(cat)) {
          _categoryCounts[cat] = _categoryCounts[cat]! + 1;
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error calculating stats: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text(
          "تحليل البيانات",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.neonGold),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. كروت الملخص
                  Row(
                    children: [
                      _buildStatCard(
                        "إجمالي العملاء",
                        _totalClients.toString(),
                        AppColors.primaryGold,
                        Icons.people,
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        "شغل جاري",
                        _activeJobs.toString(),
                        AppColors.neonGreen,
                        Icons.engineering,
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        "تم التسليم",
                        _archivedJobs.toString(),
                        Colors.grey,
                        Icons.archive,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 2. عنوان الرسم البياني
                  Text(
                    "توزيع أنواع الشغل (المعرض)",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. الرسم البياني الدائري (Pie Chart)
                  SizedBox(
                    height: 250, // ارتفاع الرسمة
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 5, // مسافة بين القطع
                        centerSpaceRadius: 40, // خرم في النص (Donut)
                        sections: _getSections(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. مفتاح الرسم (Legend)
                  Wrap(
                    spacing: 15,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: _categoryCounts.entries.map((entry) {
                      return _buildLegendItem(
                        entry.key,
                        _getColorForCategory(entry.key),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  // --- Widgets ---

  // كارت الرقم
  Widget _buildStatCard(
    String title,
    String count,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 5),
            Text(
              count,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // مفتاح الألوان
  Widget _buildLegendItem(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // تجهيز داتا الرسمة
  List<PieChartSectionData> _getSections() {
    return _categoryCounts.entries
        .map((entry) {
          // ممكن نعمل أنيميشن هنا مستقبلاً
          final double fontSize = 14.0;
          final double radius = 50.0;

          // لو مفيش داتا خالص منعملش قسم فاضي
          if (entry.value == 0) return null;

          return PieChartSectionData(
            color: _getColorForCategory(entry.key),
            value: entry.value.toDouble(),
            title: '${entry.value}', // الرقم يظهر جوه
            radius: radius,
            titleStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        })
        .whereType<PieChartSectionData>()
        .toList(); // تصفية الـ null
  }

  // ألوان الأقسام
  Color _getColorForCategory(String key) {
    switch (key) {
      case "ويفي":
        return AppColors.primaryGold;
      case "بلتكانة":
        return AppColors.lightGold;
      case "مواسير":
        return const Color(0xFF8D6B3A);
      case "حلقات كبس":
        return AppColors.navyDark;
      case "إكسسوارات":
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }
}
