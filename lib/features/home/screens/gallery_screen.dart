import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/widgets/paris_footer.dart';
import '../widgets/app_image_viewer.dart';
import '../widgets/gallery_widgets.dart';
import 'accessories_gallery_page.dart';
import 'full_gallery_page.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const Color _gold = AppColors.primaryGold;

  static const List<String> _categories = [
    'ستائر',
    'ويفي',
    'دابل ويفي',
    'حلقات كبس ومواسير',
    'بلتكانة',
  ];

  List<String> _bannerImages = const [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _promoSub;

  static const Map<String, String> _categoryImages = {
    'ستائر':
        'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?auto=format&fit=crop&w=400&q=65',
    'ويفي':
        'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=format&fit=crop&w=400&q=65',
    'دابل ويفي':
        'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=400&q=65',
    'حلقات كبس ومواسير':
        'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?auto=format&fit=crop&w=400&q=65',
    'بلتكانة':
        'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=format&fit=crop&w=400&q=65',
  };

  String _selectedCategory = 'ستائر';
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _bannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _promoSub = FirebaseFirestore.instance
        .collection('promo_images')
        .snapshots()
        .listen((snapshot) {
          final docs = [...snapshot.docs];
          docs.sort((a, b) {
            final ao = a.data()['sort_order'] ?? 0;
            final bo = b.data()['sort_order'] ?? 0;
            return (ao as num).compareTo(bo as num);
          });
          final urls = docs
              .map((doc) => (doc.data()['url'] ?? '').toString().trim())
              .where((url) => url.isNotEmpty)
              .toList();
          if (!mounted) return;
          setState(() => _bannerImages = urls);
          _restartBannerTimer();
        });
  }

  void _restartBannerTimer() {
    _bannerTimer?.cancel();
    if (_bannerImages.length <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final next = (_bannerIndex + 1) % _bannerImages.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _promoSub?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  // اشتراك واحد ثابت (لو اتعمل جوه build، كل setState كان بيعيد الاشتراك)
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _galleryStream =
      FirebaseFirestore.instance.collection('gallery_images').snapshots();

  int _compareGalleryDocs(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final ad = a.data();
    final bd = b.data();
    final ao = ad['sort_order'];
    final bo = bd['sort_order'];
    final aHasOrder = ao is num;
    final bHasOrder = bo is num;
    if (aHasOrder && bHasOrder) {
      final order = (ao).compareTo(bo);
      if (order != 0) return order;
    } else if (aHasOrder != bHasOrder) {
      return aHasOrder ? -1 : 1;
    }
    final at = ad['created_at'];
    final bt = bd['created_at'];
    final aMillis = at is Timestamp ? at.millisecondsSinceEpoch : 0;
    final bMillis = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
    final byDate = bMillis.compareTo(aMillis);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterImages(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    // 1. استبعاد الإكسسوارات والروابط الفارغة
    final validDocs = docs.where((doc) {
      final data = doc.data();
      final category = (data['category'] ?? 'عام').toString();
      final url = data['url'];
      if (category == 'إكسسوارات') return false;
      if (url is! String || url.trim().isEmpty) return false;

      if (_selectedCategory == 'ستائر') return true;
      if (_selectedCategory == 'حلقات كبس ومواسير') {
        return category == 'حلقات كبس ومواسير' ||
            category == 'حلقات كبس' ||
            category == 'مواسير';
      }
      return category == _selectedCategory;
    }).toList();

    // 2. تطبيق فكرة الـ 25 صورة:
    // إذا كان هناك صور محددة كـ is_featured نعرضها، وإلا نأخذ أول 25 صورة من المعرض
    final featuredDocs = validDocs
        .where((d) => d.data()['is_featured'] == true)
        .toList();
    if (featuredDocs.isNotEmpty) {
      return featuredDocs.take(25).toList();
    }

    return validDocs.take(25).toList();
  }

  void _openImage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> images,
    int index,
  ) {
    AppImageViewerPage.open(
      context,
      imageUrls: images
          .map((doc) => (doc.data()['url'] ?? '').toString())
          .toList(),
      titles: images
          .map((doc) => (doc.data()['category'] ?? 'باريس للستائر').toString())
          .toList(),
      initialIndex: index,
    );
  }

  void _openAccessories() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const AccessoriesGalleryPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _galleryStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return GalleryMessageView(
            icon: Icons.cloud_off_outlined,
            title: 'تعذر تحميل المعرض',
            subtitle: 'راجع اتصال الإنترنت وصلاحيات Firebase.',
            onRetry: () => setState(() {}),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _gold));
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [
          ...(snapshot.data?.docs ?? []),
        ]..sort(_compareGalleryDocs);

        // تصفية أحدث 25 صورة فقط للشاشة الرئيسية
        final images = _filterImages(allDocs);

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1000
                ? 4
                : width >= 650
                ? 3
                : 2;

            return CustomScrollView(
              key: PageStorageKey<String>(_selectedCategory),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // 1. البانر الإعلاني
                SliverToBoxAdapter(
                  child: PromoBanner(
                    images: _bannerImages,
                    index: _bannerIndex,
                    controller: _bannerController,
                    onPageChanged: (index) {
                      setState(() => _bannerIndex = index);
                    },
                    onBrowse: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FullGalleryPage(),
                        ),
                      );
                    },
                  ),
                ),

                // 2. عنوان المجموعات وزر الإكسسوارات
                SliverToBoxAdapter(
                  child: SectionTitle(
                    title: 'تصفّح مجموعتنا',
                    trailing: GoldPillButton(
                      label: 'الإكسسوارات',
                      icon: Icons.auto_awesome,
                      compact: true,
                      onTap: _openAccessories,
                    ),
                  ),
                ),

                // 3. تصنيفات الستائر الأفقية
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 118,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return CategoryTile(
                          label: category == 'ستائر' ? 'كل الستائر' : category,
                          imageUrl: _categoryImages[category]!,
                          selected: category == _selectedCategory,
                          onTap: () {
                            setState(() => _selectedCategory = category);
                          },
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                // 4. عنوان "أحدث الأعمال" مع زر "استعراض المعرض بالكامل"
                SliverToBoxAdapter(
                  child: SectionTitle(
                    title: 'أحدث الأعمال',
                    trailing: CountPill(count: images.length),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // 5. شبكة أحدث 25 صورة
                images.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: GalleryMessageView(
                          icon: Icons.photo_library_outlined,
                          title: 'لا توجد صور هنا بعد',
                          subtitle: _selectedCategory == 'ستائر'
                              ? 'ستظهر صور الستائر هنا عند إضافتها.'
                              : 'لا توجد صور في تصنيف $_selectedCategory حاليًا.',
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final data = images[index].data();
                            final url = ImageUrl.thumbnail(
                              data['url'].toString(),
                            );
                            final category = (data['category'] ?? 'ستائر')
                                .toString();
                            return GalleryImageCard(
                              imageUrl: url,
                              category: category,
                              isDark: isDark,
                              onTap: () => _openImage(images, index),
                            );
                          }, childCount: images.length),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: width < 380 ? 0.76 : 0.78,
                              ),
                        ),
                      ),

                // 6. فوتر نهاية الصفحة (باريس للستائر مع الواتساب والاتصال)
                const SliverToBoxAdapter(child: ParisFooter()),
              ],
            );
          },
        );
      },
    );
  }
}
