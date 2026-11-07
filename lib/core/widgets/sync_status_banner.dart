import 'package:flutter/material.dart';

import '../services/sync_status_service.dart';

/// شريط صغير بيبيّن حالة المزامنة: مفيش نت / جاري الرفع / تعديل اترفض.
/// بيختفي خالص لما كل حاجة تمام (الأغلب).
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  static const Color _amber = Color(0xFFFFB020);
  static const Color _sky = Color(0xFF38BDF8);
  static const Color _red = Color(0xFFFF4D5E);

  @override
  Widget build(BuildContext context) {
    final status = SyncStatus.instance;
    return ListenableBuilder(
      listenable: status,
      builder: (context, _) {
        Widget? bar;
        if (status.rejected > 0) {
          bar = _bar(
            color: _red,
            icon: Icons.error_outline_rounded,
            text:
                'السيرفر رفض تعديل اتحفظ على الجهاز. افتح الشغل وراجعه '
                'تاني (غالبًا الحساب مش أدمن).',
            onClose: status.clearRejected,
          );
        } else if (status.offline) {
          bar = _bar(
            color: _amber,
            icon: Icons.cloud_off_rounded,
            text: status.hasPending
                ? 'مفيش نت — التعديلات محفوظة على الجهاز وهتترفع لوحدها '
                      'لما النت يرجع.'
                : 'مفيش نت — كمّل شغلك عادي، وكل حاجة هتتحفظ على الجهاز '
                      'وتترفع بعدين.',
          );
        } else if (status.hasPending) {
          bar = _bar(
            color: _sky,
            icon: Icons.cloud_sync_rounded,
            text: 'جاري رفع التعديلات للسيرفر…',
          );
        }
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: bar ?? const SizedBox(width: double.infinity),
        );
      },
    );
  }

  Widget _bar({
    required Color color,
    required IconData icon,
    required String text,
    VoidCallback? onClose,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          if (onClose != null)
            InkWell(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, color: color, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}
