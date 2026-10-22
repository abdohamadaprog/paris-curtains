import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';

class GalleryReorderPage extends StatefulWidget {
  const GalleryReorderPage({super.key});

  @override
  State<GalleryReorderPage> createState() => _GalleryReorderPageState();
}

class _GalleryReorderPageState extends State<GalleryReorderPage> {
  List<DocumentSnapshot> _allImages = [];
  bool _isLoading = true;
  int? _selectedIndex;

  String _selectedCategory = "الكل";
  String _selectedAccessoryType = "الكل";

  final List<String> _categories = [
    "الكل",
    "ويفي",
    "حلقات كبس",
    "مواسير",
    "بلتكانة",
    "إكسسوارات",
  ];
  final List<String> _accessoryTypes = [
    "الكل",
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

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    setState(() => _isLoading = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('gallery_images')
          .get();
      _allImages = query.docs.toList()
        ..sort((a, b) {
          final ad = a.data();
          final bd = b.data();
          final ao = ad['sort_order'];
          final bo = bd['sort_order'];
          if (ao is num && bo is num) {
            final byOrder = ao.compareTo(bo);
            if (byOrder != 0) return byOrder;
          } else if ((ao is num) != (bo is num)) {
            return ao is num ? -1 : 1;
          }
          final at = ad['created_at'];
          final bt = bd['created_at'];
          final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
          final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
          return bm.compareTo(am);
        });
    } catch (error) {
      if (mounted) _snack('تعذر تحميل صور المعرض: $error', Colors.red);
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _onImageTap(DocumentSnapshot doc) {
    int realIndex = _allImages.indexOf(doc);
    setState(() {
      if (_selectedIndex == null) {
        _selectedIndex = realIndex;
      } else {
        final temp = _allImages[_selectedIndex!];
        _allImages[_selectedIndex!] = _allImages[realIndex];
        _allImages[realIndex] = temp;
        _selectedIndex = null;
      }
    });
  }

  // 3. حفظ الترتيب النهائي
  Future<void> _saveOrder() async {
    setState(() => _isLoading = true);
    try {
      // Firestore batches have a 500-write limit. Keep a safety margin and
      // commit in chunks so a larger gallery can still be reordered.
      for (var start = 0; start < _allImages.length; start += 450) {
        final batch = FirebaseFirestore.instance.batch();
        final end = (start + 450 < _allImages.length)
            ? start + 450
            : _allImages.length;
        for (var i = start; i < end; i++) {
          batch.update(_allImages[i].reference, {'sort_order': i});
        }
        await batch.commit();
      }

      if (mounted) {
        _snack("تم حفظ الترتيب بنجاح ✅", Colors.green);

        // 🔥🔥 التعديل هنا: استنى نص ثانية واخرج 🔥🔥
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context); // دي اللي بترجعك للداشبورد
      }
    } catch (e) {
      if (mounted) _snack("حدث خطأ", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var displayList = _allImages.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      if (_selectedCategory == "الكل") {
        return data['category'] != "إكسسوارات";
      } else if (_selectedCategory == "إكسسوارات") {
        bool isAcc = data['category'] == "إكسسوارات";
        if (_selectedAccessoryType != "الكل") {
          return isAcc && data['accessory_type'] == _selectedAccessoryType;
        }
        return isAcc;
      }
      return data['category'] == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text(
          "ترتيب المعرض",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _saveOrder,
                icon: const Icon(Icons.save, color: Colors.white, size: 18),
                label: Text(
                  "حفظ",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (ctx, i) => _buildFilterChip(
                _categories[i],
                _selectedCategory == _categories[i],
                () => setState(() {
                  _selectedCategory = _categories[i];
                  _selectedAccessoryType = "الكل";
                  _selectedIndex = null;
                }),
              ),
            ),
          ),
          if (_selectedCategory == "إكسسوارات")
            Container(
              height: 40,
              margin: const EdgeInsets.only(top: 5),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _accessoryTypes.length,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemBuilder: (ctx, i) => _buildSubFilterChip(
                  _accessoryTypes[i],
                  _selectedAccessoryType == _accessoryTypes[i],
                  () => setState(() {
                    _selectedAccessoryType = _accessoryTypes[i];
                    _selectedIndex = null;
                  }),
                ),
              ),
            ),
          const SizedBox(height: 10),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonGold),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: displayList.length,
                    itemBuilder: (ctx, i) {
                      var doc = displayList[i];
                      var data = doc.data() as Map<String, dynamic>;
                      bool isSelected =
                          _selectedIndex != null &&
                          _allImages[_selectedIndex!] == doc;

                      return GestureDetector(
                        onTap: () => _onImageTap(doc),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.neonGreen
                                  : Colors.transparent,
                              width: 3,
                            ), // 🔥🔥 البرواز النيون الأخضر
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.neonGreen.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 15,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: CachedNetworkImage(
                                  imageUrl: data['url'],
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) =>
                                      Container(color: Colors.white10),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.swap_vert_circle,
                                      color: AppColors.neonGreen,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 5,
                                right: 5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    "${_allImages.indexOf(doc) + 1}",
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              if (_selectedCategory == "إكسسوارات")
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    color: Colors.black54,
                                    child: Text(
                                      data['accessory_type'] ?? "",
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Colors.black26,
            child: Text(
              _selectedIndex == null
                  ? "حدد صورة لتبديل مكانها"
                  : "اضغط على المكان الجديد",
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets (Neon Style) ---
  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.neonCyan
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.neonCyan : Colors.white12,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? AppColors.neonOrange : Colors.grey,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
}
