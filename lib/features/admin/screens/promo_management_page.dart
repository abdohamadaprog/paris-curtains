import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_colors.dart';
import 'promo_reorder_page.dart'; // ✅ استدعاء صفحة الترتيب

class PromoManagementPage extends StatefulWidget {
  const PromoManagementPage({super.key});

  @override
  State<PromoManagementPage> createState() => _PromoManagementPageState();
}

class _PromoManagementPageState extends State<PromoManagementPage> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  final String cloudName = "dlmx10dic";
  final String uploadPreset = "curtains_upload";

  Future<void> _pickAndUpload() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload"),
      );
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      request.fields['upload_preset'] = uploadPreset;
      var response = await request.send();

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(await response.stream.bytesToString());
        String url = jsonResponse['secure_url'];

        // حفظ الصورة مع وضع sort_order مبدئي (مثلاً 100 عشان تيجي في الآخر)
        var snapshot = await FirebaseFirestore.instance
            .collection('promo_images')
            .get();
        int newOrder = snapshot.docs.length;

        await FirebaseFirestore.instance.collection('promo_images').add({
          'url': url,
          'created_at': FieldValue.serverTimestamp(),
          'sort_order': newOrder,
        });

        if (mounted) _showSnack("تم رفع الصورة ✅", Colors.green);
      } else {
        throw Exception("فشل الرفع");
      }
    } catch (e) {
      if (mounted) _showSnack("خطأ: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
        title: Text(
          "إضافة للعروض",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.bgDark,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        // 🔥🔥 الزرار المطلوب (فوق على الشمال) 🔥🔥
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PromoReorderPage(),
                ),
              );
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.neonCyan.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.low_priority,
                color: AppColors.neonCyan,
              ), // أيقونة الترتيب
            ),
            tooltip: "ترتيب وحذف العروض",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // زر الرفع الكبير
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUpload,
            child: Container(
              margin: const EdgeInsets.all(20),
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.glassWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.neonGold,
                  style: BorderStyle.solid,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonGold.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: _isUploading
                    ? const CircularProgressIndicator(color: AppColors.neonGold)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_a_photo,
                            color: AppColors.neonGold,
                            size: 35,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "اضغط لرفع صورة جديدة",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const Divider(color: Colors.white10),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // عرض معاينة بسيطة للصور (مرتبة بالأحدث هنا للسهولة)
              stream: FirebaseFirestore.instance
                  .collection('promo_images')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.neonGold),
                  );
                var docs = snapshot.data!.docs;

                if (docs.isEmpty)
                  return Center(
                    child: Text(
                      "المعرض فارغ",
                      style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                    ),
                  );

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: NetworkImage(docs[index]['url']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
