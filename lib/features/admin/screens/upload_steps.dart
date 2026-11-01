part of 'upload_image_page.dart';

// خطوات الرفع (اختيار الصور، التفاصيل، التقييم) وكروت الملخص
extension _UploadSteps on _UploadImagePageState {
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
            onTap: () => _rebuild(() => _currentStep = 1),
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
                  (value) => _rebuild(() => _selectedHeavy = value),
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
                  (value) => _rebuild(() => _selectedLight = value),
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
              onTap: () => _rebuild(() => _selectedCategory = category),
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
                onTap: () => _rebuild(() => _currentStep = 0),
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

                  _rebuild(() => _currentStep = 2);
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
          onTap: () => _rebuild(() => _currentStep = 1),
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
                    : () => _rebuild(() => _rating = index + 1.0),
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
}
