import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/telegram_backup_service.dart';
import 'invoice_share_card.dart';

const Color _kBg = Color(0xFF0F172A);
const Color _kPanel = Color(0xFF1E293B);
const Color _kGold = Color(0xFFC5A059);
const Color _kGreen = Color(0xFF10B981);
const Color _kRed = Color(0xFFE57373);

/// معاينة الفاتورة كصورة باللوجو، مع مشاركة (واتساب وغيره) أو حفظ في المعرض.
class InvoiceImagePage extends StatefulWidget {
  const InvoiceImagePage({super.key, required this.data});

  final InvoiceShareData data;

  @override
  State<InvoiceImagePage> createState() => _InvoiceImagePageState();
}

class _InvoiceImagePageState extends State<InvoiceImagePage> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  /// بيصوّر الكارت PNG بجودة عالية (عرض 1500 بكسل تقريبًا)
  Future<Uint8List> _capture() async {
    // نستنى الفريم يخلص رسم عشان نضمن إن الكارت اتعمله paint
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('الفاتورة لسه بتتحمل، جرّب تاني');
    final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw Exception('تعذّر تحويل الفاتورة لصورة');
    return bytes.buffer.asUint8List();
  }

  String get _fileBase {
    final n = widget.data.number;
    return n == null || n.isEmpty ? 'paris_invoice' : 'paris_$n';
  }

  String get _telegramCaption {
    final number = widget.data.number;
    final suffix = number == null || number.isEmpty ? '' : ' — فاتورة $number';
    return 'فاتورة ${widget.data.clientName}$suffix';
  }

  /// بيبعت نسخة في الخلفية من غير ما يعطّل المشاركة أو الحفظ.
  void _backupToTelegram(Uint8List bytes) {
    unawaited(
      TelegramBackupService.backupGeneratedImage(
        bytes: bytes,
        filename: '$_fileBase.png',
        caption: _telegramCaption,
      ),
    );
  }

  void _toast(String msg, {Color color = _kPanel}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: color,
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
          text: 'فاتورة ${widget.data.clientName} — باريس للستائر',
        ),
      );
    } catch (e) {
      _toast('تعذّرت المشاركة: $e', color: _kRed);
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
      _toast('تم حفظ الفاتورة في المعرض ✨', color: _kGreen);
    } catch (e) {
      _toast('تعذّر الحفظ: $e', color: _kRed);
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
        caption: _telegramCaption,
      );
      _toast('اتبعتت نسخة على تليجرام ✨', color: _kGreen);
    } catch (e) {
      _toast('مقدرتش أبعت على تليجرام: $e', color: _kRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kPanel,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'صورة الفاتورة',
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
              icon: const Icon(Icons.send_rounded, color: _kGold),
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
                    width: kInvoiceCardWidth,
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: InvoiceShareCard(data: widget.data),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                color: _kPanel,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _share,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kGold,
                          foregroundColor: _kBg,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _kBg,
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
                        foregroundColor: _kGold,
                        side: const BorderSide(color: _kGold),
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
