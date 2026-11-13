import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import 'featured_works_page.dart';
import 'gallery_management_page.dart';
import 'gallery_reorder_page.dart';
import 'promo_management_page.dart';
import 'upload_image_page.dart';
import 'upload_queue_page.dart';

/// صفحة واحدة لكل شغل المعرض: بدل ٦ صفوف متفرقة في الداشبورد،
/// المالك بيدخل من مكان واحد ويختار اللي عايزه.
class GalleryHubPage extends StatelessWidget {
  const GalleryHubPage({super.key});

  static Color get _bg => AppPalette.bg;
  static Color get _panel => AppPalette.panel;
  static Color get _line => AppPalette.line;
  static Color get _gold => AppPalette.gold;
  static Color get _sky => AppPalette.sky;
  static Color get _violet => AppPalette.violet;
  static Color get _green => AppPalette.green;
  static Color get _muted => AppPalette.muted;
  static Color get _white => AppPalette.text;

  @override
  Widget build(BuildContext context) {
    final items = <_HubItem>[
      _HubItem(
        title: 'رفع صور جديدة',
        subtitle: 'ضيف صور للمعرض من المعرض أو الكاميرا',
        icon: Icons.add_photo_alternate_rounded,
        color: _gold,
        page: const UploadImagePage(),
      ),
      _HubItem(
        title: 'أحدث الأعمال',
        subtitle: '٢٥ صورة مميزة في الواجهة الرئيسية',
        icon: Icons.auto_awesome_rounded,
        color: _gold,
        page: const FeaturedWorksPage(),
      ),
      _HubItem(
        title: 'إدارة المعرض',
        subtitle: 'تعديل وحذف صور المعرض',
        icon: Icons.collections_rounded,
        color: _sky,
        page: const GalleryManagementPage(),
      ),
      _HubItem(
        title: 'ترتيب الصور',
        subtitle: 'تغيير ترتيب ظهور الصور',
        icon: Icons.swap_vert_rounded,
        color: _violet,
        page: const GalleryReorderPage(),
      ),
      _HubItem(
        title: 'السلايدر والعروض',
        subtitle: 'صور البانر العلوي',
        icon: Icons.view_carousel_rounded,
        color: _gold,
        page: const PromoManagementPage(),
      ),
      _HubItem(
        title: 'متابعة رفع الصور',
        subtitle: 'طابور الرفع وإعادة المحاولة',
        icon: Icons.cloud_upload_rounded,
        color: _green,
        page: const UploadQueuePage(),
      ),
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panel,
        foregroundColor: _white,
        title: Text(
          'المعرض والمحتوى',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            color: _gold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final item = items[i];
            return Material(
              color: _panel,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => item.page)),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(item.icon, color: item.color, size: 24),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                color: _white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.subtitle,
                              style: TextStyle(color: _muted, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_left_rounded,
                        size: 22,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HubItem {
  const _HubItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.page,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;
}
