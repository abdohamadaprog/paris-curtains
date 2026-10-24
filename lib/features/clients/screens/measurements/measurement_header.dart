part of '../paris_client_measurements_page.dart';

extension _MeasurementHeader on _ParisClientMeasurementsPageState {
  // ============================================================================
  // شريط معلومات العميل العلوية
  // ============================================================================
  Widget _clientInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1118),
        border: Border(bottom: BorderSide(color: Color(0x33C7A064))),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_rounded, color: _gold, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.clientName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.phone != null && widget.phone!.isNotEmpty) ...[
            Text(
              _toArabic(widget.phone),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(width: 8),
          ],
          InkWell(
            onTap: _pickInstallationDate,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event, color: _gold, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _date(_installationDate),
                    style: const TextStyle(
                      color: _neon,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // شريط التحكم والإضافة
  // ============================================================================
  Widget _sectionHeaderBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'المقاسات (${_toArabic(_measurements.length)})',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'المحذوفات',
            visualDensity: VisualDensity.compact,
            onPressed: () => _rebuild(() => _showTrash = !_showTrash),
            icon: Badge(
              label: Text(_toArabic(_trash.length)),
              child: Icon(
                _showTrash ? Icons.close : Icons.delete_outline_rounded,
                color: _trash.isNotEmpty ? Colors.amberAccent : Colors.white54,
                size: 20,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _addBalcony,
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: BorderSide(color: _gold.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add_box_outlined, size: 16),
            label: const Text('بلكونة', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: _addMeasurement,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              'إضافة مقاس',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // شريط الإجماليات السفلي
  // ============================================================================
  Widget _totalsBottomBar(double heavy, double light, int wheels, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(top: BorderSide(color: Color(0x33C7A064))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _summaryPill('مقاسات', _toArabic(count), _gold),
                _summaryPill(
                  'ثقيل',
                  '${_fmtAr(heavy)} م',
                  const Color(0xFFFFD45A),
                ),
                _summaryPill(
                  'خفيف',
                  '${_fmtAr(light)} م',
                  const Color(0xFF70D6FF),
                ),
                _summaryPill('عجل', _toArabic(wheels), Colors.white),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _performSave(isAuto: false),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 16),
            label: const Text(
              'حفظ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white60, fontSize: 10.5),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
