import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'accessories_gallery_page.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const Color _gold = Color(0xFFD2B477);
  static const Color _black = Color(0xFF10100F);
  static const Color _cardDark = Color(0xFF201F1C);

  static const List<String> _categories = [
    'ستائر',
    'ويفي',
    'دابل ويفي',
    'حلقات كبس ومواسير',
    'بلتكانة',
  ];

  static const List<String> _bannerImages = [
    'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?auto=format&fit=crop&w=1200&q=75',
    'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=format&fit=crop&w=1200&q=75',
    'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=1200&q=75',
  ];

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

    _bannerTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !_bannerController.hasClients) return;

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
        return category == 'حلقات كبس' || category == 'مواسير';
      }

      return category == _selectedCategory;
    }).toList();
  }

  void _openImage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> images,
    int index,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _GalleryViewer(
          images: images,
          initialIndex: index,
          optimizedUrl: _optimizedUrl,
        ),
      ),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // البانر المتحرك
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: SizedBox(
                height: 165,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        controller: _bannerController,
                        itemCount: _bannerImages.length,
                        onPageChanged: (index) {
                          setState(() => _bannerIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: _bannerImages[index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Container(color: _black),
                                errorWidget: (context, url, error) => Container(
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
                            _bannerImages.length,
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

            // عنوان المجموعات وزر الإكسسوارات الصغير
            Padding(
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

            // تصنيفات الستائر؛ تصنيف "ستائر" أصغر من بقية التصنيفات
            SizedBox(
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

            const SizedBox(height: 14),

            // عنوان المعرض وعدد الصور
            Padding(
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

            // المعرض يأخذ باقي المساحة
            Expanded(
              child: images.isEmpty
                  ? _MessageView(
                      icon: Icons.photo_library_outlined,
                      title: 'لا توجد صور هنا بعد',
                      subtitle: _selectedCategory == 'ستائر'
                          ? 'ستظهر صور الستائر هنا عند إضافتها.'
                          : 'لا توجد صور في تصنيف $_selectedCategory حاليًا.',
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width >= 1000
                            ? 4
                            : width >= 650
                            ? 3
                            : 2;

                        return GridView.builder(
                          key: PageStorageKey<String>(_selectedCategory),
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 18),
                          itemCount: images.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: width < 380 ? 0.76 : 0.78,
                              ),
                          itemBuilder: (context, index) {
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
                        );
                      },
                    ),
            ),
          ],
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

class _GalleryViewer extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> images;
  final int initialIndex;
  final String Function(String) optimizedUrl;

  const _GalleryViewer({
    required this.images,
    required this.initialIndex,
    required this.optimizedUrl,
  });

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.images[_index].data();
    final title = (data['category'] ?? 'باريس للستاير').toString();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF11100E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11100E),
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFFD2B477),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() => _index = index);
              },
              itemBuilder: (context, index) {
                final imageData = widget.images[index].data();
                final url = widget.optimizedUrl(imageData['url'].toString());

                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: url,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFD2B477),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_index + 1} / ${widget.images.length}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFD2B477),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
