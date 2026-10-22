import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/theme_manger.dart';
import 'screens/gallery_screen.dart';
import 'screens/search_screen.dart';
import 'widgets/home_app_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManger,
      builder: (context, child) {
        final isDarkMode = themeManger.isDarkMode;

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
                    onSearch: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SearchScreen(),
                        ),
                      );
                    },
                    onThemeToggle: () {
                      themeManger.toggleTheme();
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
