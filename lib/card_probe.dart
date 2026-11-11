// ملف تشخيص مؤقت — بيتشال بعد ما نحدد سبب اختفاء نصوص كارت المقاس.
// بيعرض نسخ متعددة من الكارت، كل نسخة بزودها طبقة واحدة، عشان نشوف
// أنهي طبقة بالتحديد هي اللي بتمنع رسم المحتوى على الجهاز.
import 'package:flutter/material.dart';

const Color _pTop = Color(0xFF25344A);
const Color _pBottom = Color(0xFF1A2434);
const Color _pGold = Color(0xFFC7A064);
const Color _pGoldLight = Color(0xFFEBC98E);
const Color _pText = Color(0xFFF1F5F9);

class CardProbeApp extends StatelessWidget {
  const CardProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const CardProbePage(),
    );
  }
}

class CardProbePage extends StatelessWidget {
  const CardProbePage({super.key});

  static const BoxDecoration _deco = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [_pTop, _pBottom],
    ),
    borderRadius: BorderRadius.all(Radius.circular(16)),
    border: Border(
      top: BorderSide(color: Color(0x8CC7A064), width: 1.2),
      left: BorderSide(color: Color(0x2EC7A064)),
      right: BorderSide(color: Color(0x2EC7A064)),
      bottom: BorderSide(color: Color(0x2EC7A064)),
    ),
  );

  static const List<BoxShadow> _shadow = [
    BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3)),
  ];

  static Widget content(String tag) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'اسم المقاس $tag',
          style: const TextStyle(
            color: _pGoldLight,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0x33C7A064), Color(0x12C7A064)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x61C7A064)),
              ),
              child: const Text(
                '٣.٦٠ م',
                style: TextStyle(
                  color: _pText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '١٠.٨ م ثقيل',
              style: TextStyle(color: _pText, fontSize: 12),
            ),
            const Spacer(),
            const Text('✅', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  static Widget _wrap(
    Widget child, {
    bool shadow = false,
    bool ink = false,
    bool opacityOne = false,
    bool opacityHalf = false,
    bool boundary = false,
    bool mq = false,
    bool dts = false,
    bool dir = false,
    bool padding = false,
  }) {
    Widget w = child;
    if (padding) {
      w = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: w,
      );
    }
    if (dir) w = Directionality(textDirection: TextDirection.rtl, child: w);
    if (dts) {
      w = DefaultTextStyle.merge(
        style: const TextStyle(height: 1.15),
        child: w,
      );
    }
    if (mq) {
      w = Builder(
        builder: (ctx) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(
            textScaler: const TextScaler.linear(0.9),
          ),
          child: w,
        ),
      );
    }
    if (opacityHalf) w = Opacity(opacity: 0.5, child: w);
    if (opacityOne) w = Opacity(opacity: 1.0, child: w);
    if (boundary) w = RepaintBoundary(child: w);
    if (ink) w = InkWell(onTap: () {}, child: w);
    w = Container(
      decoration: _deco.copyWith(boxShadow: shadow ? _shadow : const []),
      child: w,
    );
    return w;
  }

  static Widget _row(String tag, Widget card) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                tag,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: card),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row('V1', _wrap(content('V1'), padding: true)),
                _row('V2', _wrap(content('V2'), padding: true, shadow: true)),
                _row('V3', _wrap(content('V3'), padding: true, shadow: true, ink: true)),
                _row('V4', _wrap(content('V4'), padding: true, shadow: true, ink: true, opacityOne: true)),
                _row('V5', _wrap(content('V5'), padding: true, shadow: true, ink: true, opacityHalf: true)),
                _row('V6', _wrap(content('V6'), padding: true, shadow: true, ink: true, boundary: true)),
                _row('V7', _wrap(content('V7'), padding: true, shadow: true, ink: true, mq: true)),
                _row('V8', _wrap(content('V8'), padding: true, shadow: true, ink: true, dts: true)),
                _row('V9', _wrap(content('V9'), padding: true, shadow: true, ink: true, dir: true)),
                _row(
                  'V10',
                  _wrap(
                    content('V10'),
                    padding: true,
                    shadow: true,
                    ink: true,
                    opacityOne: true,
                    boundary: true,
                    mq: true,
                    dts: true,
                    dir: true,
                  ),
                ),
                _row(
                  'V11',
                  SizedBox(
                    height: 62,
                    child: ReorderableListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: 1,
                      onReorder: (a, b) {},
                      itemBuilder: (ctx, i) => KeyedSubtree(
                        key: const ValueKey<String>('v11'),
                        child: _wrap(
                          content('V11'),
                          padding: true,
                          shadow: true,
                          ink: true,
                          opacityOne: true,
                          mq: true,
                          dts: true,
                          dir: true,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'نهاية الاختبار',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _pGoldLight, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
