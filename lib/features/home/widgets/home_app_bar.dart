import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../auth/screens/login_page.dart';
import 'gallery_widgets.dart';

class HomeAppBar extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onSearch;
  final VoidCallback onThemeToggle;

  const HomeAppBar({
    super.key,
    required this.isDarkMode,
    required this.onSearch,
    required this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const gold = AppColors.primaryGold;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? const [AppColors.surfaceDark2, AppColors.surfaceDark]
                  : const [Colors.white, AppColors.bgCreamy],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: gold.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: isDark ? 0.14 : 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // اللوجو: الضغط المطول يفتح تسجيل الدخول
              GestureDetector(
                onLongPress: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                  );
                },
                child: Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.bgDark : Colors.white,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/paris1.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.curtains,
                            color: gold,
                            size: 26,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // اسم المحل والشعار
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GoldText(
                      'باريس',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 18, height: 1.5, color: gold),
                        const SizedBox(width: 6),
                        Text(
                          'لمسة من الفخامة',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _HeaderIconButton(
                tooltip: 'البحث',
                icon: Icons.search_rounded,
                onPressed: onSearch,
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                tooltip: isDarkMode ? 'الوضع الفاتح' : 'الوضع الداكن',
                icon: isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                onPressed: onThemeToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const gold = AppColors.primaryGold;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: gold.withValues(alpha: 0.1),
        shape: CircleBorder(
          side: BorderSide(color: gold.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: gold, size: 22),
          ),
        ),
      ),
    );
  }
}
