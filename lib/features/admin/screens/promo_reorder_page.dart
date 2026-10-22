import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_colors.dart';

class PromoReorderPage extends StatefulWidget {
  const PromoReorderPage({super.key});

  @override
  State<PromoReorderPage> createState() => _PromoReorderPageState();
}

class _PromoReorderPageState extends State<PromoReorderPage> {
  List<DocumentSnapshot> _images = [];
  bool _isLoading = true;
  int? _selectedIndex; // لتحديد الصورة المراد تبديلها

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  // 1. جلب الصور (مرتبة)
  Future<void> _fetchImages() async {
    setState(() => _isLoading = true);
    var query = FirebaseFirestore.instance.collection('promo_images');

    // محاولة الجلب بالترتيب المحفوظ
    var snapshot = await query.orderBy('sort_order').get();

    // لو مفيش ترتيب (أول مرة)، بنجيب بالأحدث
    if (snapshot.docs.isEmpty) {
      var timeSnapshot = await query
          .orderBy('created_at', descending: true)
          .get();
      _images = timeSnapshot.docs;
    } else {
      _images = snapshot.docs;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // 2. منطق التبديل (Swap Logic)
  void _onImageTap(int index) {
    setState(() {
      if (_selectedIndex == null) {
        // تحديد الصورة الأولى
        _selectedIndex = index;
      } else {
        // التبديل بين الصورتين
        final temp = _images[_selectedIndex!];
        _images[_selectedIndex!] = _images[index];
        _images[index] = temp;

        // إلغاء التحديد
        _selectedIndex = null;
      }
    });
  }

  // 3. حفظ الترتيب في الداتابيز
  // حفظ الترتيب الجديد
  Future<void> _saveOrder() async {
    setState(() => _isLoading = true);
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (int i = 0; i < _images.length; i++) {
        batch.update(_images[i].reference, {'sort_order': i});
      }
      await batch.commit();

      if (mounted) {
        _showSnack("تم حفظ ترتيب العروض ✅", Colors.green);

        // 🔥🔥 استنى نص ثانية واخرج للداشبورد 🔥🔥
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack("خطأ: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 4. حذف العرض
  Future<void> _deleteImage(int index) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A24),
            title: const Text(
              "حذف العرض؟",
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              "سيتم حذف الصورة نهائياً من السلايدر.",
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("إلغاء"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("حذف", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;
    if (confirm) {
      setState(() => _isLoading = true);
      await _images[index].reference.delete(); // حذف من الفايربيس
      if (!mounted) return;
      setState(() {
        _images.removeAt(index); // حذف من الشاشة
        _isLoading = false;
      });
      _showSnack("تم الحذف", Colors.orange);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "ترتيب وحذف العروض",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading && _images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _saveOrder,
                icon: const Icon(Icons.save, color: Colors.black, size: 18),
                label: Text(
                  "حفظ",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.neonGold),
            )
          : _images.isEmpty
          ? Center(
              child: Text(
                "لا توجد عروض",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Text(
                    _selectedIndex == null
                        ? "اضغط لتحديد صورة، ثم اضغط على أخرى لتبديلها"
                        : "اختر المكان الجديد للصورة المحددة",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      var doc = _images[index];
                      bool isSelected = index == _selectedIndex;

                      return Container(
                        key: Key(doc.id),
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          // لون أخضر لو محددة
                          border: Border.all(
                            color: isSelected
                                ? AppColors.neonGreen
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // الصورة (قابلة للضغط)
                            GestureDetector(
                              onTap: () => _onImageTap(index),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.network(
                                  doc['url'],
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (ctx, child, p) => p == null
                                      ? child
                                      : Container(
                                          height: 160,
                                          color: Colors.white10,
                                          child: const Center(
                                            child: Icon(
                                              Icons.image,
                                              color: Colors.white24,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            // رقم الترتيب
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "ترتيب: ${index + 1}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),

                            // زر الحذف
                            Positioned(
                              top: 10,
                              left: 10,
                              child: GestureDetector(
                                onTap: () => _deleteImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),

                            // أيقونة التبديل عند التحديد
                            if (isSelected)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.swap_vert,
                                      color: AppColors.neonGreen,
                                      size: 50,
                                    ),
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
            ),
    );
  }
}
