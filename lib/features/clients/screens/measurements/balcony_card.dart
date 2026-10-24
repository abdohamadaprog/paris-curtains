part of '../paris_client_measurements_page.dart';

extension _BalconyCardUi on _ParisClientMeasurementsPageState {
  // ============================================================================
  // كارت البلكونة المطور
  // ============================================================================
  Widget _balconyCard(_Balcony item, int index, {Key? key}) {
    final disabled = !item.enabled;
    final cardDecoration = disabled ? TextDecoration.lineThrough : null;
    final cardDecorColor = disabled
        ? Colors.redAccent.withValues(alpha: 0.8)
        : null;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F121C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: disabled
              ? Colors.white24
              : Colors.cyan.withValues(alpha: 0.35),
          width: 1.15,
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  _rebuild(() => item.enabled = !item.enabled);
                  _triggerAutoSave();
                },
                child: Icon(
                  item.enabled
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: item.enabled ? Colors.cyanAccent : Colors.white30,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text('🚪', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: Text(
                  item.name.text.isEmpty ? 'بلكونة' : item.name.text,
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: cardDecoration,
                    decorationColor: cardDecorColor,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'قطع: ${item.parts.text.isEmpty ? "—" : _toArabic(item.parts.text)}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    decoration: cardDecoration,
                    decorationColor: cardDecorColor,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'تكرار البلكونة',
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Colors.cyan,
                  size: 16,
                ),
                onPressed: () => _duplicateBalcony(item),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 26,
                  height: 28,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'حذف',
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 18,
                ),
                onPressed: () => _deleteBalcony(index),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
