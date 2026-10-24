part of '../paris_client_measurements_page.dart';

extension _MeasurementCardHero on _ParisClientMeasurementsPageState {
  String _heroTag(_Measurement item) => 'measurement-${item.id}';

  // نفس الكارت في مكانين (مصغّر في القايمة / مكبّر فوقها) بنفس الـ tag،
  // و hero_here بيطيّره من مكان للتاني على نفس الصفحة بدون Navigator.
  Widget _hero(_Measurement item, {required bool open, required Widget child}) {
    return HeroHere(
      key: ValueKey('${open ? 'open' : 'closed'}-${item.id}'),
      tag: _heroTag(item),
      flightAnimationDuration: const Duration(milliseconds: 520),
      flightAnimationFactory: (controller) =>
          CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
      flightShuttleBuilder: HeroHereShuttles.scale(),
      child: child,
    );
  }

  Widget _measurementCard(_Measurement item, int index) {
    return Padding(
      key: ValueKey('measurement-${item.id}'),
      padding: const EdgeInsets.only(bottom: 4),
      child: _hero(
        item,
        open: false,
        child: _cardShell(
          item,
          index,
          zoom: _compactZoom,
          reveal: 0,
          popup: false,
        ),
      ),
    );
  }

  void _openCard(_Measurement item) {
    if (_expandedId != null) return;
    _rebuild(() {
      _expandedId = item.id;
      _closing = false;
    });
  }

  // بنخفي اللوحة والتعتيم الأول، وبعدين الكارت يرجع يطير لمكانه في القايمة
  void _closeCard() {
    if (_expandedId == null || _closing) return;
    _rebuild(() => _closing = true);
    Future.delayed(const Duration(milliseconds: 170), () {
      if (!mounted) return;
      _rebuild(() {
        _expandedId = null;
        _closing = false;
      });
    });
  }

  // التنقل بين الكروت وهي مفتوحة: الكارت الحالي يرجع مكانه والتاني يطلع (سحب أو أزرار)
  void _goToNeighbor(int delta) {
    if (_closing) return;
    final i = _measurements.indexWhere((m) => m.id == _expandedId);
    if (i < 0) return;
    final next = i + delta;
    if (next < 0 || next >= _measurements.length) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _rebuild(() => _expandedId = _measurements[next].id);
  }

  Widget _navRow(int index) {
    final hasPrev = index > 0;
    final hasNext = index < _measurements.length - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: hasPrev ? () => _goToNeighbor(-1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('السابق'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: BorderSide(color: _gold.withValues(alpha: 0.5)),
                minimumSize: const Size(0, 42),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${_toArabic(index + 1)} / ${_toArabic(_measurements.length)}',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: hasNext ? () => _goToNeighbor(1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('التالي'),
              iconAlignment: IconAlignment.end,
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: BorderSide(color: _gold.withValues(alpha: 0.5)),
                minimumSize: const Size(0, 42),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandedOverlay() {
    final index = _measurements.indexWhere((m) => m.id == _expandedId);
    if (index < 0) return const SizedBox.shrink();
    final item = _measurements[index];
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeCard,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _closing ? 0 : 0.68),
                duration: const Duration(milliseconds: 260),
                builder: (context, v, _) =>
                    ColoredBox(color: Colors.black.withValues(alpha: v)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // سحب الكارت يمين أو شمال ينقلك للكارت اللي جنبه
                    GestureDetector(
                      onHorizontalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (v < -250) _goToNeighbor(1);
                        if (v > 250) _goToNeighbor(-1);
                      },
                      child: _hero(
                        item,
                        open: true,
                        child: _cardShell(
                          item,
                          index,
                          zoom: 1,
                          reveal: 1,
                          popup: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _PanelReveal(
                      visible: !_closing,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [_editPanel(item), _navRow(index)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// لوحة التعديل بتنزل بالتدريج بعد ما الكارت يوصل، وتختفي بسرعة قبل ما يرجع
class _PanelReveal extends StatelessWidget {
  const _PanelReveal({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
      duration: Duration(milliseconds: visible ? 560 : 150),
      curve: visible
          ? const Interval(0.4, 1.0, curve: Curves.easeOutCubic)
          : Curves.easeIn,
      builder: (context, v, child) {
        final f = v.clamp(0.0, 1.0);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: f,
            child: Opacity(opacity: f, child: child),
          ),
        );
      },
      child: child,
    );
  }
}
