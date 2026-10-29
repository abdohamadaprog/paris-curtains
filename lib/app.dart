import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_manager.dart';
import 'features/splash/splash_screen.dart';

class ParisCurtainsApp extends StatelessWidget {
  const ParisCurtainsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'باريس للستائر',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar')],
          locale: const Locale('ar'),
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeManager.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
