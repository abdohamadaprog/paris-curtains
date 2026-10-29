import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

/// رفع الصور لـ Cloudinary بتوقيع من Cloud Function.
///
/// مفيش upload preset مكشوف في التطبيق: الدالة `getCloudinarySignature`
/// بتتأكد إنك أدمن وإن الطلب جاي من التطبيق الأصلي (App Check)، وبتوقّع
/// باراميترات الرفع (الفولدر والصيغ المسموحة) بسر محفوظ على السيرفر.
class CloudinaryService {
  CloudinaryService._();

  // لازم تطابق region الدالة في functions/index.js
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  /// بيرفع الصورة ويرجّع secure_url.
  /// [folder]: `gallery` أو `promo` (السيرفر هو اللي بيحدد المسار الفعلي).
  static Future<String> uploadImage(
    Uint8List bytes, {
    required String filename,
    String folder = 'gallery',
  }) async {
    // 1) توقيع من السيرفر
    final signed = await _functions
        .httpsCallable('getCloudinarySignature')
        .call(<String, dynamic>{'folder': folder});
    final data = Map<String, dynamic>.from(signed.data as Map);

    final cloudName = data['cloudName'] as String;

    // 2) الرفع بنفس الباراميترات الموقّعة بالظبط (أي تغيير = Cloudinary يرفض)
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

    final response = await request.send().timeout(const Duration(minutes: 3));
    final body = await response.stream.bytesToString().timeout(
      const Duration(minutes: 1),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudinary HTTP ${response.statusCode}: $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('استجابة Cloudinary غير مفهومة.');
    }
    final secureUrl = decoded['secure_url'];
    if (secureUrl is! String || secureUrl.isEmpty) {
      throw const FormatException('Cloudinary لم يرجع رابط الصورة.');
    }
    return secureUrl;
  }
}
