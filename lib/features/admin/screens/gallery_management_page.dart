import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/image_url.dart';

class GalleryManagementPage extends StatefulWidget {
  const GalleryManagementPage({super.key});

  @override
  State<GalleryManagementPage> createState() => _GalleryManagementPageState();
}

class _GalleryManagementPageState extends State<GalleryManagementPage> {
  // الفلاتر
  String _selectedCategory = "الكل";
  String _selectedAccessoryType = "الكل";

  final List<String> _categories = [
    "الكل",
    "ويفي",
    "دابل ويفي",
    "حلقات كبس ومواسير",
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

  // دالة الحذف (ستايل نيون)
  Future<void> _deleteImage(String docId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.neonRed.withValues(alpha: 0.5)),
            ),
            title: Text(
              "حذف الصورة؟",
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              "سيتم حذف هذه الصورة نهائياً.",
              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  "إلغاء",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  "حذف",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;
    if (confirm) {
      final ref = FirebaseFirestore.instance
          .collection('gallery_images')
          .doc(docId);
      // نجيب الرابط قبل الحذف عشان نمسح الصورة من Cloudinary كمان
      String? url;
      try {
        url = (await ref.get()).data()?['url']?.toString();
      } catch (_) {}
      await ref.delete();
      if (url != null && url.isNotEmpty) {
        await CloudinaryService.deleteByUrl(url);
      }
      if (mounted) _snack("تم الحذف بنجاح 🗑️", AppColors.neonRed);
    }
  }

  // دالة التعديل (ستايل نيون)
  void _showEditDialog(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String cat = data['category'] ?? "ويفي";
    String? accType = data['accessory_type'];
    String? heavy = data['heavy_fabric'];
    String? light = data['light_fabric'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setSt) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(25),
          decoration: const BoxDecoration(
            color: Color(0xFF101018),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(
              top: BorderSide(color: AppColors.neonCyan, width: 2),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "تعديل البيانات",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neonCyan,
                  ),
                ),
                const SizedBox(height: 25),

                Text(
                  "القسم الرئيسي",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.neonGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories
                      .where((x) => x != "الكل")
                      .map(
                        (k) => _buildChoiceChip(
                          k,
                          cat == k,
                          (v) => setSt(() {
                            cat = k;
                            if (cat == "إكسسوارات") {
                              heavy = null;
                              light = null;
                              accType ??= _accessoryTypes[1];
                            } else {
                              accType = null;
                              heavy ??= _heavyFabrics[0];
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 25),

                if (cat == "إكسسوارات") ...[
                  Text(
                    "نوع الإكسسوار",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildDropdown(
                    accType,
                    _accessoryTypes.where((e) => e != "الكل").toList(),
                    (v) => setSt(() => accType = v),
                  ),
                ] else ...[
                  Text(
                    "قماش ثقيل",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _buildDropdown(
                    heavy,
                    _heavyFabrics,
                    (v) => setSt(() => heavy = v),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "قماش خفيف",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _buildDropdown(
                    light,
                    _lightFabrics,
                    (v) => setSt(() => light = v),
                  ),
                ],

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () async {
                      await doc.reference.update({
                        'category': cat,
                        'accessory_type': accType,
                        'heavy_fabric': heavy,
                        'light_fabric': light,
                      });
                      if (!mounted) return;
                      Navigator.pop(context);
                      _snack("تم التعديل بامتياز ✨", AppColors.neonGreen);
                    },
                    child: Text(
                      "حفظ التغييرات",
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text(
          "إدارة المعرض",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 1. الفلتر الرئيسي
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 10),
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
                }),
              ),
            ),
          ),

          // 2. الفلتر الفرعي
          if (_selectedCategory == "إكسسوارات")
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _accessoryTypes.length,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemBuilder: (ctx, i) => _buildSubFilterChip(
                  _accessoryTypes[i],
                  _selectedAccessoryType == _accessoryTypes[i],
                  () => setState(
                    () => _selectedAccessoryType = _accessoryTypes[i],
                  ),
                ),
              ),
            ),

          // 3. الشبكة
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Keep legacy image records even if created_at was never set.
              stream: FirebaseFirestore.instance
                  .collection('gallery_images')
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.neonGold),
                  );
                }

                var docs = snap.data!.docs.toList()
                  ..sort((a, b) {
                    final ad = a.data() as Map<String, dynamic>;
                    final bd = b.data() as Map<String, dynamic>;
                    final at = ad['created_at'];
                    final bt = bd['created_at'];
                    final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                    final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                    final byDate = bm.compareTo(am);
                    return byDate != 0 ? byDate : a.id.compareTo(b.id);
                  });
                docs = docs.where((d) {
                  var data = d.data() as Map<String, dynamic>;
                  if (_selectedCategory == "الكل") {
                    return data['category'] != "إكسسوارات";
                  } else if (_selectedCategory == "إكسسوارات") {
                    bool isAcc = data['category'] == "إكسسوارات";
                    if (_selectedAccessoryType != "الكل") {
                      return isAcc &&
                          data['accessory_type'] == _selectedAccessoryType;
                    }
                    return isAcc;
                  }
                  return data['category'] == _selectedCategory;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Colors.white12,
                        ),
                        SizedBox(height: 10),
                        Text(
                          "القسم فارغ",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    var d = docs[i];
                    var data = d.data() as Map<String, dynamic>;

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white12),
                        color: const Color(0xFF1E1E2C),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: ImageUrl.thumbnail(
                                  data['url'].toString(),
                                ),
                                fit: BoxFit.cover,
                                placeholder: (c, u) =>
                                    Container(color: Colors.white10),
                              ),
                            ),
                          ),
                          Container(
                            height: 35,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2A2A3D),
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(15),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                InkWell(
                                  onTap: () => _deleteImage(d.id),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.neonRed,
                                    size: 20,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  color: Colors.white12,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _showEditDialog(d),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: AppColors.neonCyan,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---
  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.neonGold
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppColors.neonGold : Colors.white12,
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
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.neonOrange : Colors.white24,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(
    String label,
    bool isSelected,
    Function(bool) onSelect,
  ) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.neonGold,
      backgroundColor: Colors.white10,
      onSelected: onSelect,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildDropdown(
    String? val,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButton<String>(
        value: val,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E1E2C),
        underline: const SizedBox(),
        style: TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
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
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );
}
