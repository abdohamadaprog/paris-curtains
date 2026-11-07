import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app.dart';
import 'core/theme/theme_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupErrorHandling();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App Check مش شرط يخلص قبل فتح التطبيق: لو اتأخر (نت بطيء) مش هنوقف
  // شاشة البداية عشانه. بيشتغل في الخلفية والطلبات بتاخد التوكن أول ما يجهز.
  unawaited(_activateAppCheck());
  await themeManager.loadTheme();
  runApp(const ParisCurtainsApp());
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

  // بدل الشاشة الحمراء: في النسخة التجريبية بنعرض الخطأ نفسه بشكل مقروء
  // (وزرار نسخ) عشان يبقى سهل تبعته، وفي نسخة المستخدمين رسالة هادية.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!kDebugMode) {
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
    }

    final text = details.exceptionAsString();
    return Container(
      color: const Color(0xFF2A1416),
      padding: const EdgeInsets.all(12),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'حصل خطأ في الجزء ده',
              style: TextStyle(
                color: Color(0xFFFF9A9A),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              textDirection: ui.TextDirection.ltr,
              style: const TextStyle(
                color: Color(0xFFEDEDED),
                fontSize: 11,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: text)),
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text(
                  'انسخ الخطأ وابعته',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  };
}
