import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../theme/theme_manager.dart';

class ParisFooter extends StatelessWidget {
  const ParisFooter({
    super.key,
    this.phone = '01027867463',
    this.locationText = 'بنها · معاينة وتوصيل لجميع المحافظات',
  });

  final String phone;
  final String locationText;

  // الرقم بصيغة دولية (مصر) مشتق من `phone` عشان يبقى مصدر واحد للرقم
  String get _intlPhone {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('20')) return digits;
    return '20${digits.startsWith('0') ? digits.substring(1) : digits}';
  }

  // 💬 فتح الواتساب مباشرة برقمك
  Future<void> _launchWhatsApp(BuildContext context) async {
    final cleanPhone = _intlPhone;
    final text =
        'السلام عليكم م/ عبده حمادة، استفسار بخصوص ستائر منزلي مع باريس للستائر';
    final encodedText = Uri.encodeComponent(text);

    // الرابط المباشر لتطبيق الواتساب ورابط الويب البديل
    final appUrl = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=$encodedText',
    );
    final webUrl = Uri.parse('https://wa.me/$cleanPhone?text=$encodedText');

    try {
      // 1. محاولة فتح تطبيق الواتساب المثبت
      final launched = await launchUrl(
        appUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        // 2. إذا لم يفتح، افتح رابط المتصفح المباشر للواتساب
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر فتح الواتساب، تأكد من تثبيته: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  // 📞 فتح شاشة الاتصال الهاتفي مباشرة
  Future<void> _launchCall(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      // إطلاق مباشر دون انتظار canLaunchUrl
      final launched = await launchUrl(uri);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح لوحة الاتصال: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, _) {
        final isDark = themeManager.isDarkMode;
        final gold = isDark ? AppColors.lightGold : AppColors.primaryGold;
        final bg = isDark ? const Color(0xFF0B0C12) : const Color(0xFFF4EFE6);
        final textColor = isDark
            ? const Color(0xFFF8F5EF)
            : const Color(0xFF24252E);
        final subtitleColor = isDark
            ? const Color(0xFF9E9E9E)
            : const Color(0xFF616161);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              top: BorderSide(color: gold.withValues(alpha: 0.25), width: 1.2),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. هوية المحل واللوجو
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: gold, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: gold.withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: gold.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.curtains_rounded,
                          color: gold,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'باريس للستائر — Paris Curtains',
                        style: TextStyle(
                          fontFamily: 'Aref Ruqaa',
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: gold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المقر: بنها · إشراف وتنفيذ: م/ عبده حمادة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. أزرار التواصل المباشر (واتساب + اتصال + عنوان)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  // زر واتساب مباشر
                  InkWell(
                    onTap: () => _launchWhatsApp(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF25D366).withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_rounded,
                            size: 15,
                            color: Color(0xFF25D366),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'واتساب ',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // زر الهاتف
                  InkWell(
                    onTap: () => _launchCall(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_in_talk_rounded,
                            size: 15,
                            color: gold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            phone,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // عنوان التوصيل والمعاينة
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_rounded, size: 15, color: gold),
                        const SizedBox(width: 6),
                        Text(
                          locationText,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. حقوق النشر
              Text(
                'جميع الحقوق محفوظة © ${DateTime.now().year} ستائر باريس',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: subtitleColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
