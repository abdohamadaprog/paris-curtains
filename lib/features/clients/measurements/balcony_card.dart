part of 'paris_client_measurements_page.dart';

/// قاعدة حساب الأفيز لكل ضلع: أقل من ٣م = ٢ أفيز • من ٣م فأكثر = ٣ أفيز
int _calcAvez(double meters) {
  if (meters <= 0) return 0;
  return meters >= 3.0 ? 3 : 2;
}

extension _BalconyCardUi on _ParisClientMeasurementsPageState {
  // ============================================================================
  // كارت البلكونة الخارجية المطور مع الرسم الهندسي التفاعلي والأفيز التلقائي
  // ============================================================================
  Widget _balconyCard(_Balcony item, int index, {Key? key}) {
    final disabled = !item.enabled;
    final cardDecoration = disabled ? TextDecoration.lineThrough : null;
    final cardDecorColor = disabled
        ? AppPalette.redStrong.withValues(alpha: 0.8)
        : null;

    final wTotal = item.totalWidth;
    final fMeters = item.fabricMeters;
    final totalAvez = item.totalAvez;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: disabled
              ? _line
              : AppPalette.cyan.withValues(alpha: 0.30),
          width: 1,
        ),
        boxShadow: disabled
            ? const []
            : [
                BoxShadow(
                  color: AppPalette.cyanDeep.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==================================================================
            // شريط العنوان العلوي للكارت
            // ==================================================================
            InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              onTap: () => _openBalconyEditor(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // زر تفعيل / تعطيل الكارت
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        _rebuild(() => item.enabled = !item.enabled);
                        _triggerAutoSave();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: item.enabled ? AppPalette.cyan : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.enabled
                                ? AppPalette.cyan
                                : AppPalette.text.withValues(alpha: 0.30),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: item.enabled ? _bg : Colors.transparent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // أيقونة البلكونة
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppPalette.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.balcony_rounded,
                        color: AppPalette.cyan,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // اسم البلكونة (تسمية افتراضية متسلسلة وقابلة للتعديل)
                    Expanded(
                      flex: 3,
                      child: Text(
                              item.name.text.isEmpty
                                  ? 'بلكونة خارجية ${_toArabic(index + 1)}'
                                  : item.name.text,
                              style: TextStyle(
                                color: AppPalette.cyan,
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                                decoration: cardDecoration,
                                decorationColor: cardDecorColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),

                    const SizedBox(width: 8),

                    // شارة إجمالي العرض والأفيز السريع
                    Flexible(
                      flex: 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.insetAlt,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.22)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_toArabic(wTotal.toStringAsFixed(2))} م',
                            style: TextStyle(
                              color: AppPalette.text,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 1,
                            height: 12,
                            color: AppPalette.text.withValues(alpha: 0.24),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_toArabic(totalAvez)} أفيز',
                            style: TextStyle(
                              color: AppPalette.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // زر تكرار
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'تكرار البلكونة',
                      icon: Icon(
                        Icons.copy_rounded,
                        color: AppPalette.cyan,
                        size: 17,
                      ),
                      onPressed: () => _duplicateBalcony(item),
                    ),

                    // زر حذف
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 34,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'حذف',
                      icon: Icon(
                        Icons.delete_outline,
                        color: AppPalette.redStrong,
                        size: 18,
                      ),
                      onPressed: () => _deleteBalcony(index),
                    ),

                    // لمسة على الكارت بتفتح المحرر
                    Icon(
                      Icons.edit_rounded,
                      color: AppPalette.cyan,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================================
            // جسم الكارت المختصر: رسمة + ملخص. التعديل بيتم في المحرر (لمسة)
            // ==================================================================
            if (!disabled) ...[
              Divider(color: AppPalette.cyan.withValues(alpha: 0.16), height: 1),
              InkWell(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                onTap: () => _openBalconyEditor(item),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLiveBalconySketch(item),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat(
                            title: 'إجمالي المقاس',
                            value: '${_toArabic(wTotal.toStringAsFixed(2))} م',
                            color: AppPalette.cyan,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppPalette.text.withValues(alpha: 0.12),
                          ),
                          _buildMiniStat(
                            title: 'قماش (× ١.٥)',
                            value: '${_toArabic(fMeters.toStringAsFixed(2))} م',
                            color: AppPalette.cyanLight,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppPalette.text.withValues(alpha: 0.12),
                          ),
                          _buildMiniStat(
                            title: 'إجمالي الأفيز',
                            value: '${_toArabic(totalAvez)} أفيز',
                            color: AppPalette.amber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 13,
                            color: _muted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'اضغط للتعديل',
                            style: TextStyle(
                              color: AppPalette.textSoft,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }

  // ============================================================================
  // الرسم الهندسي التفاعلي الحي للبلكونة
  // ============================================================================
  Widget _buildLiveBalconySketch(_Balcony item, {int selectedSide = 0}) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: AppPalette.inset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.18)),
      ),
      child: Stack(
        children: [
          // رسم المخطط المعماري
          Positioned.fill(
            child: CustomPaint(
              painter: _BalconyCanvasPainter(
                sidesCount: item.sidesCount,
                s1: item.side1Val,
                s2: item.side2Val,
                s3: item.side3Val,
                s4: item.side4Val,
                avez1: _calcAvez(item.side1Val),
                avez2: _calcAvez(item.side2Val),
                avez3: _calcAvez(item.side3Val),
                avez4: _calcAvez(item.side4Val),
                selectedSide: selectedSide,
              ),
            ),
          ),

          // شارة توضيحية خفيفة في الزاوية
          Positioned(
            top: 6,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppPalette.scrim,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye_rounded,
                    color: AppPalette.cyan,
                    size: 11,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'مخطط تنفيذي حي',
                    style: TextStyle(color: AppPalette.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ودجت إحصائية صغيرة
  Widget _buildMiniStat({
    required String title,
    required String value,
    required Color color,
  }) {
    return Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppPalette.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 14.5,
          ),
        ),
      ],
    ),
      ),
    );
  }
}

// ============================================================================
// رسّام المخطط المعماري للبلكونة بحسب عدد الأضلاع والأفيز
// ============================================================================
class _BalconyCanvasPainter extends CustomPainter {
  final bool dark = AppPalette.isDark;
  final int sidesCount;
  final double s1;
  final double s2;
  final double s3;
  final double s4;
  final int avez1;
  final int avez2;
  final int avez3;
  final int avez4;

  /// رقم الضلع (١–٤) اللي بيتعدّل دلوقتي وبيتلوّن، أو ٠ لو مفيش
  final int selectedSide;

  _BalconyCanvasPainter({
    required this.sidesCount,
    required this.s1,
    required this.s2,
    required this.s3,
    required this.s4,
    required this.avez1,
    required this.avez2,
    required this.avez3,
    required this.avez4,
    this.selectedSide = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final wallPaint = Paint()
      ..color = AppPalette.cyan
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final wallGlowPaint = Paint()
      ..color = AppPalette.cyanDeep.withValues(alpha: 0.25)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = AppPalette.amber
      ..style = PaintingStyle.fill;

    // رسم حسب عدد الأضلاع
    switch (sidesCount) {
      case 1:
        // ضلع مستقيم (واجهة)
        final p1 = Offset(w * 0.15, h * 0.55);
        final p2 = Offset(w * 0.85, h * 0.55);

        canvas.drawLine(p1, p2, wallGlowPaint);
        canvas.drawLine(p1, p2, wallPaint);

        // علامات الأفيز
        if (selectedSide == 1) _highlight(canvas, p1, p2);
        _drawAvezDots(canvas, p1, p2, avez1, pointPaint);

        // النص
        _drawText(
          canvas,
          'الواجهة: ${_arText(s1)} م  (${_arInt(avez1)} أفيز)',
          Offset(w * 0.5, h * 0.25),
        );
        break;

      case 2:
        // زاوية L (ضلع واجهة + ضلع جانبي)
        final pA = Offset(w * 0.20, h * 0.25);
        final pCorner = Offset(w * 0.20, h * 0.75);
        final pB = Offset(w * 0.82, h * 0.75);

        // الجانب (س2)
        canvas.drawLine(pA, pCorner, wallGlowPaint);
        canvas.drawLine(pA, pCorner, wallPaint);
        if (selectedSide == 2) _highlight(canvas, pA, pCorner);
        _drawAvezDots(canvas, pA, pCorner, avez2, pointPaint);

        // الواجهة (س1)
        canvas.drawLine(pCorner, pB, wallGlowPaint);
        canvas.drawLine(pCorner, pB, wallPaint);
        if (selectedSide == 1) _highlight(canvas, pCorner, pB);
        _drawAvezDots(canvas, pCorner, pB, avez1, pointPaint);

        _drawText(
          canvas,
          'الجانب: ${_arText(s2)}م',
          Offset(w * 0.12, h * 0.50),
          isVertical: true,
        );
        _drawText(
          canvas,
          'الواجهة: ${_arText(s1)}م  (${_arInt(avez1)} أفيز)',
          Offset(w * 0.52, h * 0.86),
        );
        break;

      case 3:
        // شكل U (يمين، واجهة، شمال)
        final pLeftTop = Offset(w * 0.22, h * 0.25);
        final pLeftBottom = Offset(w * 0.22, h * 0.75);
        final pRightBottom = Offset(w * 0.78, h * 0.75);
        final pRightTop = Offset(w * 0.78, h * 0.25);

        // ضلع الشمال (س3)
        canvas.drawLine(pLeftTop, pLeftBottom, wallGlowPaint);
        canvas.drawLine(pLeftTop, pLeftBottom, wallPaint);
        if (selectedSide == 3) _highlight(canvas, pLeftTop, pLeftBottom);
        _drawAvezDots(canvas, pLeftTop, pLeftBottom, avez3, pointPaint);

        // ضلع الواجهة (س1)
        canvas.drawLine(pLeftBottom, pRightBottom, wallGlowPaint);
        canvas.drawLine(pLeftBottom, pRightBottom, wallPaint);
        if (selectedSide == 1) _highlight(canvas, pLeftBottom, pRightBottom);
        _drawAvezDots(canvas, pLeftBottom, pRightBottom, avez1, pointPaint);

        // ضلع اليمين (س2)
        canvas.drawLine(pRightTop, pRightBottom, wallGlowPaint);
        canvas.drawLine(pRightTop, pRightBottom, wallPaint);
        if (selectedSide == 2) _highlight(canvas, pRightTop, pRightBottom);
        _drawAvezDots(canvas, pRightTop, pRightBottom, avez2, pointPaint);

        // التسميات
        _drawText(
          canvas,
          'ش: ${_arText(s3)}م',
          Offset(w * 0.12, h * 0.50),
          isVertical: true,
        );
        _drawText(
          canvas,
          'الواجهة: ${_arText(s1)}م  (${_arInt(avez1)} أفيز)',
          Offset(w * 0.50, h * 0.86),
        );
        _drawText(
          canvas,
          'يمين: ${_arText(s2)}م',
          Offset(w * 0.88, h * 0.50),
          isVertical: true,
        );
        break;

      case 4:
      default:
        // ٤ أضلاع مغلقة (داير ما يدور)
        final rect = Rect.fromLTRB(w * 0.22, h * 0.20, w * 0.78, h * 0.78);
        final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

        canvas.drawRRect(rRect, wallGlowPaint);
        canvas.drawRRect(rRect, wallPaint);

        if (selectedSide == 1) _highlight(canvas, rect.bottomLeft, rect.bottomRight);
        if (selectedSide == 2) _highlight(canvas, rect.topRight, rect.bottomRight);
        if (selectedSide == 3) _highlight(canvas, rect.topLeft, rect.bottomLeft);
        if (selectedSide == 4) _highlight(canvas, rect.topLeft, rect.topRight);

        _drawAvezDots(
          canvas,
          rect.bottomLeft,
          rect.bottomRight,
          avez1,
          pointPaint,
        );
        _drawAvezDots(
          canvas,
          rect.topRight,
          rect.bottomRight,
          avez2,
          pointPaint,
        );
        _drawAvezDots(canvas, rect.topLeft, rect.bottomLeft, avez3, pointPaint);
        _drawAvezDots(canvas, rect.topLeft, rect.topRight, avez4, pointPaint);

        _drawText(
          canvas,
          'الواجهة: ${_arText(s1)}م',
          Offset(w * 0.50, h * 0.87),
        );
        _drawText(
          canvas,
          'الخلفي: ${_arText(s4)}م',
          Offset(w * 0.50, h * 0.10),
        );
        _drawText(
          canvas,
          '${_arText(s3)}م',
          Offset(w * 0.12, h * 0.49),
          isVertical: true,
        );
        _drawText(
          canvas,
          '${_arText(s2)}م',
          Offset(w * 0.88, h * 0.49),
          isVertical: true,
        );
        break;
    }
  }

  // تلوين الضلع اللي بيتعدّل
  void _highlight(Canvas canvas, Offset a, Offset b) {
    final glow = Paint()
      ..color = AppPalette.amber.withValues(alpha: 0.35)
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final line = Paint()
      ..color = AppPalette.amber
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(a, b, glow);
    canvas.drawLine(a, b, line);
  }

  void _drawAvezDots(
    Canvas canvas,
    Offset start,
    Offset end,
    int count,
    Paint paint,
  ) {
    if (count <= 0) return;
    for (int i = 1; i <= count; i++) {
      final t = i / (count + 1);
      final pt = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
      canvas.drawCircle(pt, 3.5, paint);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    bool isVertical = false,
  }) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: AppPalette.text,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.rtl)
      ..layout();

    final pos = Offset(center.dx - (tp.width / 2), center.dy - (tp.height / 2));
    tp.paint(canvas, pos);
  }

  static String _arText(double v) {
    if (v <= 0) return '٠';
    return v
        .toStringAsFixed(2)
        .replaceAll('0', '٠')
        .replaceAll('1', '١')
        .replaceAll('2', '٢')
        .replaceAll('3', '٣')
        .replaceAll('4', '٤')
        .replaceAll('5', '٥')
        .replaceAll('6', '٦')
        .replaceAll('7', '٧')
        .replaceAll('8', '٨')
        .replaceAll('9', '٩');
  }

  static String _arInt(int v) {
    return v
        .toString()
        .replaceAll('0', '٠')
        .replaceAll('1', '١')
        .replaceAll('2', '٢')
        .replaceAll('3', '٣')
        .replaceAll('4', '٤')
        .replaceAll('5', '٥')
        .replaceAll('6', '٦')
        .replaceAll('7', '٧')
        .replaceAll('8', '٨')
        .replaceAll('9', '٩');
  }

  @override
  bool shouldRepaint(covariant _BalconyCanvasPainter oldDelegate) {
    return oldDelegate.dark != dark ||
        oldDelegate.sidesCount != sidesCount ||
        oldDelegate.s1 != s1 ||
        oldDelegate.s2 != s2 ||
        oldDelegate.s3 != s3 ||
        oldDelegate.s4 != s4 ||
        oldDelegate.avez1 != avez1 ||
        oldDelegate.avez2 != avez2 ||
        oldDelegate.avez3 != avez3 ||
        oldDelegate.avez4 != avez4 ||
        oldDelegate.selectedSide != selectedSide;
  }
}
