import 'package:flutter/material.dart';

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
          body: SafeArea(
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
        );
      },
    );
  }
}
