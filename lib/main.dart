import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easy_localization/easy_localization.dart';

import 'firebase_options.dart';
import 'app.dart';
import 'core/theme/theme_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupErrorHandling();
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  await themeManager.loadTheme();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      startLocale: const Locale('ar'),
      child: const ParisCurtainsApp(),
    ),
  );
}

/// Firebase App Check: بيثبت إن الطلبات جاية من تطبيقك الأصلي مش من سكربت.
/// في الـ debug بيستخدم debug provider (التوكن بيظهر في اللوج وبتضيفه في Console).
Future<void> _activateAppCheck() async {
  if (kIsWeb) return; // الويب محتاج مفتاح reCAPTCHA منفصل
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleAppAttestWithDeviceCheckFallbackProvider()
          : const AppleDebugProvider(),
    );
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
}

/// معالجة الأخطاء: أي خطأ بيتسجّل (بدل ما يضيع)، وفي نسخة الإصدار المستخدم
/// بيشوف رسالة هادية بدل الشاشة الرمادية/الحمراء.
/// لما تضيف Crashlytics بعدين، حط الإرسال في المكانين اللي تحت.
void _setupErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'حصلت مشكلة في عرض الجزء ده. ارجع وافتحه تاني.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ),
        ),
      );
    };
  }
}
