import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'app_image_viewer.dart';

class GalleryGrid extends StatelessWidget {
  final String category;
  final String? accessoryType;
  final bool isNeonMode;
  final Color accentColor;
  final int crossAxisCount;

  const GalleryGrid({
    super.key,
    required this.category,
    this.accessoryType,
    required this.isNeonMode,
    required this.accentColor,
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
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('gallery_images')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'حصل خطأ أثناء تحميل الصور',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: accentColor));
        }

        final documents = snapshot.data?.docs ?? [];

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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 56,
                    color: accentColor.withValues(alpha: 0.65),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد صور في هذا القسم حاليًا',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          itemCount: images.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final document = images[index];
            final data = document.data();

            final originalUrl = data['url']?.toString().trim() ?? '';
            final imageUrl = _getOptimizedUrl(originalUrl);

            return GestureDetector(
              onTap: () =>
                  _showImageViewer(context, imageUrls, titles, index),
              child: Hero(
                tag: 'gallery_${document.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      border: Border.all(
                        color: isNeonMode
                            ? accentColor.withValues(alpha: 0.65)
                            : AppColors.primaryGold.withValues(alpha: 0.45),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) {
                        return Container(
                          color: theme.cardColor,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(color: accentColor),
                        );
                      },
                      errorWidget: (context, url, error) {
                        return Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
