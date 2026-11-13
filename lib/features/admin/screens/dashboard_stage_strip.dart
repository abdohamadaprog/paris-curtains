part of 'admin_dashboard_page.dart';

/// شريط مراحل الشغل: عدد العملاء في كل مرحلة بلون نيون، واضغط تفتح العملاء مفلترين.
///
/// الأرقام بتيجي جاهزة من الداشبورد (count() مرة واحدة لكل مرحلة)، فالودجت
/// ده بقى عرض بس — مفيش قراءات سيرفر هنا.
class _StageStrip extends StatelessWidget {
  const _StageStrip({required this.counts, required this.onTapStage});

  /// null = لسه بيتحمّل. المفاتيح من [WorkStage.all].
  final Map<int, int>? counts;
  final ValueChanged<int> onTapStage;

  static const Map<int, Color> _colors = WorkStage.colors;
  static const Map<int, String> _labels = WorkStage.shortLabels;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // يعيد البناء عند تغيير الثيم
    final loaded = counts != null;
    final onTapStage = this.onTapStage;

    return Row(
      children: [
        for (final stage in WorkStage.all)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: stage == WorkStage.cancelled ? 0 : 6,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTapStage(stage),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      _colors[stage]!.withValues(alpha: 0.10),
                      AppPalette.panel,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _colors[stage]!.withValues(alpha: 0.65),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _colors[stage]!.withValues(alpha: 0.28),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        loaded ? _ar(counts![stage]) : '…',
                        style: TextStyle(
                          color: _colors[stage],
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _labels[stage]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
