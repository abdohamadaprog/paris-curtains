import 'package:flutter/material.dart';

import '../../../core/utils/theme_manger.dart';
import '../widgets/gallery_grid.dart';

class AccessoriesGalleryPage extends StatefulWidget {
  const AccessoriesGalleryPage({super.key});

  @override
  State<AccessoriesGalleryPage> createState() => _AccessoriesGalleryPageState();
}

class _AccessoriesGalleryPageState extends State<AccessoriesGalleryPage> {
  static const Color _gold = Color(0xFFD2B477);

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
        final theme = Theme.of(context);
        final background = theme.scaffoldBackgroundColor;
        final textColor = theme.colorScheme.onSurface;
        final accent = _gold;

        return Scaffold(
          backgroundColor: background,
          appBar: AppBar(
            backgroundColor: background,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'كتالوج الإكسسوارات',
              style: TextStyle(
                fontFamily: 'Aref Ruqaa',
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: textColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                tooltip: 'تغيير المظهر',
                onPressed: () => themeManger.toggleTheme(),
                icon: Icon(
                  isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
                  color: accent,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 10),
              SizedBox(
                height: 45,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _accessoryTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = _accessoryTypes[index];
                    final selected = _selectedType == type;

                    return ChoiceChip(
                      label: Text(type),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _selectedType = type);
                      },
                      selectedColor: accent,
                      backgroundColor: isDarkMode
                          ? const Color(0xFF25221D)
                          : const Color(0xFFF3EFE6),
                      side: BorderSide(
                        color: selected
                            ? accent
                            : theme.dividerColor.withOpacity(0.4),
                      ),
                      labelStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: selected ? const Color(0xFF211D15) : textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _gridCount = _gridCount == 4 ? 2 : _gridCount + 1;
                      });
                    },
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: Text('×$_gridCount'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: accent.withOpacity(0.6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: GalleryGrid(
                    category: 'إكسسوارات',
                    accessoryType: _selectedType,
                    isNeonMode: isDarkMode,
                    accentColor: accent,
                    crossAxisCount: _gridCount,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
