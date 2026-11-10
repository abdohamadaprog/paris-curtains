part of 'paris_client_measurements_page.dart';

extension _MeasurementEditPanel on _ParisClientMeasurementsPageState {
  // ============================================================================
  // قائمة منبثقة سريعة بلمسة واحدة للاختيار المباشر (طراز الشغل / السقف)
  // ============================================================================
  Widget _quickSelectMenu<T>({
    required String label,
    required IconData icon,
    required Color color,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T> onSelected,
    TextDecoration? cardDecoration,
    Color? cardDecorColor,
  }) {
    return PopupMenuButton<T>(
      tooltip: 'تغيير سريع',
      color: _panel,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _line),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => items
          .map(
            (e) => PopupMenuItem<T>(
              value: e,
              height: 40,
              child: Text(
                itemLabel(e),
                style: TextStyle(
                  color: AppPalette.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                decoration: cardDecoration,
                decorationColor: cardDecorColor,
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}
