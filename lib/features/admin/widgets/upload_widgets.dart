import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

// 1. شريط الخطوات (Stepper)
class NeonStepper extends StatelessWidget {
  final int currentStep;
  const NeonStepper({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Row(
        children: [
          _buildStep(0, "الصورة"),
          _buildLine(0),
          _buildStep(1, "التفاصيل"),
          _buildLine(1),
          _buildStep(2, "حفظ"),
        ],
      ),
    );
  }

  Widget _buildStep(int index, String title) {
    bool isActive = currentStep >= index;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.neonGold : Colors.transparent,
            border: Border.all(
              color: isActive ? AppColors.neonGold : Colors.white24,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.neonGold.withOpacity(0.6),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.black, size: 20)
                : Text(
                    "${index + 1}",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10,
            color: isActive ? Colors.white : Colors.white24,
          ),
        ),
      ],
    );
  }

  Widget _buildLine(int index) {
    return Expanded(
      child: Container(
        height: 2,
        color: currentStep >= index + 1 ? AppColors.neonGold : Colors.white12,
      ),
    );
  }
}

// 2. زرار نيون (Neon Button)
class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isPrimary;

  const NeonButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppColors.neonGold : Colors.transparent,
          foregroundColor: isPrimary ? Colors.black : Colors.white,
          side: isPrimary ? null : const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// 3. كارت الاختيار الزجاجي (Glass Selection Card)
class GlassSelectionCard extends StatelessWidget {
  final String title;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  const GlassSelectionCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isSelected = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? AppColors.neonGold : Colors.white10,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.neonGold.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.neonGold : Colors.white54,
              size: 24,
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: Colors.white38,
              ),
            ),
            Text(
              value ?? "اختر",
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.white24,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// 4. خيار الفئة (Category Option)
class CategoryOptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryOptionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color activeColor = title == "إكسسوارات"
        ? AppColors.neonOrange
        : AppColors.neonCyan;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.2)
              : AppColors.glassWhite,
          border: Border.all(color: isSelected ? activeColor : Colors.white10),
          borderRadius: BorderRadius.circular(15),
          boxShadow: isSelected
              ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 10)]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : Colors.white54,
              size: 24,
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
