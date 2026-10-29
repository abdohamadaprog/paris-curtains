part of 'paris_client_measurements_page.dart';

extension _MeasurementHeader on _ParisClientMeasurementsPageState {
  // ============================================================================
  // شريط معلومات العميل (التليفون + موعد التركيب)
  // ============================================================================
  Widget _clientInfoBar() {
    final hasPhone = widget.phone != null && widget.phone!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          if (hasPhone) ...[
            const Icon(Icons.phone_rounded, color: _gold, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _toArabic(widget.phone),
                style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          InkWell(
            onTap: _pickInstallationDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event, color: _gold, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    _date(_installationDate),
                    style: const TextStyle(
                      color: _neon,
                      fontSize: 12.5,
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
  // تبويبات (الشقة / البلكونات) — نفس فكرة تبويبات الفاتورة
  // ============================================================================
  Widget _measureTabsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: TabBar(
        controller: _tabs,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _gold,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: _bg,
        unselectedLabelColor: _muted,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        splashBorderRadius: BorderRadius.circular(10),
        tabs: [
          _tabLabel(Icons.window_rounded, 'الشقة', _measurements.length),
          _tabLabel(Icons.balcony_rounded, 'البلكونات', _balconies.length),
        ],
      ),
    );
  }

  Tab _tabLabel(IconData icon, String label, int count) {
    return Tab(
      height: 42,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text('$label (${_toArabic(count)})'),
        ],
      ),
    );
  }

  // ============================================================================
  // الشريط السفلي: ملخص التبويب الحالي + زرار الفاتورة (ظاهر دايمًا)
  // ============================================================================
  Widget _bottomBar() {
    final isBalcony = _tabs.index == 1;
    final pills = <Widget>[];

    if (!isBalcony) {
      var heavy = 0.0;
      var light = 0.0;
      var wheels = 0;
      var count = 0;
      for (final m in _measurements) {
        if (!m.enabled) continue;
        count++;
        final c = m.calculation;
        heavy += c.heavyMeters;
        light += c.lightMeters;
        wheels += c.heavyWheels + c.lightWheels;
      }
      pills.addAll([
        _summaryPill('مقاسات', _toArabic(count), _gold),
        _summaryPill('ثقيل', '${_fmtAr(heavy)} م', const Color(0xFFFFD45A)),
        _summaryPill('خفيف', '${_fmtAr(light)} م', const Color(0xFF70D6FF)),
        _summaryPill('عجل', _toArabic(wheels), Colors.white),
      ]);
    } else {
      var width = 0.0;
      var fabric = 0.0;
      var avez = 0;
      var count = 0;
      for (final b in _balconies) {
        if (!b.enabled) continue;
        count++;
        width += b.totalWidth;
        fabric += b.fabricMeters;
        avez += b.totalAvez;
      }
      pills.addAll([
        _summaryPill('بلكونات', _toArabic(count), _gold),
        _summaryPill('عرض', '${_fmtAr(width)} م', const Color(0xFFFFD45A)),
        _summaryPill('قماش', '${_fmtAr(fabric)} م', const Color(0xFF70D6FF)),
        _summaryPill('أفيز', _toArabic(avez), Colors.white),
      ]);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(top: BorderSide(color: _line, width: 1.5)),
      ),
      child: Row(
        children: [
          Expanded(child: Wrap(spacing: 6, runSpacing: 5, children: pills)),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _openInvoice,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.receipt_long_rounded, size: 20),
            label: const Text(
              'الفاتورة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

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
