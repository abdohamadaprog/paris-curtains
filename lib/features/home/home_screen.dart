import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_manager.dart';
import 'screens/gallery_screen.dart';
import 'widgets/home_app_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, child) {
        final isDarkMode = themeManager.isDarkMode;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? const [Color(0xFF1C1B25), AppColors.bgDark]
                    : const [AppColors.bgCreamy, AppColors.background],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  HomeAppBar(
                    isDarkMode: isDarkMode,
                    onThemeToggle: () {
                      themeManager.toggleTheme();
                    },
                  ),
                  const Expanded(child: GalleryScreen()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
