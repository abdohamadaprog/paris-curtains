part of 'paris_client_measurements_page.dart';

extension _MeasurementEditPanel on _ParisClientMeasurementsPageState {
  // ============================================================================
  // قائمة منبثقة سريعة بلمسة واحدة للاختيار المباشر
  // ============================================================================
  Widget _quickSelectMenu<T>({
    required String label,
    required String icon,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T> onSelected,
    TextDecoration? cardDecoration,
    Color? cardDecorColor,
  }) {
    return PopupMenuButton<T>(
      tooltip: 'تغيير سريع',
      color: _panel,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _gold.withValues(alpha: 0.3)),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => items
          .map(
            (e) => PopupMenuItem<T>(
              value: e,
              height: 38,
              child: Text(
                itemLabel(e),
                style: TextStyle(
                  color: AppPalette.text,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: AppPalette.successBg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: const Color(0xFF28A745).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✅ $icon ', style: const TextStyle(fontSize: 12.5)),
            Text(
              label,
              style: TextStyle(
                color: AppPalette.mintSoft,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                decoration: cardDecoration,
                decorationColor: cardDecorColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              color: AppPalette.mintSoft,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
