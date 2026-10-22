import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// نص بتدرج ذهبي فاخر.
class GoldText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const GoldText(this.text, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
      child: Text(
        text,
        textAlign: textAlign,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

/// زر ذهبي بحواف دائرية.
class GoldPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool compact;

  const GoldPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGold.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 18,
              vertical: compact ? 7 : 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.bgDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 6),
                  Icon(icon, size: 16, color: AppColors.bgDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// عنوان قسم بشريط ذهبي جانبي.
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.lightGold, AppColors.goldDeep],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// كبسولة عدد الصور.
class CountPill extends StatelessWidget {
  final int count;

  const CountPill({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$count صورة',
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.primaryGold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// البانر الإعلاني المتحرك في أعلى الصفحة.
class PromoBanner extends StatelessWidget {
  final List<String> images;
  final int index;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBrowse;

  const PromoBanner({
    super.key,
    required this.images,
    required this.index,
    required this.controller,
    required this.onPageChanged,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = images.isEmpty ? 1 : images.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: AppColors.primaryGold.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGold.withValues(alpha: 0.18),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: controller,
                itemCount: count,
                onPageChanged: onPageChanged,
                itemBuilder: (context, i) {
                  if (images.isEmpty) {
                    return const ColoredBox(
                      color: AppColors.surfaceDark,
                      child: Center(
                        child: Icon(
                          Icons.photo_library_outlined,
                          color: AppColors.primaryGold,
                          size: 40,
                        ),
                      ),
                    );
                  }

                  return CachedNetworkImage(
                    imageUrl: images[i],
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const ColoredBox(color: AppColors.bgDark),
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: AppColors.surfaceDark,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.primaryGold,
                          size: 40,
                        ),
                      ),
                    ),
                  );
                },
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        AppColors.bgDark.withValues(alpha: 0.95),
                        AppColors.bgDark.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: 22,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SizedBox(
                    width: 220,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryGold.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          child: Text(
                            'تشكيلة مميزة',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.lightGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GoldText(
                          'أجمل الستائر',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تصاميم عصرية تليق بمنزلك',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GoldPillButton(
                          label: 'استعرض المعرض',
                          icon: Icons.arrow_back_rounded,
                          onTap: onBrowse,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                end: 18,
                bottom: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    count,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: index == i ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: index == i
                            ? AppColors.lightGold
                            : Colors.white54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة تصنيف في الشريط الأفقي.
class CategoryTile extends StatelessWidget {
  final String label;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const CategoryTile({
    super.key,
    required this.label,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 94,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? AppColors.lightGold
              : AppColors.primaryGold.withValues(alpha: 0.3),
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const ColoredBox(color: AppColors.surfaceDark),
              errorWidget: (context, url, error) => const ColoredBox(
                color: AppColors.surfaceDark,
                child: Icon(
                  Icons.image_outlined,
                  color: AppColors.primaryGold,
                  size: 22,
                ),
              ),
            ),
            if (!selected)
              ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? AppColors.lightGold : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ),
            ),
            if (selected)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.bgDark,
                  ),
                ),
              ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة صورة في شبكة المعرض.
class GalleryImageCard extends StatelessWidget {
  final String imageUrl;
  final String category;
  final bool isDark;
  final VoidCallback onTap;
  final bool compact;

  const GalleryImageCard({
    super.key,
    required this.imageUrl,
    required this.category,
    required this.isDark,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : AppColors.primaryGold.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const ColoredBox(
                  color: AppColors.surfaceDark,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGold,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => const ColoredBox(
                  color: AppColors.surfaceDark,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE6000000)],
                    stops: [0.55, 1],
                  ),
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: compact ? 6 : 10,
                end: compact ? 6 : 10,
                bottom: compact ? 6 : 10,
                child: Row(
                  children: [
                    if (compact)
                      const Spacer()
                    else ...[
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryGold.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            child: Text(
                              category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      width: compact ? 24 : 30,
                      height: compact ? 24 : 30,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.goldGradient,
                      ),
                      child: Icon(
                        Icons.zoom_in_rounded,
                        size: compact ? 15 : 18,
                        color: AppColors.bgDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// رسالة حالة (خطأ / لا توجد صور).
class GalleryMessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const GalleryMessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGold.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.primaryGold.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(icon, size: 34, color: AppColors.primaryGold),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              GoldPillButton(
                label: 'إعادة المحاولة',
                icon: Icons.refresh_rounded,
                onTap: onRetry!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
