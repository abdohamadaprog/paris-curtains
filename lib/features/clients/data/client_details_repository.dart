import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// مقاسات العميل (الشبابيك + البلكونات + المحذوفات).
///
/// بتتخزن في مستند منفصل: clients/{id}/details/main
/// عشان قائمة العملاء متحمّلش مقاسات كل العملاء، وكل عميل يحمّل مقاساته
/// هو بس لما تفتحه.
class ClientDetails {
  const ClientDetails({
    this.measurements = const [],
    this.balconies = const [],
    this.deletedCards = const [],
    this.isLegacy = false,
  });

  final List<Map<String, dynamic>> measurements;
  final List<Map<String, dynamic>> balconies;
  final List<Map<String, dynamic>> deletedCards;

  /// true لو البيانات اتقرت من مستند العميل القديم (قبل الفصل)
  final bool isLegacy;

  bool get isEmpty =>
      measurements.isEmpty && balconies.isEmpty && deletedCards.isEmpty;

  /// بصمة بسيطة للمقارنة (هل اللي جه من السيرفر مختلف عن المعروض؟)
  String get signature {
    try {
      return jsonEncode([measurements, balconies, deletedCards]);
    } catch (_) {
      return '${measurements.length}-${balconies.length}-${deletedCards.length}';
    }
  }

  static List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  factory ClientDetails.fromMap(
    Map<String, dynamic> data, {
    bool isLegacy = false,
  }) {
    return ClientDetails(
      measurements: _list(data['measurements']),
      balconies: _list(data['balconies']),
      deletedCards: _list(data['deleted_cards']),
      isLegacy: isLegacy,
    );
  }
}

class ClientDetailsRepository {
  ClientDetailsRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// لو قواعد Firestore رفضت المسار الجديد، بنرجع للتخزين القديم جوه مستند
  /// العميل لفترة قصيرة (دقيقتين) وبعدها بنجرّب تاني. الرفض ممكن يكون مؤقت
  /// (مثلاً الجلسة لسه ما اتفتحتش) فمنثبّتوش لحد ما التطبيق يتقفل.
  static DateTime? _detailsDeniedAt;

  static bool get _detailsDenied =>
      _detailsDeniedAt != null &&
      DateTime.now().difference(_detailsDeniedAt!) < const Duration(minutes: 2);

  static DocumentReference<Map<String, dynamic>> _clientRef(String id) =>
      _db.collection('clients').doc(id);

  static DocumentReference<Map<String, dynamic>> _detailsRef(String id) =>
      _clientRef(id).collection('details').doc('main');

  static bool _isDenied(Object e) =>
      e is FirebaseException && e.code == 'permission-denied';

  /// قراءة سريعة من الكاش المحلي (فورية). بترجع null لو مفيش نسخة محفوظة.
  static Future<ClientDetails?> loadCached(String clientId) async {
    const cache = GetOptions(source: Source.cache);
    try {
      if (!_detailsDenied) {
        final d = await _detailsRef(clientId).get(cache);
        if (d.exists) return ClientDetails.fromMap(d.data() ?? {});
      }
    } catch (_) {}
    try {
      final c = await _clientRef(clientId).get(cache);
      final data = c.data();
      if (c.exists && data != null) {
        final legacy = ClientDetails.fromMap(data, isLegacy: true);
        if (!legacy.isEmpty) return legacy;
      }
    } catch (_) {}
    return null;
  }

  /// قراءة من السيرفر (الأحدث).
  static Future<ClientDetails> loadServer(String clientId) async {
    if (!_detailsDenied) {
      try {
        final d = await _detailsRef(clientId).get();
        if (d.exists) return ClientDetails.fromMap(d.data() ?? {});
      } catch (e) {
        if (!_isDenied(e)) rethrow;
        _detailsDeniedAt = DateTime.now();
      }
    }
    final c = await _clientRef(clientId).get();
    return ClientDetails.fromMap(c.data() ?? {}, isLegacy: true);
  }

  /// للفاتورة: الكاش الأول (بيشمل آخر حفظ حتى لو لسه ما اتأكدش من السيرفر)،
  /// ولو مفيش كاش بيروح للسيرفر.
  static Future<ClientDetails> loadFast(String clientId) async {
    return await loadCached(clientId) ?? await loadServer(clientId);
  }

  /// مستند العميل نفسه (الخفيف) — الكاش الأول.
  static Future<Map<String, dynamic>> loadClientDocFast(String clientId) async {
    try {
      final c = await _clientRef(
        clientId,
      ).get(const GetOptions(source: Source.cache));
      if (c.exists) return c.data() ?? {};
    } catch (_) {}
    final c = await _clientRef(clientId).get();
    return c.data() ?? {};
  }

  /// حفظ المقاسات. بيكتب المستند الجديد وبيشيل الحقول القديمة التقيلة من
  /// مستند العميل في نفس العملية (Batch)، فالترحيل بيحصل لوحده.
  static Future<void> save({
    required String clientId,
    required Map<String, dynamic> clientFields,
    required ClientDetails details,
  }) async {
    final payload = <String, dynamic>{
      'measurements': details.measurements,
      'balconies': details.balconies,
      'deleted_cards': details.deletedCards,
    };

    if (!_detailsDenied) {
      try {
        final batch = _db.batch();
        batch.set(_detailsRef(clientId), {
          ...payload,
          'updated_at': FieldValue.serverTimestamp(),
        });
        batch.set(_clientRef(clientId), {
          ...clientFields,
          'updated_at': FieldValue.serverTimestamp(),
          'measurements': FieldValue.delete(),
          'balconies': FieldValue.delete(),
          'deleted_cards': FieldValue.delete(),
        }, SetOptions(merge: true));
        await batch.commit();
        return;
      } catch (e) {
        if (!_isDenied(e)) rethrow;
        _detailsDeniedAt = DateTime.now();
      }
    }

    // رجوع للتخزين القديم (لو القواعد مش مسموحة للمسار الجديد)
    await _clientRef(clientId).set({
      ...clientFields,
      ...payload,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
