part of 'paris_client_measurements_page.dart';

extension _MeasurementHeader on _ParisClientMeasurementsPageState {
  // ============================================================================
  // شريط معلومات العميل: رقم الهاتف + موعد التركيب في بطاقتين صغيرتين واضحتين
  // ============================================================================
  Widget _clientInfoBar() {
    final phone = (widget.phone ?? '').trim();
    final address = (widget.address ?? '').trim();
    final hasPhone = phone.isNotEmpty;
    final hasAddress = address.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppPalette.isDark
            ? const Color(0xFF16202F)
            : const Color(0xFFFBF8F2),
        border: Border(
          bottom: BorderSide(color: _gold.withValues(alpha: 0.16)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _infoTile(
              icon: Icons.phone_rounded,
              label: 'الهاتف',
              value: hasPhone
                  ? _toArabic(phone)
                  : (hasAddress ? address : 'مفيش رقم مسجل'),
              strong: hasPhone,
            ),
          ),
          const SizedBox(width: 8),
          _installationTile(),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required bool strong,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppPalette.insetAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _gold),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: strong ? AppPalette.text : _muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _installationTile() {
    final hasDate = _installationDate != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pickInstallationDate,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                _gold.withValues(alpha: 0.12),
                _gold.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Icon(Icons.event_rounded, size: 16, color: _gold),
              const SizedBox(width: 7),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'موعد التركيب',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _date(_installationDate),
                    maxLines: 1,
                    style: TextStyle(
                      color: hasDate ? _gold : _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // تبويبات (الشقة / البلكونات)
  // ============================================================================
  Widget _measureTabsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppPalette.insetAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line.withValues(alpha: 0.8)),
      ),
      child: TabBar(
        controller: _tabs,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [_gold, AppPalette.goldLight],
          ),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.22),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: _bg,
        unselectedLabelColor: _muted,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        splashBorderRadius: BorderRadius.circular(11),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
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
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Text(label),
          const SizedBox(width: 5),
          Text(
            '(${_toArabic(count)})',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // شريط الإجراءات السفلي (Dock):
  //   • ملخص سريع للتبويب الحالي في سطر واحد قابل للسحب.
  //   • إضافة + قالب + فاتورة في سطر واحد مريح، بدل الـ FAB والشريط المزدوج.
  // ============================================================================
  Widget _actionDock() {
    final isBalcony = _tabs.index == 1;
    final pills = <Widget>[];

    if (!isBalcony) {
      var heavy = 0.0;
      var light = 0.0;
      var blackout = 0.0;
      var wheels = 0;
      var count = 0;
      for (final m in _measurements) {
        if (!m.enabled) continue;
        count++;
        final c = m.calculation;
        heavy += c.heavyMeters;
        light += c.lightMeters;
        blackout += c.blackoutMeters;
        wheels += c.heavyWheels + c.lightWheels;
      }
      if (count > 0) {
        pills.addAll([
          _summaryPill('مقاسات', _toArabic(count), _gold),
          _summaryPill('ثقيل', '${_fmtAr(heavy)} م', AppPalette.amber),
          _summaryPill('خفيف', '${_fmtAr(light)} م', AppPalette.skyLight),
          if (blackout > 0)
            _summaryPill(
              'بلاك أوت',
              '${_fmtAr(blackout)} م',
              AppPalette.violet,
            ),
          _summaryPill('عجل', _toArabic(wheels), AppPalette.mint),
        ]);
      }
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
      if (count > 0) {
        pills.addAll([
          _summaryPill('بلكونات', _toArabic(count), _gold),
          _summaryPill('عرض', '${_fmtAr(width)} م', AppPalette.amber),
          _summaryPill('قماش', '${_fmtAr(fabric)} م', AppPalette.skyLight),
          _summaryPill('أفيز', _toArabic(avez), AppPalette.mint),
        ]);
      }
    }

    if (pills.isEmpty) {
      pills.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _bg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          child: Text(
            'لسه مفيش مقاسات مفعّلة',
            style: TextStyle(color: _muted, fontSize: 11.5),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppPalette.isDark
              ? const [Color(0xFF1E293B), Color(0xFF17202E)]
              : const [Color(0xFFFFFFFF), Color(0xFFFBF7EF)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: _gold.withValues(alpha: 0.22))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppPalette.isDark ? 0.26 : 0.06,
            ),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
            child: SizedBox(
              height: 31,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pills.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) =>
                    Align(alignment: Alignment.centerLeft, child: pills[i]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [_gold, AppPalette.goldLight],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: isBalcony ? _addBalcony : _addMeasurement,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: _bg,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 21),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isBalcony ? 'إضافة بلكونة' : 'إضافة مقاس',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isBalcony) ...[
                  const SizedBox(width: 8),
                  _dockIconButton(
                    icon: Icons.playlist_add_rounded,
                    tooltip: 'إضافة سريعة (مجموعة مقاسات)',
                    onTap: _openQuickAdd,
                  ),
                  const SizedBox(width: 8),
                  _dockIconButton(
                    icon: Icons.bookmarks_rounded,
                    tooltip: 'إضافة من قالب',
                    onTap: _pickTemplate,
                  ),
                ],
                if (AdminAuthService.role.canSeeInvoice) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _openInvoice,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        backgroundColor: _gold.withValues(alpha: 0.06),
                        side: BorderSide(color: _gold.withValues(alpha: 0.30)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 19),
                      label: const Text(
                        'الفاتورة',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dockIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppPalette.insetAlt,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line.withValues(alpha: 0.8)),
            ),
            child: Icon(icon, color: _gold, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _summaryPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
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
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: _muted, size: 17),
            const SizedBox(width: 7),
            Text(
              'سلة المحذوفات فاضية',
              style: TextStyle(color: _muted, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.redStrong.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.delete_sweep_rounded,
                color: AppPalette.redStrong,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                'المحذوفات (${_toArabic(_trash.length)})',
                style: TextStyle(
                  color: AppPalette.redStrong,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _rebuild(() => _trash.clear());
                  _triggerAutoSave();
                },
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('تفريغ السلة'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ..._trash.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name.isEmpty ? 'عنصر محذوف' : item.name,
                      style: TextStyle(
                        color: AppPalette.textSoft,
                        fontSize: 12.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
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
                    style: TextButton.styleFrom(
                      foregroundColor: _gold,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 15),
                    label: const Text(
                      'استرجاع',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
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
}
