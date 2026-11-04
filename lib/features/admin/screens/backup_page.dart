import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_features.dart';
import '../services/local_backup_service.dart';

const Color _kBg = Color(0xFF0F172A);
const Color _kPanel = Color(0xFF1E293B);
const Color _kLine = Color(0xFF334155);
const Color _kGold = Color(0xFFC5A059);
const Color _kMuted = Color(0xFF94A3B8);
const Color _kGreen = Color(0xFF10B981);
const Color _kRed = Color(0xFFE57373);
const Color _kOrange = Color(0xFFF59E0B);

/// النسخ الاحتياطي + أرشيف العملاء المحذوفين.
///
/// • النسخة التلقائية بتتعمل كل يوم 3 الفجر من Cloud Function (dailyBackup).
/// • "نسخة الآن" بيشغّل نفس الدالة فورًا (runBackupNow).
/// • حذف العميل مبقاش نهائي: بيتنقل لـ clients_archive وتقدر ترجّعه من هنا.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _backingUp = false;
  bool _testingAgenda = false;
  bool _exporting = false;
  String _exportStatus = '';
  DateTime? _lastLocalBackup;
  String? _restoringId;

  static final DateFormat _dateFmt = DateFormat('yyyy/MM/dd  HH:mm');

  @override
  void initState() {
    super.initState();
    _loadLastLocalBackup();
  }

  Future<void> _loadLastLocalBackup() async {
    final d = await LocalBackupService.lastBackupAt();
    if (mounted) setState(() => _lastLocalBackup = d);
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

  // ============================ نسخة الآن ============================

  Future<void> _backupNow() async {
    if (_backingUp) return;
    setState(() => _backingUp = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable(
            'runBackupNow',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
          );
      final res = await callable.call();
      final data = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
      _toast(
        'تمت النسخة الاحتياطية ✨ (${data['total_docs'] ?? '?'} مستند)',
        color: _kGreen,
      );
    } on FirebaseFunctionsException catch (e) {
      _toast(e.message ?? 'فشلت النسخة الاحتياطية', color: _kRed);
    } catch (e) {
      _toast('فشلت النسخة الاحتياطية: $e', color: _kRed);
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  // ============================ نسخة يدوية (الوضع المجاني) ============================

  Future<void> _exportBackup() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _exportStatus = 'بجهّز النسخة...';
    });
    try {
      final result = await LocalBackupService.createBackup(
        onProgress: (m) {
          if (mounted) setState(() => _exportStatus = m);
        },
      );
      final share = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.path, mimeType: 'application/gzip')],
          text: 'نسخة احتياطية - باريس للستائر (${result.docs} مستند)',
        ),
      );
      if (share.status != ShareResultStatus.dismissed) {
        await LocalBackupService.markDone();
        await _loadLastLocalBackup();
        _toast('تم تجهيز النسخة (${result.docs} مستند) ✨', color: _kGreen);
      } else {
        _toast(
          'اتلغت المشاركة. النسخة محفوظة في التليفون بس مش مرسلة لحد.',
          color: _kOrange,
        );
      }
    } catch (e) {
      _toast(
        'تعذّر عمل النسخة. اتأكد إن النت شغّال وجرّب تاني. ($e)',
        color: _kRed,
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  Widget _manualBackupCard() {
    final last = _lastLocalBackup;
    final age = last == null ? null : DateTime.now().difference(last);
    final stale = last == null || age! > const Duration(days: 7);
    final color = stale ? _kOrange : _kGreen;
    final title = last == null
        ? 'لسه معملتش نسخة احتياطية'
        : stale
        ? 'عدّى أكتر من أسبوع على آخر نسخة'
        : 'آخر نسخة';

    return _box(
      borderColor: color.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                stale ? Icons.warning_amber_rounded : Icons.check_circle,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
          if (last != null) ...[
            const SizedBox(height: 10),
            _kv('التاريخ', _dateFmt.format(last)),
          ],
          const SizedBox(height: 12),
          const Text(
            'دلوقتي النسخة بتتعمل بإيدك: بتجهّز ملف فيه كل العملاء والمقاسات '
            'والفواتير والأرشيف والأسعار، وتبعته لنفسك على واتساب أو Drive أو '
            'الإيميل. اعملها مرة في الأسبوع على الأقل، وبعد أي شغل كبير.',
            style: TextStyle(color: _kMuted, fontSize: 12, height: 1.7),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exporting ? null : _exportBackup,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: _kBg,
                disabledBackgroundColor: _kLine,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kBg,
                      ),
                    )
                  : const Icon(Icons.ios_share_rounded, size: 19),
              label: Text(
                _exporting ? _exportStatus : 'تصدير نسخة احتياطية الآن',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================ تجربة تنبيه الأجندة ============================

  Future<void> _testAgendaAlert() async {
    if (_testingAgenda) return;
    setState(() => _testingAgenda = true);
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('sendAgendaNow');
      final res = await callable.call(<String, dynamic>{'day': 'tomorrow'});
      final data = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
      final devices = (data['devices'] as num?)?.toInt() ?? 0;
      final sent = (data['sent'] as num?)?.toInt() ?? 0;
      if (devices == 0) {
        _toast(
          'مفيش جهاز متسجّل. افتح لوحة الإدارة واسمح بالإشعارات الأول.',
          color: _kOrange,
        );
      } else {
        _toast('اتبعت التنبيه لـ $sent من $devices جهاز ✨', color: _kGreen);
      }
    } on FirebaseFunctionsException catch (e) {
      _toast(e.message ?? 'تعذّر إرسال التنبيه', color: _kRed);
    } catch (e) {
      _toast('تعذّر إرسال التنبيه: $e', color: _kRed);
    } finally {
      if (mounted) setState(() => _testingAgenda = false);
    }
  }

  // ============================ استرجاع عميل من الأرشيف ============================

  Future<void> _restore(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _kPanel,
          title: const Text(
            'استرجاع العميل؟',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Text(
            'هيرجع "$name" بمقاساته وفاتورته لقائمة العملاء.',
            style: const TextStyle(color: _kMuted, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: _kMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استرجاع', style: TextStyle(color: _kGold)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    setState(() => _restoringId = id);
    try {
      final archiveRef = _db.collection('clients_archive').doc(id);
      final detailsArchiveRef = archiveRef.collection('details').doc('main');
      final clientRef = _db.collection('clients').doc(id);

      final archiveSnap = await archiveRef.get();
      final detailsSnap = await detailsArchiveRef.get();
      final existing = await clientRef.get();

      final archived = archiveSnap.data();
      if (archived == null || archived['data'] is! Map) {
        _toast('بيانات الأرشيف ناقصة، متقدرش أسترجع العميل ده', color: _kRed);
        return;
      }
      if (existing.exists) {
        _toast('العميل ده موجود بالفعل في القائمة', color: _kOrange);
        return;
      }

      final clientData = Map<String, dynamic>.from(archived['data'] as Map);
      final detailsData = detailsSnap.data() == null
          ? <String, dynamic>{}
          : (Map<String, dynamic>.from(detailsSnap.data()!)
              ..remove('archived_at'));

      final batch = _db.batch();
      batch.set(clientRef, clientData);
      batch.set(clientRef.collection('details').doc('main'), detailsData);
      batch.update(archiveRef, {'restored_at': FieldValue.serverTimestamp()});
      await batch.commit();
      _toast('تم استرجاع "$name" ✨', color: _kGreen);
    } catch (e) {
      _toast('تعذّر الاسترجاع: $e', color: _kRed);
    } finally {
      if (mounted) setState(() => _restoringId = null);
    }
  }

  // ============================ الواجهة ============================

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
            'النسخ الاحتياطي والأرشيف',
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
            if (!AppFeatures.cloudFunctionsEnabled) ...[
              _sectionTitle('نسخة احتياطية يدوية', Icons.ios_share_rounded),
              const SizedBox(height: 10),
              _manualBackupCard(),
              const SizedBox(height: 26),
            ],
            if (AppFeatures.cloudFunctionsEnabled) ...[
              _sectionTitle('النسخ الاحتياطي', Icons.cloud_done_rounded),
              const SizedBox(height: 10),
              _backupCard(),
              const SizedBox(height: 26),
              _sectionTitle(
                'تنبيهات الأجندة',
                Icons.notifications_active_rounded,
              ),
              const SizedBox(height: 10),
              _box(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بيجيلك إشعار الساعة ٧ مساءً بتركيبات بكرة، والساعة ٨ '
                      'صباحًا بتركيبات النهاردة (من غير اللي خلصت).',
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _testingAgenda ? null : _testAgendaAlert,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kGold,
                          side: const BorderSide(color: _kGold),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _testingAgenda
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _kGold,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: const Text('جرّب التنبيه الآن'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
            ],
            _sectionTitle('أرشيف العملاء المحذوفين', Icons.inventory_2_rounded),
            const SizedBox(height: 6),
            const Text(
              'مفيش حاجة بتتمسح نهائي: العميل المحذوف بيتنقل هنا بمقاساته '
              'وفاتورته، وتقدر ترجّعه في أي وقت.',
              style: TextStyle(color: _kMuted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 10),
            _archiveList(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _kGold, size: 20),
        const SizedBox(width: 8),
        Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  // ----------------------------- كارت حالة النسخ -----------------------------

  Widget _backupCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('app_meta').doc('last_backup').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _box(
            child: const Text(
              'مش قادر أقرا حالة النسخ الاحتياطي. اتأكد إنك نشرت قواعد '
              'Firestore الجديدة.',
              style: TextStyle(color: _kRed, height: 1.6),
            ),
          );
        }
        final d = snap.data?.data();
        final status = (d?['status'] ?? 'none').toString();
        final finishedAt = (d?['finished_at'] as Timestamp?)?.toDate();
        final failedAt = (d?['failed_at'] as Timestamp?)?.toDate();
        final stale =
            status == 'ok' &&
            finishedAt != null &&
            DateTime.now().difference(finishedAt) > const Duration(hours: 36);

        late final Color color;
        late final String title;
        late final IconData icon;
        switch (status) {
          case 'ok':
            color = stale ? _kOrange : _kGreen;
            title = stale
                ? 'آخر نسخة قديمة (أكتر من يوم ونص)'
                : 'آخر نسخة ناجحة';
            icon = stale ? Icons.warning_amber_rounded : Icons.check_circle;
            break;
          case 'running':
            color = _kGold;
            title = 'نسخة شغالة دلوقتي...';
            icon = Icons.sync_rounded;
            break;
          case 'failed':
            color = _kRed;
            title = 'آخر محاولة نسخ فشلت';
            icon = Icons.error_rounded;
            break;
          default:
            color = _kMuted;
            title = 'لسه مفيش نسخة';
            icon = Icons.hourglass_empty_rounded;
        }

        final when = status == 'failed' ? failedAt : finishedAt;
        final counts = d?['counts'];

        return _box(
          borderColor: color.withValues(alpha: 0.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (when != null) ...[
                const SizedBox(height: 10),
                _kv('التاريخ', _dateFmt.format(when.toLocal())),
              ],
              if (status == 'ok') ...[
                _kv('عدد المستندات', '${d?['total_docs'] ?? '-'}'),
                _kv('الحجم', _fmtBytes(d?['bytes'])),
                if (counts is Map)
                  _kv(
                    'التفاصيل',
                    counts.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' • '),
                  ),
              ],
              if (status == 'failed' && d?['error'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  d!['error'].toString(),
                  style: const TextStyle(color: _kRed, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'بتتعمل نسخة تلقائية كل يوم الساعة 3 الفجر، وكل نسخة بتتحفظ '
                'ومبتتمسحش.',
                style: TextStyle(color: _kMuted, fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _backingUp ? null : _backupNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGold,
                    foregroundColor: _kBg,
                    disabledBackgroundColor: _kLine,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: _backingUp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kBg,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 19),
                  label: Text(
                    _backingUp ? 'جاري النسخ...' : 'نسخة احتياطية الآن',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              k,
              style: const TextStyle(color: _kMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtBytes(dynamic b) {
    final n = (b is num) ? b.toDouble() : 0.0;
    if (n <= 0) return '-';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _box({required Widget child, Color borderColor = _kLine}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  // ----------------------------- قائمة الأرشيف -----------------------------

  Widget _archiveList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('clients_archive')
          .orderBy('deleted_at', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _box(
            child: const Text(
              'مش قادر أقرا الأرشيف. اتأكد إنك نشرت قواعد Firestore الجديدة.',
              style: TextStyle(color: _kRed, height: 1.6),
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: _kGold)),
          );
        }
        // اللي اتسترجع قبل كده مبنعرضوش
        final docs = snap.data!.docs
            .where((d) => d.data()['restored_at'] == null)
            .toList();
        if (docs.isEmpty) {
          return _box(
            child: const Text(
              'الأرشيف فاضي. أي عميل تحذفه هيظهر هنا.',
              style: TextStyle(color: _kMuted),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kLine),
          ),
          child: Column(
            children: [
              for (int i = 0; i < docs.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: _kLine),
                _archiveTile(docs[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _archiveTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final name = (d['name'] ?? '').toString().trim();
    final shown = name.isEmpty ? 'عميل بدون اسم' : name;
    final deletedAt = (d['deleted_at'] as Timestamp?)?.toDate();
    final busy = _restoringId == doc.id;

    return ListTile(
      title: Text(
        shown,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        deletedAt == null
            ? 'اتحذف'
            : 'اتحذف: ${_dateFmt.format(deletedAt.toLocal())}',
        style: const TextStyle(color: _kMuted, fontSize: 11.5),
      ),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kGold),
            )
          : TextButton.icon(
              onPressed: _restoringId == null
                  ? () => _restore(doc.id, shown)
                  : null,
              icon: const Icon(Icons.restore_rounded, color: _kGold, size: 18),
              label: const Text('استرجاع', style: TextStyle(color: _kGold)),
            ),
    );
  }
}
