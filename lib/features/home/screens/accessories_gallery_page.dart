import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/theme_manger.dart';
import '../widgets/gallery_grid.dart';
import '../widgets/gallery_widgets.dart';

class AccessoriesGalleryPage extends StatefulWidget {
  const AccessoriesGalleryPage({super.key});

  @override
  State<AccessoriesGalleryPage> createState() => _AccessoriesGalleryPageState();
}

class _AccessoriesGalleryPageState extends State<AccessoriesGalleryPage> {
  String _selectedType = 'الكل';
  int _gridCount = 2;

  static const List<String> _accessoryTypes = [
    'الكل',
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManger,
      builder: (context, child) {
        final isDarkMode = themeManger.isDarkMode;

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? const [Color(0xFF1C1B25), AppColors.bgDark]
                  : const [AppColors.bgCreamy, AppColors.background],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              leadingWidth: 64,
              leading: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14),
                child: Center(
                  child: _CircleIconButton(
                    tooltip: 'رجوع',
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              title: Text(
                'كتالوج الإكسسوارات',
                style: TextStyle(
                  fontFamily: 'Aref Ruqaa',
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  color: isDarkMode ? AppColors.lightGold : AppColors.goldDeep,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 14),
                  child: _CircleIconButton(
                    tooltip: isDarkMode ? 'الوضع الفاتح' : 'الوضع الداكن',
                    icon: isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    onPressed: () => themeManger.toggleTheme(),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                SectionTitle(
                  title: 'اختر نوع الإكسسوار',
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 12),
                  trailing: _GridCountButton(
                    count: _gridCount,
                    onTap: () {
                      setState(() {
                        _gridCount = _gridCount == 4 ? 2 : _gridCount + 1;
                      });
                    },
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _accessoryTypes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final type = _accessoryTypes[index];

                      return _TypeChip(
                        label: type,
                        selected: _selectedType == type,
                        isDark: isDarkMode,
                        onTap: () => setState(() => _selectedType = type),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GalleryGrid(
                    category: 'إكسسوارات',
                    accessoryType: _selectedType,
                    crossAxisCount: _gridCount,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const gold = AppColors.primaryGold;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: gold.withValues(alpha: 0.1),
        shape: CircleBorder(
          side: BorderSide(color: gold.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: gold, size: 20),
          ),
        ),
      ),
    );
  }
}

class _GridCountButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _GridCountButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gold = AppColors.primaryGold;

    return Material(
      color: gold.withValues(alpha: 0.1),
      shape: StadiumBorder(
        side: BorderSide(color: gold.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.grid_view_rounded, size: 16, color: gold),
              const SizedBox(width: 6),
              Text(
                '×$count',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        gradient: selected ? AppColors.goldGradient : null,
        color: selected
            ? null
            : (isDark ? AppColors.surfaceDark : Colors.white),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: selected
              ? AppColors.lightGold
              : AppColors.primaryGold.withValues(alpha: 0.35),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? AppColors.bgDark
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
