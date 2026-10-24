import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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
          title: 'باريس للستائر',
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeManger.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
