import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'app_image_viewer.dart';
import 'gallery_widgets.dart';

class GalleryGrid extends StatelessWidget {
  final String category;
  final String? accessoryType;
  final int crossAxisCount;

  const GalleryGrid({
    super.key,
    required this.category,
    this.accessoryType,
    this.crossAxisCount = 2,
  });

  String _getOptimizedUrl(String originalUrl) {
    if (!originalUrl.contains('cloudinary.com') ||
        !originalUrl.contains('/upload/')) {
      return originalUrl;
    }

    return originalUrl.replaceFirst('/upload/', '/upload/q_auto/');
  }

  void _showImageViewer(
    BuildContext context,
    List<String> imageUrls,
    List<String> titles,
    int index,
  ) {
    AppImageViewerPage.open(
      context,
      imageUrls: imageUrls,
      titles: titles,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Fetch without orderBy so legacy records missing created_at are not
      // silently omitted by Firestore.
      stream: FirebaseFirestore.instance
          .collection('gallery_images')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const GalleryMessageView(
            icon: Icons.cloud_off_outlined,
            title: 'حصل خطأ أثناء تحميل الصور',
            subtitle: 'راجع اتصال الإنترنت وحاول مرة تانية.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGold),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents =
            [...(snapshot.data?.docs ?? [])]..sort((a, b) {
              final ad = a.data()['created_at'];
              final bd = b.data()['created_at'];
              final at = ad is Timestamp ? ad.millisecondsSinceEpoch : 0;
              final bt = bd is Timestamp ? bd.millisecondsSinceEpoch : 0;
              final byDate = bt.compareTo(at);
              return byDate != 0 ? byDate : a.id.compareTo(b.id);
            });

        final images = documents
            .where((document) {
              final data = document.data();
              final itemCategory = data['category']?.toString() ?? 'عام';
              final isAccessory = itemCategory == 'إكسسوارات';

              // معرض الستائر لا يعرض الإكسسوارات.
              if (category != 'إكسسوارات') {
                if (isAccessory) {
                  return false;
                }

                // عرض جميع أنواع الستائر.
                if (category == 'الكل' || category == 'ستائر') {
                  return true;
                }

                // جمع الحلقات والمواسير في قسم واحد.
                if (category == 'حلقات كبس ومواسير') {
                  return itemCategory == 'حلقات كبس' ||
                      itemCategory == 'مواسير';
                }

                return itemCategory == category;
              }

              // معرض الإكسسوارات فقط.
              if (!isAccessory) {
                return false;
              }

              if (accessoryType == null || accessoryType == 'الكل') {
                return true;
              }

              return data['accessory_type']?.toString() == accessoryType;
            })
            .where((document) {
              final url = document.data()['url']?.toString().trim() ?? '';
              return url.isNotEmpty;
            })
            .toList();

        if (images.isEmpty) {
          return const GalleryMessageView(
            icon: Icons.photo_library_outlined,
            title: 'لا توجد صور في هذا القسم حاليًا',
            subtitle: 'جرّب نوع تاني من الإكسسوارات.',
          );
        }

        final imageUrls = images
            .map((doc) => (doc.data()['url'] ?? '').toString())
            .toList();
        final titles = images
            .map(
              (doc) =>
                  (doc.data()['accessory_type'] ??
                          doc.data()['category'] ??
                          'إكسسوار')
                      .toString(),
            )
            .toList();

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          itemCount: images.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final data = images[index].data();
            final originalUrl = data['url']?.toString().trim() ?? '';

            return GalleryImageCard(
              imageUrl: _getOptimizedUrl(originalUrl),
              category: titles[index],
              isDark: isDark,
              compact: crossAxisCount >= 3,
              onTap: () => _showImageViewer(context, imageUrls, titles, index),
            );
          },
        );
      },
    );
  }
}
