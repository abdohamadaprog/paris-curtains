import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../auth/screens/login_page.dart';

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
    final gold = AppColors.primaryGold;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // اللوجو: الضغط المطول يفتح تسجيل الدخول
          GestureDetector(
            onLongPress: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
              );
            },
            child: Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: gold, width: 1.5),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/paris1.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.curtains, color: gold, size: 25);
                  },
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // اسم المحل والشعار
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'باريس',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: gold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'لمسة من الفخامة',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          // البحث
          IconButton(
            tooltip: 'البحث',
            onPressed: onSearch,
            icon: Icon(Icons.search_rounded, color: gold, size: 27),
          ),

          // تغيير الثيم
          IconButton(
            tooltip: isDarkMode ? 'الوضع الفاتح' : 'الوضع الداكن',
            onPressed: onThemeToggle,
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: gold,
            ),
          ),
        ],
      ),
    );
  }
}
