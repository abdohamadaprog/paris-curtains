import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_url.dart';
import 'promo_reorder_page.dart';

class PromoManagementPage extends StatefulWidget {
  const PromoManagementPage({super.key});

  @override
  State<PromoManagementPage> createState() => _PromoManagementPageState();
}

class _PromoManagementPageState extends State<PromoManagementPage> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  final String cloudName = 'dlmx10dic';
  final String uploadPreset = 'curtains_upload';

  Future<String> _uploadFile(XFile image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    );
    final bytes = await image.readAsBytes().timeout(const Duration(minutes: 2));
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: image.name),
    );
    request.fields['upload_preset'] = uploadPreset;
    final response = await request.send().timeout(const Duration(minutes: 3));
    final responseBody = await response.stream.bytesToString().timeout(
      const Duration(minutes: 1),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudinary HTTP ${response.statusCode}: $responseBody');
    }
    final jsonResponse = jsonDecode(responseBody);
    return jsonResponse['secure_url'] as String;
  }

  Future<void> _pickAndUpload() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final url = await _uploadFile(image);
      final snapshot = await FirebaseFirestore.instance
          .collection('promo_images')
          .get();

      await FirebaseFirestore.instance.collection('promo_images').add({
        'url': url,
        'created_at': FieldValue.serverTimestamp(),
        'sort_order': snapshot.docs.length,
      });

      if (mounted) _showSnack('تم رفع صورة العرض', AppColors.success);
    } catch (error) {
      if (mounted) _showSnack('خطأ: $error', AppColors.danger);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _replaceImage(DocumentSnapshot doc) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final url = await _uploadFile(image);
      await doc.reference.update({
        'url': url,
        'updated_at': FieldValue.serverTimestamp(),
      });
      if (mounted) _showSnack('تم تغيير صورة العرض', AppColors.success);
    } catch (error) {
      if (mounted) _showSnack('خطأ: $error', AppColors.danger);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteImage(DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'حذف العرض؟',
          style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
        ),
        content: const Text(
          'هتتشال الصورة من سلايدر الصفحة الرئيسية.',
          style: TextStyle(fontFamily: 'Cairo', color: Color(0xFFB8B5AF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.lightGold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'حذف',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await doc.reference.delete();
    if (mounted) _showSnack('تم حذف العرض', AppColors.primaryGold);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text(
          'صور السلايدر والعروض',
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
                color: AppColors.primaryGold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.low_priority, color: AppColors.lightGold),
            ),
            tooltip: 'ترتيب العروض',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUpload,
            child: Container(
              margin: const EdgeInsets.all(20),
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryGold),
              ),
              child: Center(
                child: _isUploading
                    ? const CircularProgressIndicator(
                        color: AppColors.primaryGold,
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            color: AppColors.primaryGold,
                            size: 35,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'اضغط لرفع صورة عرض جديدة',
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'تقدر تغير أو تمسح أي صورة ظاهرة في الهوم من هنا',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFFB8B5AF),
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Avoid excluding older promo records without sort_order.
              stream: FirebaseFirestore.instance
                  .collection('promo_images')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGold,
                    ),
                  );
                }
                final docs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final ad = a.data() as Map<String, dynamic>;
                    final bd = b.data() as Map<String, dynamic>;
                    final ao = ad['sort_order'];
                    final bo = bd['sort_order'];
                    if (ao is num && bo is num) {
                      final byOrder = ao.compareTo(bo);
                      if (byOrder != 0) return byOrder;
                    } else if ((ao is num) != (bo is num)) {
                      return ao is num ? -1 : 1;
                    }
                    final at = ad['created_at'];
                    final bt = bd['created_at'];
                    final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                    final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                    return bm.compareTo(am);
                  });

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'مفيش صور عروض حالياً',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Color(0xFFB8B5AF),
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final url = (doc['url'] ?? '').toString();

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryGold.withValues(alpha: 0.45),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Expanded(
                            child: CachedNetworkImage(
                              imageUrl: ImageUrl.thumbnail(url, width: 700),
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryGold,
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.lightGold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: _isUploading
                                        ? null
                                        : () => _replaceImage(doc),
                                    icon: const Icon(
                                      Icons.swap_horiz_rounded,
                                      size: 16,
                                      color: AppColors.lightGold,
                                    ),
                                    label: const Text(
                                      'تغيير',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        color: AppColors.lightGold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'حذف',
                                  onPressed: _isUploading
                                      ? null
                                      : () => _deleteImage(doc),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
