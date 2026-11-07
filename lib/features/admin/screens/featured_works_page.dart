import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_url.dart';

class FeaturedWorksPage extends StatefulWidget {
  const FeaturedWorksPage({super.key});

  @override
  State<FeaturedWorksPage> createState() => _FeaturedWorksPageState();
}

class _FeaturedWorksPageState extends State<FeaturedWorksPage> {
  // الحد الأقصى لعدد صور الرئيسية — بيتحفظ في public_config/home
  // (4 : 60) وبيتقرأ في الرئيسية عند كل فتح.
  int _maxLimit = 25;
  static const Color _gold = AppColors.primaryGold;

  @override
  void initState() {
    super.initState();
    _loadLimit();
  }

  Future<void> _loadLimit() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('public_config')
          .doc('home')
          .get();
      final raw = snap.data()?['featured_count'];
      if (raw is num && mounted) {
        setState(() => _maxLimit = raw.toInt().clamp(4, 60));
      }
    } catch (_) {
      // مفيش إعداد محفوظ — نكمل بالافتراضي.
    }
  }

  Future<void> _setLimit(int value) async {
    final next = value.clamp(4, 60);
    setState(() => _maxLimit = next);
    try {
      await FirebaseFirestore.instance
          .collection('public_config')
          .doc('home')
          .set({
            'featured_count': next,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر حفظ العدد. اتأكد من نشر قواعد Firestore.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _toggleFeatured(DocumentSnapshot doc, bool currentVal, int totalFeatured) async {
    if (!currentVal && totalFeatured >= _maxLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('وصلت للحد الأقصى ($_maxLimit صورة). زوّد العدد من الشريط اللي فوق أو ألغِ تحديد صورة قديمة.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    await doc.reference.update({
      'is_featured': !currentVal,
      'featured_at': !currentVal ? FieldValue.serverTimestamp() : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تحديد صور الصفحة الرئيسية',
          style: TextStyle(fontFamily: 'Aref Ruqaa', color: AppColors.lightGold, fontSize: 20),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('gallery_images').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }

          final docs = snapshot.data!.docs;
          final featuredCount = docs.where((d) => d.data()['is_featured'] == true).length;

          return Column(
            children: [
              // شريط العداد والتنبيه
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المحدد للرئيسية: $featuredCount من $_maxLimit صورة',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                        Icon(
                          featuredCount >= _maxLimit ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          color: featuredCount >= _maxLimit ? Colors.greenAccent : _gold,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'عدد صور الرئيسية',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'أقل',
                          onPressed: _maxLimit <= 4
                              ? null
                              : () => _setLimit(_maxLimit - 1),
                          icon: const Icon(Icons.remove_circle_outline, color: _gold, size: 20),
                        ),
                        Text(
                          '$_maxLimit',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'أكتر',
                          onPressed: _maxLimit >= 60
                              ? null
                              : () => _setLimit(_maxLimit + 1),
                          icon: const Icon(Icons.add_circle_outline, color: _gold, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // شبكة اختيار وتحديد الصور
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final url = ImageUrl.thumbnail(data['url'].toString());
                    final isFeatured = data['is_featured'] == true;

                    return GestureDetector(
                      onTap: () => _toggleFeatured(doc, isFeatured, featuredCount),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(url, fit: BoxFit.cover),
                          ),
                          // علامة التحديد (صح أخضر أو علامة إضافة)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFeatured ? Colors.green : Colors.black54,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Icon(
                                isFeatured ? Icons.check : Icons.add,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}