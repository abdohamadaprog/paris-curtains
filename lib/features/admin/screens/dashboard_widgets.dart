part of 'admin_dashboard_page.dart';

class _QuickAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // يعيد البناء عند تغيير الثيم
    return Material(
      color: AppPalette.panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: AppPalette.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: AppPalette.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GroupRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // يعيد البناء عند تغيير الثيم
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppPalette.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppPalette.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}

/// ملخص اليوم: مواعيد تركيب النهارده + شغل مفتوح + تعديلات مستنية الرفع.
///
/// الأرقام بتيجي من عدّادات count() اللي بتتحمّل مرة واحدة في الداشبورد،
/// والتعديلات المستنية بتتحدّث لحظيًا من [SyncStatus] من غير أي قراءة سيرفر.
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({
    required this.loading,
    required this.appointments,
    required this.openJobs,
    required this.onTapAppointments,
    required this.onTapOpenJobs,
    required this.onTapPending,
  });

  final bool loading;
  final int appointments;
  final int openJobs;
  final VoidCallback onTapAppointments;
  final VoidCallback onTapOpenJobs;
  final VoidCallback onTapPending;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // يعيد البناء عند تغيير الثيم
    final sync = SyncStatus.instance;
    return AnimatedBuilder(
      animation: sync,
      builder: (context, _) {
        final pending = sync.pendingCount;
        return Container(
          decoration: BoxDecoration(
            color: AppPalette.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  value: loading ? '…' : _ar(appointments),
                  label: 'مواعيد النهارده',
                  icon: Icons.event_available_rounded,
                  color: AppPalette.violet,
                  onTap: onTapAppointments,
                ),
              ),
              _divider(),
              Expanded(
                child: _SummaryTile(
                  value: loading ? '…' : _ar(openJobs),
                  label: 'شغل مفتوح',
                  icon: Icons.local_fire_department_rounded,
                  color: AppPalette.sky,
                  onTap: onTapOpenJobs,
                ),
              ),
              _divider(),
              Expanded(
                child: _SummaryTile(
                  value: pending == 0 ? '✓' : _ar(pending),
                  label: 'مستنية الرفع',
                  icon: pending == 0
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_upload_rounded,
                  color: pending == 0 ? AppPalette.green : AppPalette.gold,
                  onTap: onTapPending,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 46,
    color: AppPalette.line,
  );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
