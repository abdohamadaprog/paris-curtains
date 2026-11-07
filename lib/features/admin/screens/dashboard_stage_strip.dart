part of 'admin_dashboard_page.dart';

/// شريط مراحل الشغل: عدد العملاء في كل مرحلة بلون نيون، واضغط تفتح العملاء مفلترين
class _StageStrip extends StatefulWidget {
  const _StageStrip({required this.onTapStage, required this.refreshToken});

  final ValueChanged<int> onTapStage;
  final int refreshToken;

  @override
  State<_StageStrip> createState() => _StageStripState();
}

class _StageStripState extends State<_StageStrip> {
  static const Map<int, Color> _colors = WorkStage.colors;
  static const Map<int, String> _labels = WorkStage.shortLabels;

  Map<int, int>? _counts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _StageStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  /// بدل ما نحمّل كل العملاء (قراءة لكل مستند)، بنستخدم count() (قراءة واحدة
  /// تقريبًا لكل ١٠٠٠ مستند). العملاء القدام من غير work_stage بيتحسبوا:
  /// تمت = installation_done، والباقي = مرحلة ١ (نفس WorkStage.fromData).
  Future<void> _load() async {
    try {
      final col = FirebaseFirestore.instance.collection('clients');
      final results = await Future.wait([
        col.count().get(),
        col.where('work_stage', isEqualTo: WorkStage.preparing).count().get(),
        col.where('work_stage', isEqualTo: WorkStage.drilled).count().get(),
        col.where('installation_done', isEqualTo: true).count().get(),
        col.where('work_stage', isEqualTo: WorkStage.cancelled).count().get(),
      ]);
      final total = results[0].count ?? 0;
      final preparing = results[1].count ?? 0;
      final drilled = results[2].count ?? 0;
      final done = results[3].count ?? 0;
      final cancelled = results[4].count ?? 0;
      final started = total - preparing - drilled - done - cancelled;
      if (!mounted) return;
      setState(() {
        _counts = {
          1: started < 0 ? 0 : started,
          2: preparing,
          3: drilled,
          4: done,
          5: cancelled,
        };
      });
    } catch (_) {
      // لو فشل (مفيش نت) بنسيب القيم القديمة أو "…"
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts ?? const <int, int>{};
    final loaded = _counts != null;
    final onTapStage = widget.onTapStage;

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
                      const Color(0xFF1E293B),
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
                        loaded ? _ar(counts[stage]) : '…',
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
