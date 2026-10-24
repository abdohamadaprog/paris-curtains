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
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;

  Timer? _navigationTimer;

  static const Color gold = AppColors.primaryGold;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    final titleCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.7, curve: Curves.easeOut),
    );
    _titleFade = titleCurve;
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(titleCurve);

    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.95, curve: Curves.easeIn),
    );

    _controller.forward();

    _navigationTimer = Timer(const Duration(milliseconds: 1300), () {
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
    final backgroundColor = isDark ? AppColors.bgDark : AppColors.background;
    final titleColor = isDark ? AppColors.lightGold : AppColors.goldDeep;
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // إطار اللوجو بحلقة ذهبية متدرجة
                        FadeTransition(
                          opacity: _logoFade,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: Container(
                              width: 158,
                              height: 158,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.goldGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: gold.withValues(alpha: 0.28),
                                    blurRadius: 40,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: backgroundColor,
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
                          ),
                        ),

                        const SizedBox(height: 28),

                        // اسم باريس
                        FadeTransition(
                          opacity: _titleFade,
                          child: SlideTransition(
                            position: _titleSlide,
                            child: Text(
                              'باريس للستائر',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Aref Ruqaa',
                                fontSize: 58,
                                height: 1.35,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                                shadows: [
                                  Shadow(
                                    color: gold.withValues(alpha: 0.3),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // فاصل زخرفي + الشعار + شريط التحميل
                        FadeTransition(
                          opacity: _taglineFade,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _dividerLine(),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Icon(
                                      Icons.auto_awesome,
                                      size: 15,
                                      color: gold,
                                    ),
                                  ),
                                  _dividerLine(),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'فخامة التصميم وأناقة التفصيل الملكي',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 19,
                                  color: mainTextColor,
                                ),
                              ),
                              const SizedBox(height: 40),
                              _progressBar(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: FadeTransition(
                        opacity: _taglineFade,
                        child: Text(
                          'PARIS  •  CURTAINS',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 5,
                            fontWeight: FontWeight.w600,
                            color: gold.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dividerLine() {
    return Container(width: 42, height: 1, color: gold.withValues(alpha: 0.7));
  }

  Widget _progressBar() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            width: 120,
            height: 3,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: gold.withValues(alpha: 0.18)),
                ),
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: _controller.value,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
