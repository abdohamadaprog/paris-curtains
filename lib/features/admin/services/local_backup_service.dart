import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نتيجة نسخة احتياطية يدوية.
class LocalBackupResult {
  const LocalBackupResult({
    required this.path,
    required this.docs,
    required this.bytes,
  });

  final String path;
  final int docs;
  final int bytes;
}

/// نسخة احتياطية يدوية (مجانية، من غير Cloud Functions).
///
/// بتقرا كل بيانات التطبيق من Firestore وتحفظها في ملف واحد مضغوط
/// `paris_backup_<تاريخ>.jsonl.gz` بنفس صيغة النسخة التلقائية، فيتسترجع
/// بنفس سكريبت `functions/scripts/restore-backup.js`.
/// الملف بتبعته لنفسك (واتساب / Drive / إيميل) من قائمة المشاركة.
class LocalBackupService {
  LocalBackupService._();

  static const String _prefKey = 'last_local_backup_ms';

  /// Collections المستوى الأول اللي بنعمل منها نسخة.
  static const List<String> _collections = [
    'clients',
    'clients_archive',
    'settings',
    'gallery_images',
    'promo_images',
    'accessories',
  ];

  /// دي ليها subcollection اسمها details (المقاسات).
  static const List<String> _withDetails = ['clients', 'clients_archive'];

  static const GetOptions _serverOnly = GetOptions(source: Source.server);

  /// آخر مرة اتعملت فيها نسخة (ومتشاركة). null لو لسه.
  static Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_prefKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// بتجهّز ملف النسخة. بترمي استثناء لو النت مقطوع (عشان منطلعش نسخة ناقصة).
  static Future<LocalBackupResult> createBackup({
    void Function(String message)? onProgress,
  }) async {
    final db = FirebaseFirestore.instance;
    final lines = <String>[];

    void add(String path, Map<String, dynamic> data) {
      lines.add(jsonEncode({'path': path, 'data': _ser(data)}));
    }

    for (final name in _collections) {
      onProgress?.call('بقرا $name...');
      final snap = await db.collection(name).get(_serverOnly);
      for (final doc in snap.docs) {
        add(doc.reference.path, doc.data());
      }

      if (_withDetails.contains(name)) {
        final docs = snap.docs;
        for (var i = 0; i < docs.length; i += 15) {
          final chunk = docs.skip(i).take(15).toList();
          final subs = await Future.wait(
            chunk.map((d) => d.reference.collection('details').get(_serverOnly)),
          );
          for (final sub in subs) {
            for (final sd in sub.docs) {
              add(sd.reference.path, sd.data());
            }
          }
          onProgress?.call('$name: ${math.min(i + 15, docs.length)} من ${docs.length}');
        }
      }
    }

    onProgress?.call('بضغط الملف...');
    final bytes = gzip.encode(utf8.encode('${lines.join('\n')}\n'));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_fileName(DateTime.now())}');
    await file.writeAsBytes(bytes, flush: true);

    return LocalBackupResult(
      path: file.path,
      docs: lines.length,
      bytes: bytes.length,
    );
  }

  static String _fileName(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'paris_backup_${d.year}-${two(d.month)}-${two(d.day)}_'
        '${two(d.hour)}${two(d.minute)}.jsonl.gz';
  }

  /// نفس صيغة functions/backup_lib.js بالظبط (عشان نفس سكريبت الاسترجاع يقراها).
  static dynamic _ser(dynamic v) {
    if (v == null) return null;
    if (v is String || v is bool) return v;
    if (v is num) {
      if (v is double) {
        if (v.isNaN) return {'__t': 'num', 'v': 'NaN'};
        if (v.isInfinite) return {'__t': 'num', 'v': v > 0 ? 'Infinity' : '-Infinity'};
      }
      return v;
    }
    if (v is Timestamp) return {'__t': 'ts', 's': v.seconds, 'n': v.nanoseconds};
    if (v is DateTime) {
      final ms = v.millisecondsSinceEpoch;
      return {'__t': 'ts', 's': ms ~/ 1000, 'n': (ms % 1000) * 1000000};
    }
    if (v is GeoPoint) return {'__t': 'geo', 'lat': v.latitude, 'lng': v.longitude};
    if (v is DocumentReference) return {'__t': 'ref', 'path': v.path};
    if (v is Blob) return {'__t': 'bytes', 'b64': base64Encode(v.bytes)};
    if (v is List) return v.map(_ser).toList();
    if (v is Map) {
      final out = <String, dynamic>{};
      v.forEach((k, val) => out[k.toString()] = _ser(val));
      if (out.containsKey('__t')) return {'__t': 'map', 'v': out};
      return out;
    }
    return v.toString();
  }
}
