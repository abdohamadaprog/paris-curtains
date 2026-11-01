part of 'upload_image_page.dart';

// اختيار الصور والرفع والتأكيدات
extension _UploadActions on _UploadImagePageState {
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

      _rebuild(() {
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

      _rebuild(() {
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

    _rebuild(() {
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

      _rebuild(() {
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
      _rebuild(() {
        _isAccessoryMode = false;
        _selectedAccessoryType = null;
        _selectedCategory = 'ويفي';
        _currentStep = 0;
      });
    }
  }
}
