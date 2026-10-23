import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_colors.dart';

class AppImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final List<String>? titles;
  final int initialIndex;

  const AppImageViewerPage({
    super.key,
    required this.imageUrls,
    this.titles,
    this.initialIndex = 0,
  });

  static Future<void> open(
    BuildContext context, {
    required List<String> imageUrls,
    List<String>? titles,
    int initialIndex = 0,
  }) {
    if (imageUrls.isEmpty) return Future.value();

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppImageViewerPage(
          imageUrls: imageUrls,
          titles: titles,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<AppImageViewerPage> createState() => _AppImageViewerPageState();
}

class _AppImageViewerPageState extends State<AppImageViewerPage> {
  late final PageController _pageController;
  late final TransformationController _transform;
  late int _index;
  bool _isDownloading = false;
  bool _zoomed = false;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _index);
    _transform = TransformationController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transform.value = Matrix4.identity();
    _zoomed = false;
  }

  void _onInteractionEnd() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.05;
    if (zoomed != _zoomed) {
      setState(() => _zoomed = zoomed);
    }
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    if (_zoomed || _transform.value.getMaxScaleOnAxis() > 1.05) {
      setState(_resetZoom);
      return;
    }

    final position = details?.localPosition ?? Offset.zero;
    const scale = 3.0;
    final x = -position.dx * (scale - 1);
    final y = -position.dy * (scale - 1);

    setState(() {
      _transform.value = Matrix4.identity()
        ..translateByDouble(x, y, 0.0, 1.0)
        ..scaleByDouble(scale, scale, scale, 1.0);
      _zoomed = true;
    });
  }

  Future<void> _downloadCurrent() async {
    if (_isDownloading) return;

    final url = widget.imageUrls[_index];
    setState(() => _isDownloading = true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري حفظ الصورة في المعرض...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('تعذر تحميل الصورة من الإنترنت');
      }

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception(
            'مفيش صلاحية حفظ الصور. فعّل صلاحية المعرض من الإعدادات.',
          );
        }
      }

      await Gal.putImageBytes(
        response.bodyBytes,
        name: 'paris_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الصورة في المعرض'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ الصورة: $error'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.titles != null && _index < widget.titles!.length)
        ? widget.titles![_index]
        : 'باريس للستاير';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: AppColors.lightGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحميل الصورة',
            onPressed: _isDownloading ? null : _downloadCurrent,
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGold,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.download_rounded,
                    color: AppColors.primaryGold,
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _index = index;
                  _resetZoom();
                });
              },
              itemBuilder: (context, index) {
                final url = widget.imageUrls[index];
                return GestureDetector(
                  onDoubleTapDown: (details) => _doubleTapDetails = details,
                  onDoubleTap: _handleDoubleTap,
                  child: InteractiveViewer(
                    transformationController: index == _index
                        ? _transform
                        : TransformationController(),
                    minScale: 1,
                    maxScale: 8,
                    panEnabled: true,
                    scaleEnabled: true,
                    onInteractionEnd: (_) => _onInteractionEnd(),
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: url,
                        memCacheWidth: 1800,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGold,
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              children: [
                Text(
                  '${_index + 1} / ${widget.imageUrls.length}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.lightGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'قرّب بإصبعين أو دابل تاب للزووم، واسحب بحرية للتفاصيل',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFFB8B5AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
