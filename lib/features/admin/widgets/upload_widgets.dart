import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';

class UploadStyle {
  UploadStyle._();

  static Color get gold => AppPalette.gold;
  static Color get goldLight => AppPalette.goldLight;
  static Color get background => AppPalette.bg;
  static Color get surface => AppPalette.panel;
  static Color get surfaceLight => AppPalette.panel2;
  static Color get textPrimary => AppPalette.text;
  static Color get textSecondary => AppPalette.muted;
  static Color get border => AppPalette.line;
  static Color get success => AppPalette.green;
  static Color get danger => AppPalette.red;

  static const double radius = 18;

  static TextStyle get heading => TextStyle(
    fontFamily: 'Cairo',
    fontSize: 17,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static TextStyle get body => TextStyle(
    fontFamily: 'Cairo',
    fontSize: 13,
    color: textSecondary,
  );
}

class NeonStepper extends StatelessWidget {
  final int currentStep;

  const NeonStepper({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // يعيد البناء عند تغيير الثيم
    const labels = ['الصور', 'التفاصيل', 'النشر'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: UploadStyle.surface,
        borderRadius: BorderRadius.circular(UploadStyle.radius),
        border: Border.all(color: UploadStyle.border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            _step(i, labels[i]),
            if (i < labels.length - 1) Expanded(child: _line(i)),
          ],
        ],
      ),
    );
  }

  Widget _step(int index, String label) {
    final completed = currentStep > index;
    final active = currentStep >= index;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? UploadStyle.gold : UploadStyle.surfaceLight,
            border: Border.all(
              color: active ? UploadStyle.gold : UploadStyle.border,
            ),
          ),
          child: Center(
            child: completed
                ? Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: UploadStyle.background,
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: active
                          ? UploadStyle.background
                          : UploadStyle.textSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? UploadStyle.goldLight : UploadStyle.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _line(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 2,
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 20),
      decoration: BoxDecoration(
        color: currentStep > index ? UploadStyle.gold : UploadStyle.border,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

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
    Theme.of(context); // يعيد البناء عند تغيير الثيم
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: isPrimary ? 2 : 0,
          shadowColor: UploadStyle.gold.withValues(alpha: 0.16),
          backgroundColor: isPrimary ? UploadStyle.gold : UploadStyle.surface,
          foregroundColor: isPrimary
              ? UploadStyle.background
              : UploadStyle.textPrimary,
          side: BorderSide(
            color: isPrimary ? UploadStyle.gold : UploadStyle.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

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
    Theme.of(context); // يعيد البناء عند تغيير الثيم
    final selected = value != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? UploadStyle.gold.withValues(alpha: 0.08)
                : UploadStyle.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? UploadStyle.gold : UploadStyle.border,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 25,
                color: selected
                    ? UploadStyle.goldLight
                    : UploadStyle.textSecondary,
              ),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: UploadStyle.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value ?? 'اضغط للاختيار',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? UploadStyle.goldLight
                      : UploadStyle.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    Theme.of(context); // يعيد البناء عند تغيير الثيم
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? UploadStyle.gold.withValues(alpha: 0.09)
                : UploadStyle.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? UploadStyle.gold : UploadStyle.border,
              width: isSelected ? 1.3 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 25,
                color: isSelected
                    ? UploadStyle.goldLight
                    : UploadStyle.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? UploadStyle.goldLight
                      : UploadStyle.textPrimary,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: UploadStyle.gold,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
