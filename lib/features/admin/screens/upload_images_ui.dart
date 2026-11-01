part of 'upload_image_page.dart';

// عرض الصور المختارة ومعاينتها
extension _UploadImagesUi on _UploadImagePageState {
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
                                  _rebuild(() {
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
                                  _rebuild(() {
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
                                    _rebuild(() {
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
                              _rebuild(() {
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
}
