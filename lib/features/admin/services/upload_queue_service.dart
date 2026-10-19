import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// In-memory upload queue shared by the upload page, dashboard and tracker.
/// Jobs survive navigation while the Flutter app remains alive, but not a
/// web reload, tab close, browser crash, or process termination.
class UploadQueueService extends ChangeNotifier {
  UploadQueueService._();

  static final UploadQueueService instance = UploadQueueService._();

  static const String cloudinaryUrl =
      'https://api.cloudinary.com/v1_1/dlmx10dic/image/upload';

  static const String uploadPreset = 'curtains_upload';

  final List<UploadQueueItem> _items = <UploadQueueItem>[];

  bool _running = false;
  bool _disposed = false;

  List<UploadQueueItem> get items => List.unmodifiable(_items);
  bool get isRunning => _running;

  int get total => _items.length;

  int get succeeded =>
      _items.where((e) => e.status == UploadItemStatus.success).length;

  int get failed =>
      _items.where((e) => e.status == UploadItemStatus.failed).length;

  int get pending => _items
      .where(
        (e) =>
            e.status == UploadItemStatus.pending ||
            e.status == UploadItemStatus.uploading ||
            e.status == UploadItemStatus.saving,
      )
      .length;

  bool get hasFailures => failed > 0;

  /// Adds files to the shared queue.
  Future<void> enqueue({
    required List<XFile> files,
    required String category,
    required double rating,
    required bool isAccessory,
    String? accessoryType,
    String? heavyFabric,
    String? lightFabric,
  }) async {
    if (files.isEmpty) return;

    final jobItems = <UploadQueueItem>[];

    for (final file in files) {
      jobItems.add(
        UploadQueueItem(
          file: file,
          filename: file.name.isNotEmpty
              ? file.name
              : 'image_${DateTime.now().microsecondsSinceEpoch}',
          documentId: FirebaseFirestore.instance
              .collection('gallery_images')
              .doc()
              .id,
          category: category,
          rating: rating,
          isAccessory: isAccessory,
          accessoryType: accessoryType,
          heavyFabric: heavyFabric,
          lightFabric: lightFabric,
        ),
      );
    }

    _items.addAll(jobItems);
    _notify();

    unawaited(_processPending());
  }

  /// Retries failed jobs.
  /// If Cloudinary already returned a URL, only Firestore is retried.
  Future<void> retryFailed() async {
    for (final item in _items.where(
      (e) => e.status == UploadItemStatus.failed,
    )) {
      item.status = item.cloudinaryUrl == null
          ? UploadItemStatus.pending
          : UploadItemStatus.saving;

      item.error = null;
    }

    _notify();
    unawaited(_processPending());
  }

  Future<void> _processPending() async {
    if (_running) return;

    _running = true;
    _notify();

    try {
      // Index-based iteration also picks up new tasks enqueued while running.
      for (var index = 0; index < _items.length; index++) {
        final item = _items[index];

        if (item.status != UploadItemStatus.pending &&
            item.status != UploadItemStatus.saving) {
          continue;
        }

        var currentStage = 'بدء العملية';

        try {
          if (item.cloudinaryUrl == null) {
            item.status = UploadItemStatus.uploading;
            item.error = null;
            _notify();

            currentStage = 'قراءة الصورة';
            debugPrint(
              '[UPLOAD DEBUG] ${item.filename} | المرحلة: $currentStage',
            );

            final Uint8List bytes = await item.file.readAsBytes().timeout(
              const Duration(minutes: 3),
            );

            debugPrint(
              '[UPLOAD DEBUG] ${item.filename} | '
              'تمت قراءة الصورة بنجاح | الحجم: ${bytes.length} bytes',
            );

            currentStage = 'رفع الصورة إلى Cloudinary';
            debugPrint(
              '[UPLOAD DEBUG] ${item.filename} | المرحلة: $currentStage',
            );

            // Keep the URL if upload succeeds, even if Firestore later fails.
            item.cloudinaryUrl = await _uploadToCloudinary(item, bytes);

            debugPrint(
              '[UPLOAD DEBUG] ${item.filename} | '
              'نجح رفع الصورة إلى Cloudinary',
            );
          }

          currentStage = 'حفظ البيانات في Firestore';
          item.status = UploadItemStatus.saving;
          _notify();

          debugPrint(
            '[UPLOAD DEBUG] ${item.filename} | المرحلة: $currentStage',
          );

          try {
            await _saveFirestore(item).timeout(const Duration(seconds: 30));
          } on TimeoutException {
            debugPrint(
              '[UPLOAD DEBUG] انتهت مهلة الحفظ، '
              'جارٍ التحقق من وجود السجل في Firestore...',
            );

            final doc = await FirebaseFirestore.instance
                .collection('gallery_images')
                .doc(item.documentId)
                .get()
                .timeout(const Duration(seconds: 15));

            final savedUrl = doc.data()?['url'];

            if (doc.exists && savedUrl == item.cloudinaryUrl) {
              debugPrint(
                '[UPLOAD DEBUG] السجل موجود بالفعل '
                'ورابط الصورة مطابق. سيتم اعتبار العملية ناجحة.',
              );
            } else {
              rethrow;
            }
          }
          debugPrint(
            '[UPLOAD DEBUG] ${item.filename} | '
            'تم حفظ البيانات في Firestore بنجاح',
          );
          //
          item.status = UploadItemStatus.success;
          item.error = null;
        } catch (error, stackTrace) {
          item.status = UploadItemStatus.failed;

          item.error = _friendlyError(error, stage: currentStage);

          debugPrint('========== UPLOAD DIAGNOSTICS ==========');
          debugPrint('File: ${item.filename}');
          debugPrint('Stage: $currentStage');
          debugPrint('Error type: ${error.runtimeType}');
          debugPrint('Original error: $error');
          debugPrint('Cloudinary URL saved: ${item.cloudinaryUrl != null}');
          debugPrint('User-facing error: ${item.error}');
          debugPrint('Stack trace: $stackTrace');
          debugPrint('=========================================');
        }

        _notify();
      }
    } finally {
      _running = false;
      _notify();
    }
  }

  Future<String> _uploadToCloudinary(
    UploadQueueItem item,
    Uint8List bytes,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));

    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: item.filename),
    );

    final response = await request.send().timeout(const Duration(minutes: 3));

    final body = await response.stream.bytesToString().timeout(
      const Duration(minutes: 1),
    );

    debugPrint('[CLOUDINARY DEBUG] HTTP status: ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[CLOUDINARY DEBUG] Response body: $body');

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

    final extension = _extension(item.filename);

    return (extension == 'heic' || extension == 'heif')
        ? secureUrl.replaceFirst('/upload/', '/upload/f_auto/')
        : secureUrl;
  }

  Future<void> _saveFirestore(UploadQueueItem item) async {
    final url = item.cloudinaryUrl;

    if (url == null || url.isEmpty) {
      throw StateError('رابط الصورة غير متاح للحفظ.');
    }

    final data = <String, dynamic>{
      'url': url,
      'category': item.category,
      'rating': item.rating,
      'created_at': FieldValue.serverTimestamp(),
      'sort_order': 0,
    };

    if (item.isAccessory) {
      data['accessory_type'] = item.accessoryType;
    } else {
      data['heavy_fabric'] = item.heavyFabric;
      data['light_fabric'] = item.lightFabric;
    }

    // Stable ID prevents duplicate records when retrying a timed-out write.
    await FirebaseFirestore.instance
        .collection('gallery_images')
        .doc(item.documentId)
        .set(data, SetOptions(merge: true));
  }

  static String _extension(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot < 0 ? '' : filename.substring(dot + 1).toLowerCase();
  }

  static String _friendlyError(Object error, {required String stage}) {
    final raw = error.toString();

    String message;

    if (error is TimeoutException || raw.contains('TimeoutException')) {
      switch (stage) {
        case 'قراءة الصورة':
          message =
              'انتهت مهلة قراءة الصورة من الجهاز أو المتصفح. جرّب صورة أصغر.';
          break;

        case 'رفع الصورة إلى Cloudinary':
          message =
              'انتهت مهلة رفع الصورة إلى Cloudinary. قد يكون الاتصال بطيئًا أو الطلب لم يكتمل.';
          break;

        case 'حفظ البيانات في Firestore':
          message =
              'انتهت مهلة حفظ البيانات في Firestore. قد تكون الصورة رُفعت بالفعل؛ أعد المحاولة للحفظ.';
          break;

        default:
          message = 'انتهت المهلة أثناء تنفيذ العملية.';
      }

      return 'المرحلة: $stage\n$message\nالتفاصيل: $raw';
    }

    // Extract Cloudinary's actual error message when available.
    final start = raw.indexOf('{');

    if (start >= 0) {
      try {
        final decoded = jsonDecode(raw.substring(start));

        if (decoded is Map &&
            decoded['error'] is Map &&
            decoded['error']['message'] != null) {
          message = decoded['error']['message'].toString();

          return 'المرحلة: $stage\nCloudinary: $message';
        }
      } catch (_) {
        // Continue to the general diagnostic below.
      }
    }

    if (raw.contains('FirebaseException')) {
      return 'المرحلة: $stage\n'
          'فشل التعامل مع Firestore.\n'
          'التفاصيل الأصلية: $raw';
    }

    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('ClientException')) {
      return 'المرحلة: $stage\n'
          'تعذّر الاتصال بالخادم. افحص الإنترنت وإمكانية الوصول إلى الخدمة.\n'
          'التفاصيل الأصلية: $raw';
    }

    if (raw.contains('Cloudinary HTTP')) {
      return 'المرحلة: $stage\n'
          'Cloudinary رفض طلب الرفع أو أعاد استجابة خطأ.\n'
          'التفاصيل الأصلية: $raw';
    }

    message = raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');

    return 'المرحلة: $stage\nالخطأ: $message';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class UploadQueueItem {
  UploadQueueItem({
    required this.file,
    required this.filename,
    required this.documentId,
    required this.category,
    required this.rating,
    required this.isAccessory,
    this.accessoryType,
    this.heavyFabric,
    this.lightFabric,
  });

  final XFile file;
  final String filename;
  final String documentId;
  final String category;
  final double rating;
  final bool isAccessory;
  final String? accessoryType;
  final String? heavyFabric;
  final String? lightFabric;

  UploadItemStatus status = UploadItemStatus.pending;
  String? cloudinaryUrl;
  String? error;
}

enum UploadItemStatus { pending, uploading, saving, success, failed }
