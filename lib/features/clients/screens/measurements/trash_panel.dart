part of '../paris_client_measurements_page.dart';

extension _TrashPanelUi on _ParisClientMeasurementsPageState {
  // ============================================================================
  // سلة المحذوفات القابلة للاسترجاع
  // ============================================================================
  Widget _trashPanel() {
    if (_trash.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Text(
            'سلة المحذوفات فارغة',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'المحذوفات (${_toArabic(_trash.length)})',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _rebuild(() => _trash.clear());
                  _triggerAutoSave();
                },
                child: const Text(
                  'تفريغ السلة',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
          ..._trash.map(
            (item) => Row(
              children: [
                Expanded(
                  child: Text(
                    item.name.isEmpty ? 'عنصر محذوف' : item.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _rebuild(() {
                      _trash.remove(item);
                      if (item.isBalcony) {
                        _balconies.add(item.toBalcony());
                      } else {
                        _measurements.add(item.toMeasurement());
                      }
                    });
                    _triggerAutoSave();
                  },
                  child: const Text(
                    'استرجاع',
                    style: TextStyle(color: _gold, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
