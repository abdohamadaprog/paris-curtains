part of '../paris_client_measurements_page.dart';

extension _MeasurementCardHero on _ParisClientMeasurementsPageState {
  Widget _measurementCard(_Measurement item, int index) {
    return Padding(
      key: ValueKey('measurement-${item.id}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: _cardShell(
        item,
        index,
        zoom: _compactZoom,
        reveal: 0,
        popup: false,
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

  void _closeCard() {
    if (_expandedId == null || _closing) return;
    _rebuild(() => _closing = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _rebuild(() {
        _expandedId = null;
        _closing = false;
      });
    });
  }

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
            child: OutlinedButton(
              onPressed: hasNext ? () => _goToNeighbor(1) : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: BorderSide(color: _gold.withValues(alpha: 0.5)),
                minimumSize: const Size(0, 42),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('التالي'),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_left_rounded),
                ],
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
          // خلفية معتمة تضغط عليها تقفل
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeCard,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _closing ? 0 : 0.72),
                duration: const Duration(milliseconds: 240),
                builder: (context, v, _) =>
                    ColoredBox(color: Colors.black.withValues(alpha: v)),
              ),
            ),
          ),
          // كارت منبثق بأنيميشن تكبير مرن (Spring Pop Zoom)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Center(
              child: SingleChildScrollView(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: _closing ? 1.0 : 0.76,
                    end: _closing ? 0.76 : 1.0,
                  ),
                  duration: Duration(milliseconds: _closing ? 180 : 320),
                  curve: _closing ? Curves.easeInCubic : Curves.easeOutBack,
                  builder: (context, scale, childWidget) {
                    return Transform.scale(scale: scale, child: childWidget);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // زر إغلاق علوي سريع
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                          tooltip: 'إغلاق',
                          onPressed: _closeCard,
                        ),
                      ),
                      // سحب الكارت يمين أو شمال ينقلك للكارت اللي جنبه
                      GestureDetector(
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -250) _goToNeighbor(1);
                          if (v > 250) _goToNeighbor(-1);
                        },
                        child: _cardShell(
                          item,
                          index,
                          zoom: 1.0,
                          reveal: 1.0,
                          popup: true,
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
          ),
        ],
      ),
    );
  }
}

// لوحة التعديل بتنزل بالتدريج بسلاسة
class _PanelReveal extends StatelessWidget {
  const _PanelReveal({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
      duration: Duration(milliseconds: visible ? 380 : 150),
      curve: visible
          ? const Interval(0.2, 1.0, curve: Curves.easeOutCubic)
          : Curves.easeIn,
      builder: (context, v, childWidget) {
        final f = v.clamp(0.0, 1.0);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: f,
            child: Opacity(opacity: f, child: childWidget),
          ),
        );
      },
      child: child,
    );
  }
}
