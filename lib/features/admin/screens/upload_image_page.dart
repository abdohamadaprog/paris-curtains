import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../services/upload_queue_service.dart';
import '../widgets/upload_widgets.dart';

class UploadImagePage extends StatefulWidget {
  const UploadImagePage({super.key});

  @override
  State<UploadImagePage> createState() => _UploadImagePageState();
}

class _UploadImagePageState extends State<UploadImagePage> {
  final ImagePicker _picker = ImagePicker();

  final List<String> _accessoryTypes = [
    'تراك ويفي',
    'لمامة',
    'شماعات',
    'أربطة',
    'شيالات',
    'قمقم',
    'مواسير',
    'حلقات كبس',
    'أخرى',
  ];

  final List<String> _heavyFabrics = [
    'قطيفة هامر',
    'قطيفة هامر بلس',
    'قطيفة بوليفار',
    'كتان',
    'كتان بلاك اوت',
    'جلد مقلوب',
    'أخرى',
  ];

  final List<String> _lightFabrics = [
    'كتان سادة',
    'كتان مشجر',
    'كتان تركي',
    'أورجانزا',
    'دانتيل',
    'شيفون',
    'أخرى',
  ];

  final List<String> _curtainCategories = [
    'ويفي',
    'دابل ويفي',
    'حلقات كبس ومواسير',
    'بلتكانة',
  ];

  final List<XFile> _selectedImages = [];
  final Map<String, Future<Uint8List>> _imageBytesCache = {};

  int _currentStep = 0;

  bool _isUploading = false;
  bool _isAccessoryMode = false;

  String _selectedCategory = 'ويفي';
  String? _selectedHeavy;
  String? _selectedLight;
  String? _selectedAccessoryType;
  final Map<String, String> _imageAccessoryTypes = {};

  double _rating = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UploadStyle.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton:
          (!_isUploading && _currentStep == 0 && !_isAccessoryMode)
          ? FloatingActionButton.extended(
              onPressed: _pickAccessoryImagesOnly,
              backgroundColor: UploadStyle.surfaceLight,
              foregroundColor: UploadStyle.goldLight,
              elevation: 3,
              icon: const Icon(Icons.category_rounded),
              label: const Text(
                'رفع إكسسوارات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (!_isAccessoryMode) ...[
                  const SizedBox(height: 8),
                  NeonStepper(currentStep: _currentStep),
                ],
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isAccessoryMode
                          ? _buildAccessoryUI()
                          : _buildCurtainSteps(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'رجوع',
            onPressed: _isUploading ? null : _confirmExit,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: UploadStyle.textPrimary,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _isAccessoryMode ? 'إضافة إكسسوارات' : 'إضافة عمل جديد',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: UploadStyle.textPrimary,
                  ),
                ),
                const Text(
                  'باريس للستائر',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: UploadStyle.gold,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: UploadStyle.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: UploadStyle.border),
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              color: UploadStyle.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurtainSteps() {
    switch (_currentStep) {
      case 0:
        return _step1SelectImages();
      case 1:
        return _step2Details();
      case 2:
        return _step3RatingAndUpload();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: UploadStyle.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: UploadStyle.goldLight),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: UploadStyle.heading),
              const SizedBox(height: 2),
              Text(subtitle, style: UploadStyle.body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _step1SelectImages() {
    return Column(
      key: const ValueKey('curtain-images'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'صور الشغل',
          'اختار صور واضحة للشغل اللي عايز تضيفه للمعرض',
          Icons.photo_library_outlined,
        ),
        const SizedBox(height: 20),
        _buildPickerCard(
          title: 'اختار صور الستاير',
          subtitle: 'تقدر تختار أكتر من صورة وتراجعها قبل النشر',
          icon: Icons.add_photo_alternate_outlined,
          onTap: _pickImages,
        ),
        const SizedBox(height: 16),
        _buildSelectedImages(),
        const SizedBox(height: 20),
        _buildInfoCard(
          icon: Icons.tips_and_updates_outlined,
          text: 'اختار صور واضحة بإضاءة جيدة عشان تظهر تفاصيل القماش.',
        ),
        const SizedBox(height: 24),
        if (_selectedImages.isNotEmpty)
          NeonButton(
            text: 'التالي • بيانات القماش',
            isPrimary: true,
            onTap: () => setState(() => _currentStep = 1),
          ),
      ],
    );
  }

  Widget _step2Details() {
    return Column(
      key: const ValueKey('curtain-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'بيانات القماش',
          'حدد الخامات المستخدمة في تنفيذ الستارة',
          Icons.layers_outlined,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GlassSelectionCard(
                title: 'قماش ثقيل',
                value: _selectedHeavy,
                icon: Icons.layers_rounded,
                onTap: () => _showSelectionSheet(
                  'اختيار القماش الثقيل',
                  _heavyFabrics,
                  (value) => setState(() => _selectedHeavy = value),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassSelectionCard(
                title: 'قماش خفيف',
                value: _selectedLight,
                icon: Icons.blur_on_rounded,
                onTap: () => _showSelectionSheet(
                  'اختيار القماش الخفيف',
                  _lightFabrics,
                  (value) => setState(() => _selectedLight = value),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const Text('نوع الستارة', style: UploadStyle.heading),
        const SizedBox(height: 5),
        const Text('اختار النوع المناسب للشغل', style: UploadStyle.body),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _curtainCategories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 100,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final category = _curtainCategories[index];
            final icons = <IconData>[
              Icons.waves_rounded,
              Icons.circle_outlined,
              Icons.horizontal_distribute_rounded,
              Icons.curtains_closed_outlined,
            ];

            return CategoryOptionCard(
              title: category,
              icon: icons[index],
              isSelected: _selectedCategory == category,
              onTap: () => setState(() => _selectedCategory = category),
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: NeonButton(
                text: 'السابق',
                isPrimary: false,
                onTap: () => setState(() => _currentStep = 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NeonButton(
                text: 'التالي • التقييم',
                isPrimary: true,
                onTap: () {
                  if (_selectedHeavy == null || _selectedLight == null) {
                    _showMessage(
                      'حدد القماش الثقيل والخفيف الأول.',
                      isError: true,
                    );
                    return;
                  }

                  setState(() => _currentStep = 2);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _step3RatingAndUpload() {
    return Column(
      key: const ValueKey('curtain-publish'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'مراجعة قبل النشر',
          'راجع اختيارك وحدد تقييم العمل',
          Icons.verified_outlined,
        ),
        const SizedBox(height: 20),
        _buildSummaryCard(),
        const SizedBox(height: 24),
        _buildRatingCard(),
        const SizedBox(height: 24),
        NeonButton(
          text: 'نشر الستاير الآن',
          isPrimary: true,
          onTap: _uploadAllImages,
        ),
        const SizedBox(height: 12),
        NeonButton(
          text: 'رجوع للتفاصيل',
          isPrimary: false,
          onTap: () => setState(() => _currentStep = 1),
        ),
      ],
    );
  }

  Widget _buildAccessoryUI() {
    return Column(
      key: const ValueKey('accessory-upload'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'إضافة إكسسوارات',
          'حدد نوع الإكسسوار لكل صورة بجانبها، ثم انشر العمل',
          Icons.category_outlined,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildPickerCard(
                title: 'إضافة صور أخرى',
                subtitle: 'اختار صور جديدة للإكسسوارات',
                icon: Icons.add_photo_alternate_outlined,
                onTap: _pickImages,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildAccessoryImagesList(),
        const SizedBox(height: 24),
        _buildRatingCard(),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: NeonButton(
                text: 'إلغاء',
                isPrimary: false,
                onTap: _confirmCancelAccessoryMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NeonButton(
                text: 'نشر الإكسسوارات',
                isPrimary: true,
                onTap: _uploadAllImages,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccessoryImagesList() {
    if (_selectedImages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: UploadStyle.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: UploadStyle.border),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.photo_size_select_actual_outlined,
              size: 34,
              color: UploadStyle.textSecondary,
            ),
            SizedBox(height: 8),
            Text('لسه مفيش صور مختارة', style: UploadStyle.body),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('الصور وتحديد الأنواع', style: UploadStyle.heading),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: UploadStyle.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_selectedImages.length} صورة',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: UploadStyle.goldLight,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedImages.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final file = _selectedImages[index];
            final currentType = _imageAccessoryTypes[file.path];

            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: UploadStyle.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: UploadStyle.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: _buildImagePreview(file),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          onTap: _isUploading
                              ? null
                              : () {
                                  setState(() {
                                    final removed = _selectedImages.removeAt(
                                      index,
                                    );
                                    _imageBytesCache.remove(removed.path);
                                    _imageAccessoryTypes.remove(removed.path);
                                  });
                                },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'صورة رقم ${index + 1}',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: UploadStyle.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey('${file.path}-$currentType'),
                          initialValue: currentType,
                          isExpanded: true,
                          dropdownColor: UploadStyle.surfaceLight,
                          hint: const Text(
                            'حدد نوع الإكسسوار',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: UploadStyle.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: UploadStyle.surfaceLight,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: currentType == null
                                    ? UploadStyle.border
                                    : UploadStyle.gold,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: UploadStyle.gold,
                              ),
                            ),
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: UploadStyle.gold,
                          ),
                          items: _accessoryTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      color: UploadStyle.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _isUploading
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _imageAccessoryTypes[file.path] = value;
                                    _selectedAccessoryType = value;
                                  });
                                },
                        ),
                        if (currentType != null && _selectedImages.length > 1)
                          TextButton(
                            onPressed: _isUploading
                                ? null
                                : () {
                                    setState(() {
                                      for (final image in _selectedImages) {
                                        _imageAccessoryTypes[image.path] =
                                            currentType;
                                      }
                                      _selectedAccessoryType = currentType;
                                    });
                                  },
                            child: const Text(
                              'تطبيق النوع على كل الصور',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: UploadStyle.goldLight,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPickerCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isUploading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: UploadStyle.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: UploadStyle.gold.withValues(alpha: 0.55)),
          ),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: UploadStyle.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 30, color: UploadStyle.goldLight),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: UploadStyle.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: UploadStyle.body,
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 18,
                    color: UploadStyle.gold,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'اختيار الصور',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: UploadStyle.goldLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedImages() {
    if (_selectedImages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: UploadStyle.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: UploadStyle.border),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.photo_size_select_actual_outlined,
              size: 34,
              color: UploadStyle.textSecondary,
            ),
            SizedBox(height: 8),
            Text('لسه مفيش صور مختارة', style: UploadStyle.body),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('الصور المختارة', style: UploadStyle.heading),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: UploadStyle.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_selectedImages.length} صورة',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: UploadStyle.goldLight,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedImages.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final file = _selectedImages[index];

            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: _buildImagePreview(file),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.72),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isUploading
                          ? null
                          : () {
                              setState(() {
                                final removed = _selectedImages.removeAt(index);
                                _imageBytesCache.remove(removed.path);
                              });
                            },
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UploadStyle.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UploadStyle.border),
      ),
      child: Column(
        children: [
          _summaryRow('عدد الصور', '${_selectedImages.length} صورة'),
          _summaryRow('نوع الستارة', _selectedCategory),
          _summaryRow('القماش الثقيل', _selectedHeavy ?? '—'),
          _summaryRow('القماش الخفيف', _selectedLight ?? '—'),
        ],
      ),
    );
  }

  Widget _summaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: UploadStyle.body)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: UploadStyle.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: UploadStyle.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UploadStyle.border),
      ),
      child: Column(
        children: [
          const Text('تقييم العمل', style: UploadStyle.heading),
          const SizedBox(height: 5),
          const Text(
            'اختار تقييم من نجمة إلى خمس نجوم',
            style: UploadStyle.body,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _isUploading
                    ? null
                    : () => setState(() => _rating = index + 1.0),
                iconSize: 34,
                tooltip: 'تقييم ${index + 1}',
                icon: Icon(
                  index < _rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: UploadStyle.gold,
                ),
              ),
            ),
          ),
          Text(
            '${_rating.toInt()} / 5',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: UploadStyle.goldLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: UploadStyle.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UploadStyle.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: UploadStyle.gold, size: 21),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: UploadStyle.body)),
        ],
      ),
    );
  }

  String _imageExtension(XFile file) {
    final candidate = file.name.isNotEmpty ? file.name : file.path;
    final dot = candidate.lastIndexOf('.');
    return dot < 0 ? '' : candidate.substring(dot + 1).toLowerCase();
  }

  bool _isSupportedImage(XFile file) {
    return const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
    }.contains(_imageExtension(file));
  }

  Widget _buildImagePreview(XFile file) {
    final extension = _imageExtension(file);

    if (extension == 'heic' || extension == 'heif') {
      return Container(
        color: UploadStyle.surfaceLight,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, color: UploadStyle.goldLight, size: 30),
            SizedBox(height: 6),
            Text(
              'HEIC / HEIF',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: UploadStyle.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'ستظهر الصورة بعد الرفع',
              textAlign: TextAlign.center,
              style: TextStyle(color: UploadStyle.textSecondary, fontSize: 9),
            ),
          ],
        ),
      );
    }

    final bytesFuture = _imageBytesCache.putIfAbsent(
      file.path,
      () => file.readAsBytes(),
    );

    return FutureBuilder<Uint8List>(
      future: bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _imagePreviewError(),
          );
        }

        if (snapshot.hasError) {
          return _imagePreviewError();
        }

        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }

  Widget _imagePreviewError() {
    return Container(
      color: UploadStyle.surfaceLight,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: UploadStyle.textSecondary,
      ),
    );
  }

  Future<void> _pickImages() async {
    if (_isUploading) return;

    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 2000,
      );

      if (!mounted || images.isEmpty) return;

      final supportedImages = images.where(_isSupportedImage).toList();

      if (supportedImages.isEmpty) {
        _showMessage(
          'التنسيقات المدعومة: JPG وJPEG وPNG وWebP وHEIC وHEIF.',
          isError: true,
        );
        return;
      }

      setState(() {
        final existing = _selectedImages.map((f) => f.path).toSet();

        for (final image in supportedImages) {
          if (existing.add(image.path)) {
            _selectedImages.add(image);
          }
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Image picker error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage('تعذر اختيار الصور. حاول مرة أخرى.', isError: true);
      }
    }
  }

  Future<void> _pickAccessoryImagesOnly() async {
    if (_isUploading) return;

    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 2000,
      );

      if (!mounted || images.isEmpty) return;

      final supportedImages = images.where(_isSupportedImage).toList();

      if (supportedImages.isEmpty) {
        _showMessage(
          'التنسيقات المدعومة: JPG وJPEG وPNG وWebP وHEIC وHEIF.',
          isError: true,
        );
        return;
      }

      setState(() {
        _isAccessoryMode = true;
        _selectedCategory = 'إكسسوارات';
        _selectedAccessoryType = null;
        _currentStep = 0;

        final existing = _selectedImages.map((f) => f.path).toSet();

        for (final image in supportedImages) {
          if (existing.add(image.path)) {
            _selectedImages.add(image);
          }
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Accessory picker error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage('تعذر اختيار الصور. حاول مرة أخرى.', isError: true);
      }
    }
  }

  Future<void> _showSelectionSheet(
    String title,
    List<String> options,
    ValueChanged<String> onSelected,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: UploadStyle.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: UploadStyle.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 18),
                Text(title, style: UploadStyle.heading),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: options.map((option) {
                        return ActionChip(
                          label: Text(
                            option,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: UploadStyle.textPrimary,
                            ),
                          ),
                          backgroundColor: UploadStyle.surfaceLight,
                          side: const BorderSide(color: UploadStyle.border),
                          onPressed: () {
                            Navigator.pop(sheetContext, option);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      onSelected(selected);
    }
  }

  Future<void> _uploadAllImages() async {
    if (_isUploading) return;

    if (_selectedImages.isEmpty) {
      _showMessage('اختار صورة واحدة على الأقل.', isError: true);
      return;
    }

    if (_isAccessoryMode) {
      for (final file in _selectedImages) {
        if (_imageAccessoryTypes[file.path] == null) {
          _showMessage(
            'يجب تحديد نوع الإكسسوار لكل الصور المختارة.',
            isError: true,
          );
          return;
        }
      }
    }

    if (!_isAccessoryMode &&
        (_selectedHeavy == null || _selectedLight == null)) {
      _showMessage('حدد القماش الثقيل والخفيف الأول.', isError: true);
      return;
    }

    final files = List<XFile>.from(_selectedImages);

    setState(() {
      _isUploading = true;
    });

    try {
      await UploadQueueService.instance.enqueue(
        files: files,
        category: _selectedCategory,
        rating: _rating,
        isAccessory: _isAccessoryMode,
        accessoryType: _selectedAccessoryType,
        fileAccessoryTypes: _isAccessoryMode ? _imageAccessoryTypes : null,
        heavyFabric: _selectedHeavy,
        lightFabric: _selectedLight,
      );

      if (!mounted) return;

      _showMessage(
        'تمت إضافة ${files.length} صورة لطابور الرفع.',
        isError: false,
      );

      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Failed to enqueue images: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      _showMessage(
        'تعذر بدء رفع الصور. راجع الخطأ وحاول مرة أخرى.',
        isError: true,
      );
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: isError
              ? const Color(0xFF8F3535)
              : const Color(0xFF286B4B),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _confirmExit() async {
    if (_isUploading) {
      _showMessage('جاري إضافة الصور لطابور الرفع، استنى لحظة.', isError: true);
      return;
    }

    if (_selectedImages.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: UploadStyle.surface,
          title: const Text(
            'الخروج من الصفحة؟',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: UploadStyle.textPrimary,
            ),
          ),
          content: const Text(
            'الصور المختارة هتتمسح من الاختيارات الحالية.',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: UploadStyle.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: UploadStyle.goldLight,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'خروج',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: UploadStyle.danger,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldExit == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmCancelAccessoryMode() async {
    if (_isUploading) return;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: UploadStyle.surface,
          title: const Text(
            'إلغاء إضافة الإكسسوارات؟',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: UploadStyle.textPrimary,
            ),
          ),
          content: const Text(
            'هترجع لوضع إضافة الستاير، والصور المختارة هتفضل موجودة.',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: UploadStyle.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('متابعة'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'إلغاء الوضع',
                style: TextStyle(color: UploadStyle.danger),
              ),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true && mounted) {
      setState(() {
        _isAccessoryMode = false;
        _selectedAccessoryType = null;
        _selectedCategory = 'ويفي';
        _currentStep = 0;
      });
    }
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: _glow(UploadStyle.gold.withValues(alpha: 0.055)),
          ),
          Positioned(
            bottom: -130,
            right: -110,
            child: _glow(AppColors.primaryGold.withValues(alpha: 0.045)),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 30)],
      ),
    );
  }
}
