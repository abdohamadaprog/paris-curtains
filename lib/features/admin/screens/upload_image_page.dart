import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/upload_widgets.dart';

class UploadImagePage extends StatefulWidget {
  const UploadImagePage({super.key});

  @override
  State<UploadImagePage> createState() => _UploadImagePageState();
}

class _UploadImagePageState extends State<UploadImagePage> {
  // المتغيرات
  List<File> _selectedImages = [];
  final bool _isUploading = false;
  int _currentStep = 0;

  final int _totalImages = 0;
  final int _uploadedCount = 0;

  // خيارات الستاير
  String _selectedCategory = "ويفي";
  String? _selectedHeavy, _selectedLight;

  // خيارات الإكسسوارات
  bool _isAccessoryMode = false;
  String? _selectedAccessoryType;

  double _rating = 5.0;
  final ImagePicker _picker = ImagePicker();

  // القوائم
  final List<String> _accessoryTypes = [
    "تراك ويفي",
    "لمامة",
    "شماعات",
    "أربطة",
    "شيالات",
    "قمقم",
    "مواسير",
    "حلقات كبس",
    "أخرى",
  ];
  final List<String> _heavyFabrics = [
    "قطيفة هامر",
    "قطيفة هامر بلس",
    "قطيفة بوليفار",
    "كتان",
    "كتان بلاك اوت",
    "جلد مقلوب",
    "أخرى",
  ];
  final List<String> _lightFabrics = [
    "كتان سادة",
    "كتان مشجر",
    "كتان تركي",
    "أورجانزا",
    "دانتيل",
    "شيفون",
    "أخرى",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      // زرار الإكسسوارات العائم
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: (_currentStep == 0 && !_isAccessoryMode)
          ? FloatingActionButton.extended(
              onPressed: _pickAccessoryImagesOnly, // 🔥 يفتح الصور علطول
              backgroundColor: AppColors.neonOrange,
              icon: const Icon(Icons.extension, color: Colors.white),
              label: const Text(
                "رفع إكسسوارات",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          : null,

      body: Stack(
        children: [
          _buildGlow(-100, -50, AppColors.neonCyan),
          Positioned(
            bottom: -100,
            right: -50,
            child: _buildGlow(null, null, AppColors.neonOrange),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                // الستيبس تظهر بس لو ستاير
                if (!_isAccessoryMode) NeonStepper(currentStep: _currentStep),

                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
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

  // ================== واجهة الستاير (خطوات) ==================
  Widget _buildCurtainSteps() {
    switch (_currentStep) {
      case 0:
        return _step1SelectImages();
      case 1:
        return _step2Details();
      case 2:
        return _step3RatingAndUpload();
      default:
        return const SizedBox();
    }
  }

  Widget _step1SelectImages() {
    return Column(
      key: const ValueKey(0),
      children: [
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: AppColors.neonCyan.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonCyan.withOpacity(0.1),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 50,
                  color: AppColors.neonCyan,
                ),
                const SizedBox(height: 10),
                const Text(
                  "اضغط لتحديد ستاير (صور متعددة)",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildImageGrid(),
        const SizedBox(height: 40),
        if (_selectedImages.isNotEmpty)
          NeonButton(
            text: "التالي",
            isPrimary: true,
            onTap: () => setState(() => _currentStep = 1),
          ),
      ],
    );
  }

  Widget _step2Details() {
    return Column(
      key: const ValueKey(1),
      children: [
        const Text(
          "بيانات القماش",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.neonOrange,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: GlassSelectionCard(
                title: "قماش ثقيل",
                value: _selectedHeavy,
                icon: Icons.layers,
                onTap: () => _showSheet(
                  "قماش ثقيل",
                  _heavyFabrics,
                  (v) => setState(() => _selectedHeavy = v),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GlassSelectionCard(
                title: "قماش خفيف",
                value: _selectedLight,
                icon: Icons.blur_on,
                onTap: () => _showSheet(
                  "قماش خفيف",
                  _lightFabrics,
                  (v) => setState(() => _selectedLight = v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Text(
          "نوع الستارة",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        _buildCurtainCategoryGrid(),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: NeonButton(
                text: "السابق",
                isPrimary: false,
                onTap: () => setState(() => _currentStep = 0),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: NeonButton(
                text: "التالي",
                isPrimary: true,
                onTap: () {
                  if (_selectedHeavy == null || _selectedLight == null)
                    return _snack("حدد أنواع القماش", Colors.red);
                  setState(() => _currentStep = 2);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================== واجهة الإكسسوارات (الجديدة) ==================
  Widget _buildAccessoryUI() {
    return Column(
      key: const ValueKey("AccessoryUI"),
      children: [
        // زرار اختيار النوع (بيكون أحمر لو لسه محددتش)
        GestureDetector(
          onTap: _showTypeSelectionDialog,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.neonOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.neonOrange),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.category, color: AppColors.neonOrange),
                const SizedBox(width: 10),
                Text(
                  _selectedAccessoryType ?? "اضغط لتحديد نوع الإكسسوار ⚠️",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: _selectedAccessoryType == null
                        ? Colors.redAccent
                        : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        _buildImageGrid(), // الصور ظاهرة
        const SizedBox(height: 30),

        // التقييم (مشترك)
        const Text(
          "تقييم العمل",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (i) => GestureDetector(
              onTap: () => setState(() => _rating = i + 1.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Icon(
                  i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: AppColors.neonGold,
                  size: 40,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 30),
        _isUploading
            ? _buildLoader()
            : Row(
                children: [
                  Expanded(
                    child: NeonButton(
                      text: "إلغاء",
                      isPrimary: false,
                      onTap: () => setState(() {
                        _isAccessoryMode = false;
                        _selectedImages.clear();
                      }),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: NeonButton(
                      text: "نشر",
                      isPrimary: true,
                      onTap: () {
                        if (_selectedAccessoryType == null) {
                          _snack("حدد نوع الإكسسوار!", Colors.red);
                          return;
                        }
                        _uploadAllImages();
                      },
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  // ================== الجزء المشترك ==================
  Widget _step3RatingAndUpload() {
    return Column(
      key: const ValueKey(2),
      children: [
        const SizedBox(height: 40),
        const Text(
          "تقييم العمل",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (i) => GestureDetector(
              onTap: () => setState(() => _rating = i + 1.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Icon(
                  i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: AppColors.neonGold,
                  size: 45,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 60),
        _isUploading
            ? _buildLoader()
            : Column(
                children: [
                  NeonButton(
                    text: "نشر الستاير الآن",
                    isPrimary: true,
                    onTap: _uploadAllImages,
                  ),
                  const SizedBox(height: 15),
                  NeonButton(
                    text: "رجوع",
                    isPrimary: false,
                    onTap: () => setState(() => _currentStep = 1),
                  ),
                ],
              ),
      ],
    );
  }

  // ================== المنطق (Logic) ==================

  // 1. اختيار ستاير
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 60,
      maxWidth: 800,
    );
    if (images.isNotEmpty)
      setState(() => _selectedImages.addAll(images.map((x) => File(x.path))));
  }

  // 2. اختيار إكسسوارات (صور فقط الأول)
  Future<void> _pickAccessoryImagesOnly() async {
    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 60,
      maxWidth: 800,
    );
    if (images.isNotEmpty) {
      setState(() {
        _isAccessoryMode = true;
        _selectedCategory = "إكسسوارات";
        _selectedAccessoryType = null; // لسه محددش النوع
        _selectedImages = images.map((x) => File(x.path)).toList();
      });
    }
  }

  // 3. نافذة اختيار النوع
  void _showTypeSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "اختر النوع",
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _accessoryTypes
                  .map(
                    (t) => ActionChip(
                      label: Text(t),
                      backgroundColor: AppColors.neonOrange,
                      onPressed: () {
                        setState(() => _selectedAccessoryType = t);
                        Navigator.pop(ctx);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // 4. عملية الرفع الموحدة
  Future<void> _uploadAllImages() async {
    // 1. تجميع البيانات عشان لما نخرج تفضل معانا
    final List<File> imagesToUpload = List.from(_selectedImages);
    final String cat = _selectedCategory;
    final String? accType = _selectedAccessoryType;
    final bool isAcc = _isAccessoryMode;
    final String? heavy = _selectedHeavy;
    final String? light = _selectedLight;
    final double rating = _rating;

    // 2. رسالة وخروج فوري (عشان متستناش)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "بدأ الرفع في الخلفية.. يمكنك المتابعة في عملك 🚀",
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
    Navigator.pop(context); // اخرج للداشبورد

    // 3. الشغل في الخلفية
    int successCount = 0;
    for (var imageFile in imagesToUpload) {
      try {
        var req = http.MultipartRequest(
          "POST",
          Uri.parse("https://api.cloudinary.com/v1_1/dlmx10dic/image/upload"),
        );
        req.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );
        req.fields['upload_preset'] = "curtains_upload";

        var res = await req.send();
        if (res.statusCode == 200) {
          var url = jsonDecode(await res.stream.bytesToString())['secure_url'];

          Map<String, dynamic> data = {
            'url': url,
            'category': cat,
            'rating': rating,
            'created_at': FieldValue.serverTimestamp(),
            'sort_order': 0,
          };

          if (isAcc)
            data['accessory_type'] = accType;
          else {
            data['heavy_fabric'] = heavy;
            data['light_fabric'] = light;
          }

          await FirebaseFirestore.instance
              .collection('gallery_images')
              .add(data);
          successCount++;
        }
      } catch (e) {
        debugPrint("Upload error: $e");
      }
    }
    debugPrint("Finished uploading $successCount images");
  }

  // ================== Helpers ==================
  Widget _buildImageGrid() {
    if (_selectedImages.isEmpty) return const SizedBox();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _selectedImages.length,
      itemBuilder: (ctx, i) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              _selectedImages[i],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => setState(() => _selectedImages.removeAt(i)),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() => Column(
    children: [
      CircularProgressIndicator(color: AppColors.neonGold),
      const SizedBox(height: 10),
      Text(
        "جاري رفع $_uploadedCount من $_totalImages",
        style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
      ),
    ],
  );

  Widget _buildCurtainCategoryGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CategoryOptionCard(
                title: "ويفي",
                icon: Icons.waves,
                isSelected: _selectedCategory == "ويفي",
                onTap: () => setState(() => _selectedCategory = "ويفي"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CategoryOptionCard(
                title: "حلقات كبس",
                icon: Icons.circle_outlined,
                isSelected: _selectedCategory == "حلقات كبس",
                onTap: () => setState(() => _selectedCategory = "حلقات كبس"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: CategoryOptionCard(
                title: "مواسير",
                icon: Icons.horizontal_distribute,
                isSelected: _selectedCategory == "مواسير",
                onTap: () => setState(() => _selectedCategory = "مواسير"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CategoryOptionCard(
                title: "بلتكانة",
                icon: Icons.curtains_closed_outlined,
                isSelected: _selectedCategory == "بلتكانة",
                onTap: () => setState(() => _selectedCategory = "بلتكانة"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.all(10),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Center(
            child: Text(
              _isAccessoryMode ? "رفع إكسسوارات" : "إضافة عمل جديد",
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    ),
  );
  Widget _buildGlow(double? t, double? l, Color c) => Container(
    width: 200,
    height: 200,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c.withOpacity(0.15),
      boxShadow: [BoxShadow(color: c, blurRadius: 100)],
    ),
  );

  void _showSheet(String t, List<String> o, Function(String) s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: o
                  .map(
                    (e) => GestureDetector(
                      onTap: () {
                        s(e);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.glassWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.neonCyan.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          e,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, [Color color = Colors.orange]) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: color,
        ),
      );
}
