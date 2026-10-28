import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fl_chart/fl_chart.dart'; // ✅ مكتبة الرسوم
import '../../../core/constants/app_colors.dart';

// نفس ألوان الفاتورة والمقاسات والعملاء
const Color _bg = Color(0xFF0F172A);
const Color _panel = Color(0xFF1E293B);
const Color _line = Color(0xFF334155);
const Color _gold = AppColors.primaryGold;
const Color _muted = Color(0xFF94A3B8);

const Map<int, Color> _stageColors = {
  1: Color(0xFFFF4D5E),
  2: Color(0xFFFFD43B),
  3: Color(0xFF38BDF8),
  4: Color(0xFF22E58B),
};
const Map<int, String> _stageLabels = {
  1: 'بدأنا الشغل',
  2: 'جاري التحضير',
  3: 'جاهز للتركيب',
  4: 'تمت',
};

String _ar(Object? n) => (n ?? '').toString().replaceAllMapped(
  RegExp(r'[0-9]'),
  (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
);

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

  // عدد العملاء في كل مرحلة شغل (١ أحمر • ٢ أصفر • ٣ أزرق • ٤ أخضر)
  final Map<int, int> _stageCounts = {1: 0, 2: 0, 3: 0, 4: 0};

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
      // 1. حساب العملاء (حالي وأرشيف + المراحل)
      var clientSnap = await FirebaseFirestore.instance
          .collection('clients')
          .get();
      _totalClients = clientSnap.docs.length;

      DateTime today = DateTime.now();
      today = DateTime(today.year, today.month, today.day); // تصفير الوقت

      for (var doc in clientSnap.docs) {
        var data = doc.data();

        final rawStage = data['work_stage'];
        final stage = rawStage is num
            ? rawStage.toInt().clamp(1, 4)
            : (data['installation_done'] == true ? 4 : 1);
        _stageCounts[stage] = (_stageCounts[stage] ?? 0) + 1;

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
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          "تحليل البيانات",
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        backgroundColor: _panel,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. كروت الملخص
                  Row(
                    children: [
                      _buildStatCard(
                        "إجمالي العملاء",
                        _ar(_totalClients),
                        _gold,
                        Icons.groups_rounded,
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        "شغل جاري",
                        _ar(_activeJobs),
                        const Color(0xFF38BDF8),
                        Icons.engineering_rounded,
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        "الأرشيف",
                        _ar(_archivedJobs),
                        _muted,
                        Icons.inventory_2_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  // 2. مراحل الشغل
                  _sectionTitle(
                    "مراحل الشغل",
                    Icons.local_fire_department_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildStageBar(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final s in const [1, 2, 3, 4])
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: s == 4 ? 0 : 8),
                            child: _buildStageCard(s),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // 3. توزيع أنواع الشغل
                  _sectionTitle(
                    "توزيع أنواع الشغل (المعرض)",
                    Icons.donut_large_rounded,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 4, // مسافة بين القطع
                              centerSpaceRadius: 42, // خرم في النص (Donut)
                              sections: _getSections(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: _categoryCounts.entries.map((entry) {
                            return _buildLegendItem(
                              '${entry.key} (${_ar(entry.value)})',
                              _getColorForCategory(entry.key),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- Widgets ---

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
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // كارت الرقم
  Widget _buildStatCard(
    String title,
    String count,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              count,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
      ),
    );
  }

  // شريط واحد بنسب المراحل
  Widget _buildStageBar() {
    final total = _stageCounts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (final s in const [1, 2, 3, 4])
              if ((_stageCounts[s] ?? 0) > 0)
                Expanded(
                  flex: _stageCounts[s]!,
                  child: Container(color: _stageColors[s]),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageCard(int stage) {
    final color = _stageColors[stage]!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.10), _panel),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.3),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          Text(
            _ar(_stageCounts[stage]),
            style: TextStyle(
              color: color,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _stageLabels[stage]!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
        ),
      ],
    );
  }

  // تجهيز داتا الرسمة
  List<PieChartSectionData> _getSections() {
    return _categoryCounts.entries
        .map((entry) {
          // لو مفيش داتا خالص منعملش قسم فاضي
          if (entry.value == 0) return null;

          return PieChartSectionData(
            color: _getColorForCategory(entry.key),
            value: entry.value.toDouble(),
            title: _ar(entry.value), // الرقم يظهر جوه
            radius: 52,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _bg,
            ),
          );
        })
        .whereType<PieChartSectionData>()
        .toList(); // تصفية الـ null
  }

  // ألوان الأقسام (ألوان واضحة على الخلفية الغامقة)
  Color _getColorForCategory(String key) {
    switch (key) {
      case "ويفي":
        return _gold;
      case "بلتكانة":
        return const Color(0xFF38BDF8);
      case "مواسير":
        return const Color(0xFFA78BFA);
      case "حلقات كبس":
        return const Color(0xFFFB7185);
      case "إكسسوارات":
        return const Color(0xFF22E58B);
      default:
        return _muted;
    }
  }
}
