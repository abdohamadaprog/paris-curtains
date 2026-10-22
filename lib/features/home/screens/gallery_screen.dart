import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../widgets/app_image_viewer.dart';
import 'accessories_gallery_page.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const Color _gold = AppColors.primaryGold;
  static const Color _black = AppColors.bgDark;
  static const Color _cardDark = AppColors.surfaceDark;

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
          setState(() {
            _bannerImages = urls;
            if (_bannerIndex >= urls.length) _bannerIndex = 0;
          });
          _startBannerTimer();
        });
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    if (_bannerImages.length <= 1) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !_bannerController.hasClients || _bannerImages.length <= 1) {
        return;
      }

      final nextIndex = (_bannerIndex + 1) % _bannerImages.length;
      _bannerController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 650),
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _galleryStream() {
    return FirebaseFirestore.instance
        .collection('gallery_images')
        .orderBy('sort_order')
        .snapshots();
  }

  String _optimizedUrl(String url) {
    if (url.contains('cloudinary.com') && url.contains('/upload/')) {
      return url.replaceFirst('/upload/', '/upload/q_auto/');
    }
    return url;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterImages(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      final category = (data['category'] ?? 'عام').toString();
      final url = data['url'];

      if (category == 'إكسسوارات') return false;
      if (url is! String || url.trim().isEmpty) return false;

      // تصنيف "ستائر" يعرض جميع صور الستائر.
      if (_selectedCategory == 'ستائر') return true;

      if (_selectedCategory == 'حلقات كبس ومواسير') {
        return category == 'حلقات كبس ومواسير' || category == 'حلقات كبس' || category == 'مواسير';
      }

      return category == _selectedCategory;
    }).toList();
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
          .map((doc) => (doc.data()['category'] ?? 'باريس للستاير').toString())
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _galleryStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MessageView(
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

        final allDocs = snapshot.data?.docs ?? [];
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
                // البانر المتحرك
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: SizedBox(
                      height: 165,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              controller: _bannerController,
                              itemCount: _bannerImages.isEmpty
                                  ? 1
                                  : _bannerImages.length,
                              onPageChanged: (index) {
                                setState(() => _bannerIndex = index);
                              },
                              itemBuilder: (context, index) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_bannerImages.isEmpty)
                                      Container(
                                        color: _cardDark,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.photo_library_outlined,
                                          color: _gold,
                                          size: 40,
                                        ),
                                      )
                                    else
                                      CachedNetworkImage(
                                        imageUrl: _bannerImages[index],
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(color: _black),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              color: _cardDark,
                                              child: const Icon(
                                                Icons.image_not_supported_outlined,
                                                color: _gold,
                                                size: 40,
                                              ),
                                            ),
                                      ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerRight,
                                          end: Alignment.centerLeft,
                                          colors: [
                                            _black.withValues(alpha: 0.96),
                                            _black.withValues(alpha: 0.76),
                                            Colors.transparent,
                                          ],
                                          stops: const [0, 0.52, 1],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            PositionedDirectional(
                              start: 18,
                              top: 0,
                              bottom: 18,
                              child: Center(
                                child: SizedBox(
                                  width: 205,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'أجمل الستائر',
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          color: _gold,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'تصاميم عصرية تليق بمنزلك',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton(
                                        onPressed: () {
                                          setState(() => _selectedCategory = 'ستائر');
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _gold,
                                          side: const BorderSide(color: _gold),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'استعرض المعرض',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(color: _gold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _bannerImages.isEmpty ? 1 : _bannerImages.length,
                                  (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: _bannerIndex == index ? 19 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _bannerIndex == index
                                          ? _gold
                                          : Colors.white60,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // عنوان المجموعات وزر الإكسسوارات الصغير
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.grid_view_rounded, color: _gold, size: 21),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'تصفّح مجموعتنا',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: _gold.withValues(alpha: isDark ? 0.13 : 0.16),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: _openAccessories,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.75),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    color: _gold,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'الإكسسوارات',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: _gold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // تصنيفات الستائر
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 96,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._categories.map((category) {
                          final selected = category == _selectedCategory;
                          final isAllCurtains = category == 'ستائر';

                          return Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: SizedBox(
                              width: isAllCurtains ? 60 : 88,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(13),
                                onTap: () {
                                  setState(() => _selectedCategory = category);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: _gold,
                                      width: selected ? 1.4 : 0.7,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: _categoryImages[category]!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(color: _cardDark),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              color: _cardDark,
                                              child: const Icon(
                                                Icons.image_outlined,
                                                color: _gold,
                                                size: 22,
                                              ),
                                            ),
                                      ),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withValues(alpha: 0.05),
                                              Colors.black.withValues(alpha: 0.88),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isAllCurtains ? 2 : 4,
                                            vertical: 6,
                                          ),
                                          child: Text(
                                            category,
                                            maxLines: 2,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: selected
                                                      ? const Color(0xFFFFE8B2)
                                                      : Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: isAllCurtains ? 9 : 10,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                // عنوان المعرض وعدد الصور
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          color: _gold,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'أحدث الأعمال',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${images.length} صورة',
                          style: theme.textTheme.bodySmall?.copyWith(color: _gold),
                        ),
                      ],
                    ),
                  ),
                ),

                // شبكة الصور (SliverGrid)
                images.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MessageView(
                          icon: Icons.photo_library_outlined,
                          title: 'لا توجد صور هنا بعد',
                          subtitle: _selectedCategory == 'ستائر'
                              ? 'ستظهر صور الستائر هنا عند إضافتها.'
                              : 'لا توجد صور في تصنيف $_selectedCategory حاليًا.',
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final data = images[index].data();
                              final url = _optimizedUrl(data['url'].toString());
                              final category = (data['category'] ?? 'ستائر')
                                  .toString();

                              return Material(
                                color: isDark ? _cardDark : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _openImage(images, index),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _gold.withValues(alpha: 0.55),
                                      ),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Hero(
                                          tag: url,
                                          child: CachedNetworkImage(
                                            imageUrl: url,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: _gold,
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                            errorWidget: (context, url, error) =>
                                                const Center(
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Colors.grey,
                                                    size: 36,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        const DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Color(0xD9000000),
                                              ],
                                              stops: [0.48, 1],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 9,
                                          left: 9,
                                          bottom: 10,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  category,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                              const Icon(
                                                Icons.zoom_in_rounded,
                                                color: _gold,
                                                size: 21,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: images.length,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: width < 380 ? 0.76 : 0.78,
                          ),
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const _MessageView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: _GalleryScreenState._gold),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

