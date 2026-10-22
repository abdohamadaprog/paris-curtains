import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  Timer? _navigationTimer;

  static const Color gold = AppColors.primaryGold;
  static const Color darkBackground = AppColors.bgDark;
  static const Color lightBackground = AppColors.background;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ));

    _controller.forward();

    _navigationTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark ? darkBackground : lightBackground;

    final mainTextColor = isDark
        ? const Color(0xFFF8F2E7)
        : const Color(0xFF29241B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF201C16),
                    Color(0xFF11100E),
                    Color(0xFF080807),
                  ]
                : const [
                    Color(0xFFFFFDF8),
                    Color(0xFFF4EDDF),
                    Color(0xFFE9DFC9),
                  ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // لمسات ذهبية هادئة في الخلفية
            Positioned(top: -95, right: -75, child: _glowCircle(isDark, 230)),
            Positioned(
              bottom: -110,
              left: -85,
              child: _glowCircle(isDark, 260),
            ),

            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // إطار اللوجو
                        Container(
                          width: 154,
                          height: 154,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: gold, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: gold.withValues(alpha: 0.13),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: gold.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/paris1.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.curtains,
                                    size: 68,
                                    color: gold,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // اسم باريس في منتصف الشاشة
                        Text(
                          'باريس',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Aref Ruqaa',
                            fontSize: 58,
                            height: 1.35,
                            fontWeight: FontWeight.bold,
                            color: gold,
                            shadows: [
                              Shadow(
                                color: gold.withValues(alpha: 0.22),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // فاصل زخرفي ذهبي
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 42,
                              height: 1,
                              color: gold.withValues(alpha: 0.7),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(
                                Icons.auto_awesome,
                                size: 15,
                                color: gold,
                              ),
                            ),
                            Container(
                              width: 42,
                              height: 1,
                              color: gold.withValues(alpha: 0.7),
                            ),
                          ],
                        ),

                        const SizedBox(height: 17),

                        Text(
                          'لمسة من الفخامة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 19,
                            letterSpacing: 0.5,
                            color: mainTextColor,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // مؤشر تحميل بسيط وأنيق
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: gold.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowCircle(bool isDark, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            gold.withValues(alpha: isDark ? 0.09 : 0.15),
            gold.withValues(alpha: 0.025),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
