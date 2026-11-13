import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_features.dart';

/// رفع الصور على Cloudinary (رفع مباشر بدون سيرفر).
///
/// المشروع على خطة Firebase Spark (مفيش Cloud Functions)، فالرفع بيتم
/// بـ unsigned upload preset. لازم في Cloudinary Console:
///   • الـ preset يكون **Unsigned**
///   • folder إجباري = `paris_curtains`
///   • تحديد أقصى حجم وأنواع الملفات المسموحة (حماية إضافية)
class CloudinaryService {
  CloudinaryService._();

  static const String _folderPrefix = 'paris_curtains';

  /// بيرجّع secure_url.
  /// [folder]: `gallery` أو `promo`.
  static Future<String> uploadImage(
    Uint8List bytes, {
    required String filename,
    String folder = 'gallery',
  }) async {
    final cloudName = AppFeatures.cloudinaryCloudName.trim();
    if (cloudName.isEmpty) {
      throw StateError(
        'اسم حساب Cloudinary مش متظبط. حطّه في '
        'lib/core/config/app_features.dart (cloudinaryCloudName).',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    );
    request.fields['upload_preset'] = AppFeatures.unsignedUploadPreset;
    request.fields['folder'] = '$_folderPrefix/$folder';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    return _send(request);
  }

  static Future<String> _send(http.MultipartRequest request) async {
    final response = await request.send().timeout(const Duration(minutes: 3));
    final body = await response.stream
        .bytesToString()
        .timeout(const Duration(minutes: 1));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudinary HTTP ${response.statusCode}: $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('رد Cloudinary مش مفهوم.');
    }
    final secureUrl = decoded['secure_url'];
    if (secureUrl is! String || secureUrl.isEmpty) {
      throw const FormatException('Cloudinary مش راجع رابط للصورة.');
    }
    return secureUrl;
  }

  /// استخراج public_id من رابط Cloudinary (secure_url).
  static String? publicIdFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.endsWith('cloudinary.com')) return null;

    final segments = uri.pathSegments;
    final uploadIndex = segments.indexOf('upload');
    if (uploadIndex == -1 || uploadIndex + 1 >= segments.length) return null;

    var rest = segments.sublist(uploadIndex + 1);

    // تخطي أي transformations قبل رقم النسخة (v123456)
    final versionIndex = rest.indexWhere((s) => RegExp(r'^v\d+$').hasMatch(s));
    if (versionIndex != -1) {
      rest = rest.sublist(versionIndex + 1);
    }
    if (rest.isEmpty) return null;

    final joined = Uri.decodeComponent(rest.join('/'));
    final dot = joined.lastIndexOf('.');
    final withoutExt = dot > 0 ? joined.substring(0, dot) : joined;
    return withoutExt.isEmpty ? null : withoutExt;
  }

  /// حذف الصورة من Cloudinary نفسه محتاج توقيع من سيرفر، ومفيش Cloud
  /// Functions على الخطة الحالية — فبنرجّع false دايمًا.
  ///
  /// يعني: حذف الصورة بيمسح مستندها من Firestore بس، والملف بيفضل موجود في
  /// Cloudinary (مش مشكلة كبيرة، ومش بيكسر حاجة في التطبيق).
  static Future<bool> deleteByUrl(String url) async => false;
}
