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
  static const int _maxLimit = 25;
  static const Color _gold = AppColors.primaryGold;

  Future<void> _toggleFeatured(DocumentSnapshot doc, bool currentVal, int totalFeatured) async {
    if (!currentVal && totalFeatured >= _maxLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('وصلت للحد الأقصى (25 صورة). ألغِ تحديد صورة قديمة أولاً لإضافة غيرها.'),
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
          'تحديد أحدث الأعمال (الـ 25 صورة)',
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المحدد للرئيسية: $featuredCount من $_maxLimit صورة',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                    ),
                    Icon(
                      featuredCount == _maxLimit ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      color: featuredCount == _maxLimit ? Colors.greenAccent : _gold,
                      size: 20,
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