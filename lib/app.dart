import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/theme_manger.dart';
import 'features/splash/splash_screen.dart';

class ParisCurtainsApp extends StatelessWidget {
  const ParisCurtainsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManger,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'باريس للستاير',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeManger.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
