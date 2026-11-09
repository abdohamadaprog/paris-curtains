import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

import '../config/app_features.dart';

/// رفع الصور على Cloudinary.
///
/// فيه مسارين:
///  1) **الموقّع (الموصى به)**: التطبيق بياخد توقيع من Cloud Function
///     (`getCloudinarySignature`) — محتاج خطة Blaze.
///  2) **المباشر (بدون سيرفر)**: رفع بـ unsigned upload preset — بيشتغل على
///     خطة Spark فقط (لما `cloudFunctionsEnabled = false`)، بس أي حد يعرف اسم
///     الـ preset يقدر يرفع. مؤقت لحد الترقية لـ Blaze، ومفيش فولباك تلقائي ليه.
///
/// الاختيار بيتم من `AppFeatures.cloudFunctionsEnabled`.
class CloudinaryService {
  CloudinaryService._();

  // نفس الـ region اللي في functions/index.js
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  static const String _folderPrefix = 'paris_curtains';

  /// بيرجّع secure_url.
  /// [folder]: `gallery` أو `promo`.
  static Future<String> uploadImage(
    Uint8List bytes, {
    required String filename,
    String folder = 'gallery',
  }) async {
    if (!AppFeatures.cloudFunctionsEnabled) {
      return _uploadUnsigned(bytes, filename: filename, folder: folder);
    }
    // لما الدوال مفعّلة بنرفع بتوقيع بس. مفيش رجوع للرفع غير الموقّع عند أي
    // خطأ، لأن ده كان بيفتح الثغرة (أي حد يعرف الـ preset يقدر يرفع).
    // الخطأ بيظهر للمستخدم وطابور الرفع بيعيد المحاولة.
    return _uploadSigned(bytes, filename: filename, folder: folder);
  }

  static Future<String> _uploadSigned(
    Uint8List bytes, {
    required String filename,
    required String folder,
  }) async {
    final signed = await _functions.httpsCallable('getCloudinarySignature').call(
      <String, dynamic>{'folder': folder},
    );
    final data = Map<String, dynamic>.from(signed.data as Map);
    final cloudName = data['cloudName'] as String;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    );
    request.fields['api_key'] = data['apiKey'].toString();
    request.fields['timestamp'] = data['timestamp'].toString();
    request.fields['signature'] = data['signature'] as String;
    request.fields['folder'] = data['folder'] as String;
    request.fields['allowed_formats'] = data['allowed_formats'] as String;
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    return _send(request);
  }

  /// رفع مباشر بـ unsigned preset (بدون Cloud Functions).
  static Future<String> _uploadUnsigned(
    Uint8List bytes, {
    required String filename,
    required String folder,
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

  /// حذف الصورة من Cloudinary (أدمن فقط، عن طريق Cloud Function).
  ///
  /// "best effort": لو فشل (مثلاً بدون Cloud Functions) بيمسح المستند من
  /// Firestore ويسيب الصورة في Cloudinary — مش مشكلة كبيرة.
  static Future<bool> deleteByUrl(String url) async {
    final publicId = publicIdFromUrl(url);
    if (publicId == null) return false;
    if (!AppFeatures.cloudFunctionsEnabled) return false;
    try {
      await _functions.httpsCallable('deleteCloudinaryAsset').call(
        <String, dynamic>{'publicId': publicId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
