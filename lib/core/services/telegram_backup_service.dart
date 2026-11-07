import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/image_url.dart';

/// إعدادات بوت تليجرام (بتتحفظ في Firestore للأدمن بس).
class TelegramConfig {
  const TelegramConfig({
    required this.botToken,
    required this.chatId,
    this.enabled = true,
  });

  final String botToken;
  final String chatId;
  final bool enabled;
}

class TelegramException implements Exception {
  const TelegramException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// نسخة احتياطية من صور المعرض على قناة تليجرام خاصة.
///
/// ليه؟ Cloudinary هو المصدر الأساسي، وتليجرام نسخة تانية مجانية وأمان لو
/// حصل أي مشكلة في الحساب. كل النداءات بتحصل من الموبايل مباشرة (HTTPS)
/// فشغالة على خطة Spark من غير Cloud Functions.
///
/// الإعدادات في: settings/telegram_backup
///   bot_token • chat_id • enabled • updated_at
class TelegramBackupService {
  TelegramBackupService._();

  static const String _collection = 'settings';
  static const String _docId = 'telegram_backup';

  static TelegramConfig? _cache;

  /// آخر إعدادات متحمّلة (من غير قراءة Firestore تاني).
  static TelegramConfig? get cached => _cache;

  static Future<TelegramConfig?> loadConfig({bool refresh = false}) async {
    if (!refresh && _cache != null) return _cache;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .get();
      final data = snap.data();
      final token = _normalizeToken((data?['bot_token'] ?? '').toString());
      final chat = (data?['chat_id'] ?? '').toString().trim();
      if (token.isEmpty || chat.isEmpty) {
        _cache = null;
        return null;
      }
      _cache = TelegramConfig(
        botToken: token,
        chatId: chat,
        enabled: data?['enabled'] != false,
      );
      return _cache;
    } catch (e) {
      debugPrint('[TELEGRAM] load config: $e');
      return _cache;
    }
  }

  static Future<void> saveConfig({
    required String botToken,
    required String chatId,
    bool enabled = true,
  }) async {
    final config = TelegramConfig(
      botToken: _normalizeToken(botToken),
      chatId: chatId.trim(),
      enabled: enabled,
    );
    await FirebaseFirestore.instance
        .collection(_collection)
        .doc(_docId)
        .set(<String, dynamic>{
          'bot_token': config.botToken,
          'chat_id': config.chatId,
          'enabled': config.enabled,
          'updated_at': FieldValue.serverTimestamp(),
        });
    _cache = config;
  }

  /// بيتأكد إن التوكن شغال، البوت شايف القناة، وعنده صلاحية ينشر.
  /// بيرجّع اسم القناة. (بيبعت رسالة صغيرة للتأكيد)
  static Future<String> verify({
    required String botToken,
    required String chatId,
  }) async {
    final token = _normalizeToken(botToken);
    final chat = chatId.trim();
    if (token.isEmpty) throw const TelegramException('التوكن فاضي.');
    if (chat.isEmpty) throw const TelegramException('الـ chat_id فاضي.');

    final info = await _post(token, 'getChat', <String, dynamic>{'chat_id': chat});
    final title = (info['title'] ??
            info['username'] ??
            info['first_name'] ??
            '')
        .toString();

    await _post(token, 'sendMessage', <String, dynamic>{
      'chat_id': chat,
      'text': '✅ الاتصال شغال — نسخة باريس للستائر على تليجرام',
      'disable_notification': true,
    });

    return title.isEmpty ? chat : title;
  }

  /// بيجيب chat_id القناة أوتوماتيك من آخر رسالة في القناة.
  /// شرط: البوت يكون أدمن في القناة، ويكون فيه رسالة واحدة على الأقل.
  static Future<String> discoverChatId({required String botToken}) async {
    final token = _normalizeToken(botToken);
    if (token.isEmpty) throw const TelegramException('اكتب التوكن الأول.');

    final result = await _request(token, 'getUpdates', <String, dynamic>{
      'limit': 100,
      'allowed_updates': <String>['channel_post', 'message'],
    });

    if (result is List) {
      // الأفضل: آخر رسالة في قناة (channel_post). بعدها أي شات تاني
      // (ممكن يكون محادثة خاصة مع البوت — بنستخدمها كخطة بديلة).
      for (final key in const <String>['channel_post', 'message']) {
        for (final update in result.reversed) {
          if (update is! Map) continue;
          final post = update[key];
          if (post is! Map) continue;
          final chat = post['chat'];
          if (chat is Map && chat['id'] != null) {
            final type = (chat['type'] ?? '').toString();
            if (key == 'channel_post' && type != 'channel') continue;
            return chat['id'].toString();
          }
        }
      }
    }

    throw const TelegramException(
      'مفيش رسائل لقيتها. ضيف البوت أدمن في القناة، ابعت أي رسالة في '
      'القناة، وجرّب تاني.',
    );
  }

  /// رفع صورة بالرابط (تليجرام بينزّلها بنفسه) — بدون رمي استثناء لو فشلت.
  static Future<bool> backupGalleryImage({
    required String documentId,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final config = await loadConfig();
      if (config == null || !config.enabled) return false;

      await sendPhoto(imageUrl: imageUrl, caption: caption, config: config);

      await FirebaseFirestore.instance
          .collection('gallery_images')
          .doc(documentId)
          .update(<String, dynamic>{
            'telegram_sent': true,
            'telegram_sent_at': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      debugPrint('[TELEGRAM] backup $documentId: $e');
      return false;
    }
  }

  /// رفع صورة واحدة. بيرمي [TelegramException] لو حصلت مشكلة.
  static Future<void> sendPhoto({
    required String imageUrl,
    String? caption,
    TelegramConfig? config,
  }) async {
    final cfg = config ?? await loadConfig();
    if (cfg == null) {
      throw const TelegramException('إعدادات تليجرام مش متظبطة.');
    }
    if (!cfg.enabled) {
      throw const TelegramException('الرفع التلقائي لتليجرام متوقف.');
    }

    final url = ImageUrl.banner(imageUrl);
    final text = (caption ?? '').trim();
    await _post(cfg.botToken, 'sendPhoto', <String, dynamic>{
      'chat_id': cfg.chatId,
      'photo': url,
      if (text.isNotEmpty)
        'caption': text.length > 900 ? text.substring(0, 900) : text,
    });
  }

  /// رفع صورة من ذاكرة التطبيق (PNG) — زي صورة الفاتورة أو صورة المقاسات.
  static Future<void> sendPhotoBytes({
    required Uint8List bytes,
    required String filename,
    String? caption,
    TelegramConfig? config,
  }) async {
    final cfg = config ?? await loadConfig();
    if (cfg == null) {
      throw const TelegramException('إعدادات تليجرام مش متظبطة.');
    }
    if (!cfg.enabled) {
      throw const TelegramException('الرفع التلقائي لتليجرام متوقف.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.telegram.org/bot${cfg.botToken}/sendPhoto'),
    );
    request.fields['chat_id'] = cfg.chatId;
    final text = (caption ?? '').trim();
    if (text.isNotEmpty) {
      request.fields['caption'] = text.length > 900
          ? text.substring(0, 900)
          : text;
    }
    request.files.add(
      http.MultipartFile.fromBytes('photo', bytes, filename: filename),
    );

    late final http.Response response;
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 90),
      );
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      throw TelegramException('مش قادر أوصل لتليجرام. اتأكد من النت. ($e)');
    }

    _read(response);
  }

  /// نسخة على تليجرام من صورة اتولدت في التطبيق.
  /// best effort: بترجع false بدل ما توقف الشغل لو الإعدادات مش موجودة.
  static Future<bool> backupGeneratedImage({
    required Uint8List bytes,
    required String filename,
    String? caption,
  }) async {
    try {
      final config = await loadConfig();
      if (config == null || !config.enabled) return false;
      await sendPhotoBytes(
        bytes: bytes,
        filename: filename,
        caption: caption,
        config: config,
      );
      return true;
    } catch (e) {
      debugPrint('[TELEGRAM] generated image: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------

  static String _normalizeToken(String raw) {
    var token = raw.trim();
    if (token.toLowerCase().startsWith('bot')) token = token.substring(3);
    if (token.startsWith('https://api.telegram.org/bot')) {
      token = token.substring('https://api.telegram.org/bot'.length);
    }
    final slash = token.indexOf('/');
    if (slash != -1) token = token.substring(0, slash);
    return token.trim();
  }

  static Future<Map<String, dynamic>> _post(
    String token,
    String method,
    Map<String, dynamic> body,
  ) async {
    final result = await _request(token, method, body);
    return result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
  }

  static Future<dynamic> _request(
    String token,
    String method,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('https://api.telegram.org/bot$token/$method');

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      throw TelegramException('مش قادر أوصل لتليجرام. اتأكد من النت. ($e)');
    }

    return _read(response);
  }

  static dynamic _read(http.Response response) {
    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {
      // الرد مش JSON — هنتعامل معاه تحت.
    }

    if (response.statusCode == 401) {
      throw const TelegramException(
        'التوكن غلط أو اتلغى. خد توكن جديد من BotFather وانسخه بصح.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final desc = (decoded?['description'] ?? '').toString();
      throw TelegramException(_arabicApiError(desc, response.statusCode));
    }

    if (decoded == null || decoded['ok'] != true) {
      final desc = (decoded?['description'] ?? '').toString();
      throw TelegramException(
        desc.isEmpty ? 'رد غير مفهوم من تليجرام.' : desc,
      );
    }

    return decoded['result'];
  }

  static String _arabicApiError(String description, int status) {
    final d = description.toLowerCase();
    if (d.contains('chat not found')) {
      return 'مش لاقي القناة. اتأكد إن البوت مضاف أدمن في القناة '
          'وإن الـ chat_id صح (بيبدأ بـ -100).';
    }
    if (d.contains('not enough rights') || d.contains('have no rights')) {
      return 'البوت مش عنده صلاحية ينشر. ضيفه أدمن وفعّل Post Messages.';
    }
    if (d.contains('failed to get http url content') ||
        d.contains('wrong url') ||
        d.contains('wrong file identifier')) {
      return 'تليجرام مش قادر ينزّل الصورة من الرابط.';
    }
    if (d.contains('chat_id is empty')) return 'الـ chat_id فاضي.';
    if (d.contains('unauthorized')) return 'التوكن غلط أو اتلغى.';
    if (description.isNotEmpty) return description;
    return 'تليجرام رفض الطلب ($status).';
  }
}
