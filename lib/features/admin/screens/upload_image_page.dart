import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../services/upload_queue_service.dart';
import '../widgets/upload_widgets.dart';

part 'upload_steps.dart';
part 'upload_images_ui.dart';
part 'upload_actions.dart';

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

  /// setState لأجزاء الواجهة المنقولة لملفات part
  void _rebuild(VoidCallback fn) => setState(fn);

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
