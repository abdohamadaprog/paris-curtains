import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';

import '../services/local_backup_service.dart';
import 'telegram_backup_page.dart';

Color get _kBg => AppPalette.bg;
Color get _kPanel => AppPalette.panel;
Color get _kLine => AppPalette.line;
Color get _kGold => AppPalette.gold;
Color get _kMuted => AppPalette.muted;
Color get _kGreen => AppPalette.green;
Color get _kRed => AppPalette.red;
Color get _kOrange => AppPalette.orange;

/// النسخ الاحتياطي + أرشيف العملاء المحذوفين.
///
/// • "تصدير نسخة احتياطية الآن" بيجهّز ملف على الجهاز ويتشاركه (تليجرام/درايف)
///   — شغال على خطة Spark ومش محتاج أي سيرفر.
/// • حذف العميل مبقاش نهائي: بيتنقل لـ clients_archive وتقدر ترجّعه من هنا.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
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

  void _toast(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: color ?? _kPanel,
      ),
    );
  }

  // ============================ نسخة يدوية ============================

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
          Text(
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
                  ? SizedBox(
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

  // ============================ استرجاع عميل من الأرشيف ============================

  Future<void> _restore(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _kPanel,
          title: Text(
            'استرجاع العميل؟',
            style: TextStyle(color: AppPalette.text, fontSize: 16),
          ),
          content: Text(
            'هيرجع "$name" بمقاساته وفاتورته لقائمة العملاء.',
            style: TextStyle(color: _kMuted, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: _kMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('استرجاع', style: TextStyle(color: _kGold)),
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
    Theme.of(context); // يعيد البناء عند تغيير الثيم
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kPanel,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppPalette.text),
          title: Text(
            'النسخ الاحتياطي والأرشيف',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppPalette.text,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          children: [
            _sectionTitle('نسخة احتياطية يدوية', Icons.ios_share_rounded),
            const SizedBox(height: 10),
            _manualBackupCard(),
            const SizedBox(height: 26),
            _sectionTitle('نسخة صور المعرض على تليجرام', Icons.cloud_upload_rounded),
            const SizedBox(height: 10),
            _box(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'كل صورة بتترفع على المعرض بيتبعت نسخة منها على قناتك '
                    'الخاصة على تليجرام. ده شغال على الخطة المجانية ومش '
                    'محتاج سيرفر.',
                    style: TextStyle(color: _kMuted, fontSize: 12, height: 1.7),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TelegramBackupPage(),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGold,
                        side: BorderSide(color: _kGold),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      label: const Text('إعداد ومزامنة تليجرام'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            _sectionTitle('أرشيف العملاء المحذوفين', Icons.inventory_2_rounded),
            const SizedBox(height: 6),
            Text(
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
          style: TextStyle(
            color: AppPalette.text,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
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
              style: TextStyle(color: _kMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(color: AppPalette.text, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? _kLine),
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
            child: Text(
              'مش قادر أقرا الأرشيف. اتأكد إنك نشرت قواعد Firestore الجديدة.',
              style: TextStyle(color: _kRed, height: 1.6),
            ),
          );
        }
        if (!snap.hasData) {
          return Padding(
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
            child: Text(
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
                if (i > 0) Divider(height: 1, color: _kLine),
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
        style: TextStyle(
          color: AppPalette.text,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        deletedAt == null
            ? 'اتحذف'
            : 'اتحذف: ${_dateFmt.format(deletedAt.toLocal())}',
        style: TextStyle(color: _kMuted, fontSize: 11.5),
      ),
      trailing: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kGold),
            )
          : TextButton.icon(
              onPressed: _restoringId == null
                  ? () => _restore(doc.id, shown)
                  : null,
              icon: Icon(Icons.restore_rounded, color: _kGold, size: 18),
              label: Text('استرجاع', style: TextStyle(color: _kGold)),
            ),
    );
  }
}
