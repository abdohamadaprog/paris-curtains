import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/services/telegram_backup_service.dart';

const Color _kBg = Color(0xFF0F172A);
const Color _kPanel = Color(0xFF1E293B);
const Color _kLine = Color(0xFF334155);
const Color _kGold = Color(0xFFC5A059);
const Color _kMuted = Color(0xFF94A3B8);
const Color _kGreen = Color(0xFF10B981);
const Color _kRed = Color(0xFFE57373);
const Color _kOrange = Color(0xFFF59E0B);

/// إعداد النسخة الاحتياطية على قناة تليجرام + رفع الصور القديمة.
///
/// الفكرة: كل صورة بتترفع على Cloudinary بيتبعت نسخة منها على القناة
/// (تلقائي)، والصفحة دي فيها زر لرفع كل الصور القديمة اللي لسه مرفوعتش.
class TelegramBackupPage extends StatefulWidget {
  const TelegramBackupPage({super.key});

  @override
  State<TelegramBackupPage> createState() => _TelegramBackupPageState();
}

class _TelegramBackupPageState extends State<TelegramBackupPage> {
  final TextEditingController _tokenCtrl = TextEditingController();
  final TextEditingController _chatCtrl = TextEditingController();

  bool _enabled = true;
  bool _obscure = true;
  bool _busy = false;
  bool _cancel = false;

  int _sent = 0;
  int _failed = 0;
  int _total = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final config = await TelegramBackupService.loadConfig(refresh: true);
    if (!mounted || config == null) return;
    setState(() {
      _tokenCtrl.text = config.botToken;
      _chatCtrl.text = config.chatId;
      _enabled = config.enabled;
    });
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: color,
      ),
    );
  }

  bool _validateFields() {
    if (_tokenCtrl.text.trim().isEmpty || _chatCtrl.text.trim().isEmpty) {
      _toast('اكتب التوكن و chat_id الأول', _kOrange);
      return false;
    }
    return true;
  }

  Future<bool> _save() async {
    if (!_validateFields()) return false;
    setState(() => _status = 'بحفظ الإعدادات...');
    try {
      await TelegramBackupService.saveConfig(
        botToken: _tokenCtrl.text,
        chatId: _chatCtrl.text,
        enabled: _enabled,
      );
      if (mounted) {
        setState(() => _status = 'تم حفظ الإعدادات ✅');
        _toast('تم الحفظ ✨', _kGreen);
      }
      return true;
    } catch (e) {
      if (mounted) {
        final denied = e is FirebaseException && e.code == 'permission-denied';
        setState(() {
          _status = denied
              ? 'تعذّر الحفظ: انشر قواعد Firestore الجديدة الأول.'
              : 'تعذّر الحفظ: $e';
        });
      }
      return false;
    }
  }

  Future<void> _discoverChat() async {
    if (_busy) return;
    if (_tokenCtrl.text.trim().isEmpty) {
      _toast('اكتب توكن البوت الأول', _kOrange);
      return;
    }
    setState(() {
      _busy = true;
      _status = 'بدوّر على القناة في رسايل البوت...';
    });
    try {
      final id = await TelegramBackupService.discoverChatId(
        botToken: _tokenCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _chatCtrl.text = id;
        _status = 'لقيتها ✅ الـ chat_id اتكتب فوق. دوس "اختبار الاتصال".';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'مش لاقي القناة: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testConnection() async {
    if (_busy) return;
    if (!_validateFields()) return;
    setState(() {
      _busy = true;
      _status = 'بجرّب الاتصال بالقناة...';
    });
    try {
      final title = await TelegramBackupService.verify(
        botToken: _tokenCtrl.text,
        chatId: _chatCtrl.text,
      );
      if (!mounted) return;
      setState(() => _status = 'تمام ✅ البوت شايف القناة: $title');
      _toast('الاتصال شغال — شوف القناة، فيه رسالة تجربة', _kGreen);
      // الحفظ بعد نجاح الاختبار (لو القواعد مش منشورة هيظهر في الحالة).
      try {
        await TelegramBackupService.saveConfig(
          botToken: _tokenCtrl.text,
          chatId: _chatCtrl.text,
          enabled: _enabled,
        );
      } catch (_) {
        if (!mounted) return;
        setState(
          () => _status =
              'الاتصال شغال، بس الحفظ فشل — انشر قواعد Firestore الجديدة.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'في مشكلة: $e');
      _toast('مش شغال: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadOldImages() async {
    if (_busy) return;
    final config = await TelegramBackupService.loadConfig();
    if (config == null) {
      _toast('احفظ التوكن والـ chat_id الأول', _kOrange);
      return;
    }

    setState(() {
      _busy = true;
      _cancel = false;
      _sent = 0;
      _failed = 0;
      _total = 0;
      _status = 'بجيب صور المعرض...';
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('gallery_images')
          .get();
      final pending = snap.docs.where((doc) {
        final data = doc.data();
        final url = (data['url'] ?? '').toString();
        return url.isNotEmpty && data['telegram_sent'] != true;
      }).toList();

      if (!mounted) return;
      if (pending.isEmpty) {
        setState(() {
          _status = 'كل صور المعرض مرفوعة على تليجرام بالفعل ✅';
          _busy = false;
        });
        return;
      }
      setState(() {
        _total = pending.length;
        _status = 'بترفع على تليجرام... 0 من $_total';
      });

      for (final doc in pending) {
        if (_cancel) break;
        final data = doc.data();
        try {
          await TelegramBackupService.sendPhoto(
            imageUrl: (data['url'] ?? '').toString(),
            caption: (data['category'] ?? '').toString(),
            config: config,
          );
          await doc.reference.update(<String, dynamic>{
            'telegram_sent': true,
            'telegram_sent_at': FieldValue.serverTimestamp(),
          });
          if (!mounted) return;
          setState(() {
            _sent++;
            _status = 'بترفع على تليجرام... $_sent من $_total';
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _failed++;
            _status = 'فيه مشكلة في صورة ($_failed فشلت). آخر خطأ: $e';
          });
        }

        // تليجرام بيرفض لو بعتنا أسرع من كده بكتير.
        if (!_cancel && (_sent + _failed) < _total) {
          await Future<void>.delayed(const Duration(seconds: 3));
        }
      }

      if (!mounted) return;
      setState(() {
        _status = _cancel
            ? 'اتوقف. اترفع $_sent من $_total صورة.'
            : 'خلصنا ✅ اترفع $_sent صورة'
                  '${_failed > 0 ? '، وفشل $_failed' : ''}.';
      });
      if (!_cancel) {
        _toast('تم رفع $_sent صورة على القناة ✨', _kGreen);
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'تعذّرت المزامنة: $e');
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
            'نسخة تليجرام',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          children: [
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'كل صورة بتترفع على المعرض بيتبعت نسخة منها على قناتك '
                    'الخاصة على تليجرام — أمان إضافي مجاني لو حصل أي مشكلة '
                    'في Cloudinary.',
                    style: TextStyle(color: _kMuted, fontSize: 12, height: 1.7),
                  ),
                  const SizedBox(height: 16),
                  _label('توكن البوت (من BotFather)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _tokenCtrl,
                    obscureText: _obscure,
                    enableSuggestions: false,
                    autocorrect: false,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _input('123456789:AAH...').copyWith(
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'إظهار' : 'إخفاء',
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _kMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _label('chat_id القناة (بيبدأ بـ -100)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _chatCtrl,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _input('-1001234567890'),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _discoverChat,
                      style: TextButton.styleFrom(
                        foregroundColor: _kGold,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.travel_explore_rounded, size: 16),
                      label: const Text(
                        'مش عارفه؟ جيبه أوتوماتيك من القناة',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'رفع تلقائي للصور الجديدة',
                      style: TextStyle(color: Colors.white, fontSize: 13.5),
                    ),
                    subtitle: const Text(
                      'لو قفلته، الصور مش هتترفع غير لما تدوس الزرار اللي تحت.',
                      style: TextStyle(color: _kMuted, fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _save,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kMuted,
                            side: const BorderSide(color: _kLine),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('حفظ'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _testConnection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kGold,
                            foregroundColor: _kBg,
                            disabledBackgroundColor: _kLine,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                          label: const Text(
                            'اختبار الاتصال',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle('الصور القديمة', Icons.cloud_upload_rounded),
            const SizedBox(height: 10),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'بترفع كل صور المعرض اللي لسه مرفوعتش على القناة. '
                    'بتنزل صورة كل ٣ ثواني عشان تليجرام ميرفضش الرفع — '
                    'سيبه شغال ومتقفلش الصفحة.',
                    style: TextStyle(color: _kMuted, fontSize: 12, height: 1.7),
                  ),
                  const SizedBox(height: 14),
                  if (_busy && _total > 0) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _total == 0 ? null : (_sent + _failed) / _total,
                        minHeight: 7,
                        backgroundColor: _kLine,
                        color: _kGold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_status.isNotEmpty) ...[
                    Text(
                      _status,
                      style: TextStyle(
                        color: _status.startsWith('خلصنا') ||
                                _status.startsWith('تمام') ||
                                _status.startsWith('كل صور')
                            ? _kGreen
                            : _status.startsWith('في مشكلة') ||
                                  _status.startsWith('تعذّر')
                            ? _kRed
                            : _kMuted,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy
                          ? () => setState(() => _cancel = true)
                          : _uploadOldImages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _busy ? _kRed : _kPanel,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: _busy ? _kRed : _kLine),
                      ),
                      icon: Icon(
                        _busy ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _busy
                            ? 'وقّف'
                            : 'ارفع صور المعرض القديمة على تليجرام',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'إزاي تجيب البيانات؟',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '١) كلم @BotFather → /newbot → هيبعتلك التوكن.\n'
                    '٢) ضيف البوت أدمن في القناة وفعّل Post Messages.\n'
                    '٣) ابعت أي رسالة في القناة، وبعدين افتح:\n'
                    'api.telegram.org/bot<التوكن>/getUpdates\n'
                    'وهتلاقي chat_id جوه "chat": {"id": -100...}.',
                    style: TextStyle(color: _kMuted, fontSize: 12, height: 1.9),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'التوكن بيتحفظ في قاعدة البيانات ومحدش يقدر يقراه غير '
                    'الأدمن. لو حسيت إنه اتكشف، اعمله Revoke من BotFather.',
                    style: TextStyle(color: _kOrange, fontSize: 11.5, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _kGold, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _kMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  InputDecoration _input(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
      filled: true,
      fillColor: _kBg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kGold),
      ),
    );
  }
}
