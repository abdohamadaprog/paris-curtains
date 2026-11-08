part of 'paris_client_measurements_page.dart';

// ============================================================================
// صورة المقاسات: كارت ثابت بيتحوّل لصورة (زي الفاتورة) — للمشاركة والحفظ
// ونسخة احتياطية على تليجرام.
// ============================================================================

const Color _paper = Color(0xFFFFFBF3);
const Color _ink = Color(0xFF1F2937);
const Color _inkMuted = Color(0xFF6B7280);
const Color _paperGold = Color(0xFFB8893A);
const Color _paperLine = Color(0xFFE5D9BF);

const double _kSheetWidth = 600;

class _MeasurementSheetRow {
  const _MeasurementSheetRow({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

class _MeasurementSheetData {
  const _MeasurementSheetData({
    required this.clientName,
    required this.rows,
    this.phone,
    this.date,
  });

  final String clientName;
  final String? phone;
  final String? date;
  final List<_MeasurementSheetRow> rows;
}

class _MeasurementSheet extends StatelessWidget {
  const _MeasurementSheet({required this.data});

  final _MeasurementSheetData data;

  static const String _font = 'Cairo';

  TextStyle _t(
    double size, {
    Color color = _ink,
    FontWeight weight = FontWeight.w500,
    double? height,
  }) => TextStyle(
    fontFamily: _font,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: _kSheetWidth,
        color: _paper,
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 92,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'مقاسات التنفيذ',
                      style: _t(
                        24,
                        color: _paperGold,
                        weight: FontWeight.w900,
                      ),
                    ),
                    if (data.date != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        data.date!,
                        style: _t(13, color: _inkMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 2, color: _paperGold),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.clientName,
                    style: _t(22, weight: FontWeight.w900),
                  ),
                ),
                if (data.phone != null && data.phone!.isNotEmpty)
                  Text(
                    data.phone!,
                    style: _t(14, color: _inkMuted),
                    textDirection: TextDirection.ltr,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < data.rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _paperLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: _paperGold,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: _t(
                              12,
                              color: Colors.white,
                              weight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data.rows[i].title,
                            style: _t(16, weight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final line in data.rows[i].lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          line,
                          style: _t(13, color: _ink, height: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.center,
              child: Text(
                'PARIS CURTAINS • باريس للستائر',
                style: _t(11, color: _inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementImagePage extends StatefulWidget {
  const _MeasurementImagePage({required this.data});

  final _MeasurementSheetData data;

  @override
  State<_MeasurementImagePage> createState() => _MeasurementImagePageState();
}

class _MeasurementImagePageState extends State<_MeasurementImagePage> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  String get _fileBase => 'paris_measurements';

  String get _caption => 'مقاسات ${widget.data.clientName}';

  Future<Uint8List> _capture() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('الصورة لسه بتتحمل، جرّب تاني');
    final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw Exception('تعذّر تحويل المقاسات لصورة');
    return bytes.buffer.asUint8List();
  }

  void _toast(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: color ?? _panel,
      ),
    );
  }

  void _backupToTelegram(Uint8List bytes) {
    unawaited(
      TelegramBackupService.backupGeneratedImage(
        bytes: bytes,
        filename: '$_fileBase.png',
        caption: _caption,
      ),
    );
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      _backupToTelegram(bytes);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_fileBase.png');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'مقاسات ${widget.data.clientName} — باريس للستائر',
        ),
      );
    } catch (e) {
      _toast('تعذّرت المشاركة: $e', color: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      _backupToTelegram(bytes);
      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception('مفيش صلاحية حفظ الصور. فعّلها من إعدادات التليفون.');
        }
      }
      await Gal.putImageBytes(
        bytes,
        name: '${_fileBase}_${DateTime.now().millisecondsSinceEpoch}',
      );
      _toast('تم حفظ صورة المقاسات في المعرض ✨', color: Colors.green);
    } catch (e) {
      _toast('تعذّر الحفظ: $e', color: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendToTelegram() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      await TelegramBackupService.sendPhotoBytes(
        bytes: bytes,
        filename: '$_fileBase.png',
        caption: _caption,
      );
      _toast('اتبعتت نسخة على تليجرام ✨', color: Colors.green);
    } catch (e) {
      _toast('مقدرتش أبعت على تليجرام: $e', color: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _panel,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'صورة المقاسات',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'نسخة على تليجرام',
              onPressed: _busy ? null : _sendToTelegram,
              icon: Icon(Icons.send_rounded, color: _gold),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: SizedBox(
                    width: _kSheetWidth,
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: _MeasurementSheet(data: widget.data),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                color: _panel,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _share,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.share_rounded, size: 19),
                        label: const Text(
                          'مشاركة (واتساب)',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _saveToGallery,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: BorderSide(color: _gold),
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                          horizontal: 16,
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 19),
                      label: const Text('حفظ'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
