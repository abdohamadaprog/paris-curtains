import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// نتيجة كتابة على Firestore من وجهة نظر المستخدم.
enum WriteOutcome {
  /// السيرفر أكّد الكتابة.
  synced,

  /// السيرفر ماردّش في الوقت المحدد (غالبًا مفيش نت): التعديل متخزّن على
  /// الجهاز وهيترفع لوحده أول ما النت يرجع.
  queued,
}

/// حالة مزامنة البيانات مع السيرفر (للعمل بدون نت).
///
/// Firestore على أندرويد/iOS بيخزّن أي كتابة على الجهاز الأول ويرفعها لما
/// النت يرجع. المشكلة إن الـ Future بتاع الكتابة (`commit`/`set`/`update`)
/// مابيخلصش غير لما السيرفر يرد، فأي شاشة بتعمل `await` عليه كانت بتفضل
/// "بتحفظ..." للأبد وهو مفيش نت (والحفظ اللي بعده كان بيتأجّل).
///
/// [settle] بتحل ده: بتستنى السيرفر ثانية ونص بس، ولو ماردّش بتقول
/// "اتخزّن على الجهاز" وتكمّل، وبتفضل تتابع الكتابة في الخلفية وتبلّغ لو
/// السيرفر رفضها بعدين.
class SyncStatus extends ChangeNotifier {
  SyncStatus._() : _settleWait = const Duration(milliseconds: 1500);

  @visibleForTesting
  SyncStatus.forTest({Duration settleWait = const Duration(milliseconds: 50)})
    : _settleWait = settleWait;

  static final SyncStatus instance = SyncStatus._();

  /// المدة اللي نستنى فيها رد السيرفر قبل ما نعتبر الكتابة "متخزّنة محليًا".
  final Duration _settleWait;

  /// بعد قد إيه من غير رد من السيرفر نقول "مفيش نت" (يمنع الوميض في البداية).
  static const Duration _offlineGrace = Duration(seconds: 4);

  int _queued = 0; // كتابات اتخزّنت محليًا ولسه السيرفر ماأكدهاش
  bool _leftover = false; // كتابات من جلسة سابقة لسه مستنية الرفع
  bool _offline = false;
  int _rejected = 0;
  Object? _lastError;

  bool _started = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _offlineTimer;

  /// فيه تعديلات لسه ماترفعتش للسيرفر؟
  bool get hasPending => _queued > 0 || _leftover;

  /// عدد التعديلات المستنية الرفع (على الأقل ١ لو فيه كتابات من جلسة سابقة).
  /// ده تقدير للعرض بس — Firestore مش بيقول العدد الحقيقي.
  int get pendingCount => _queued > 0 ? _queued : (_leftover ? 1 : 0);

  /// مفيش اتصال بالسيرفر دلوقتي؟
  bool get offline => _offline;

  /// عدد التعديلات اللي السيرفر رفضها بعد ما اتخزّنت محليًا (مثلاً صلاحيات).
  int get rejected => _rejected;

  Object? get lastError => _lastError;

  void clearRejected() {
    if (_rejected == 0) return;
    _rejected = 0;
    _lastError = null;
    notifyListeners();
  }

  /// بيتنادى مرة واحدة بعد Firebase.initializeApp.
  void start() {
    if (_started) return;
    _started = true;

    // مستند عام صغير بنسمع عليه مع metadata: لما isFromCache تفضل true
    // فترة يبقى السيرفر مش واصلنا. (Firestore بيبلّغ بده بعد حوالي ١٠ ثواني
    // من انقطاع النت.)
    _sub = FirebaseFirestore.instance
        .collection('public_config')
        .doc('home')
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
          if (!snap.metadata.isFromCache) {
            _offlineTimer?.cancel();
            _offlineTimer = null;
            if (_offline) {
              _offline = false;
              notifyListeners();
              unawaited(_checkLeftover());
            }
          } else {
            _offlineTimer ??= Timer(_offlineGrace, () {
              _offlineTimer = null;
              if (!_offline) {
                _offline = true;
                notifyListeners();
              }
            });
          }
        }, onError: (Object _) {});

    unawaited(_checkLeftover());
  }

  /// فيه كتابات من المرة اللي فاتت (التطبيق اتقفل وهو مفيش نت) لسه مارفعتش؟
  Future<void> _checkLeftover() async {
    var done = false;
    unawaited(
      FirebaseFirestore.instance
          .waitForPendingWrites()
          .then((_) {
            done = true;
            if (_leftover) {
              _leftover = false;
              notifyListeners();
            }
          })
          .catchError((Object _) {}),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!done && !_leftover) {
      _leftover = true;
      notifyListeners();
    }
  }

  /// بتستنى كتابة Firestore بحد أقصى [_settleWait]:
  ///  - خلصت في الوقت: `synced`.
  ///  - اتأخرت (مفيش نت): `queued` والكتابة بتكمّل في الخلفية.
  ///  - فشلت في الوقت: بترمي الخطأ زي ما هو (الـ catch القديمة تفضل شغالة).
  ///  - فشلت بعد ما رجّعنا `queued`: بنزوّد [rejected] عشان الشريط يبلّغ.
  Future<WriteOutcome> settle<T>(Future<T> write) {
    final completer = Completer<WriteOutcome>();
    var answered = false;
    var counted = false;

    final timer = Timer(_settleWait, () {
      if (answered) return;
      answered = true;
      counted = true;
      _queued++;
      notifyListeners();
      completer.complete(WriteOutcome.queued);
    });

    write.then(
      (_) {
        timer.cancel();
        if (counted && _queued > 0) {
          _queued--;
          notifyListeners();
        }
        if (!answered) {
          answered = true;
          completer.complete(WriteOutcome.synced);
        }
      },
      onError: (Object error, StackTrace stack) {
        timer.cancel();
        if (counted && _queued > 0) _queued--;
        if (!answered) {
          answered = true;
          completer.completeError(error, stack);
        } else {
          _rejected++;
          _lastError = error;
          notifyListeners();
        }
      },
    );

    return completer.future;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _offlineTimer?.cancel();
    super.dispose();
  }
}
