import 'package:flutter/material.dart';

import '../services/upload_queue_service.dart';

class UploadQueuePage extends StatefulWidget {
  const UploadQueuePage({super.key});

  @override
  State<UploadQueuePage> createState() => _UploadQueuePageState();
}

class _UploadQueuePageState extends State<UploadQueuePage> {
  final UploadQueueService _queue = UploadQueueService.instance;

  @override
  void initState() {
    super.initState();
    _queue.addListener(_refresh);
  }

  @override
  void dispose() {
    _queue.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = _queue.items;
    final done = _queue.succeeded + _queue.failed;
    final progress = items.isEmpty ? 0.0 : done / items.length;
    return Scaffold(
      backgroundColor: const Color(0xFF111217),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191A20),
        foregroundColor: Colors.white,
        title: const Text(
          'متابعة رفع الصور',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF202128),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _queue.isRunning
                      ? 'عملية الرفع شغالة'
                      : (_queue.failed > 0
                            ? 'في صور محتاجة إعادة محاولة'
                            : 'حالة عمليات الرفع'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFFD6B46A),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _count('الإجمالي', _queue.total, Colors.white),
                    _count('ناجح', _queue.succeeded, Colors.greenAccent),
                    _count('فاشل', _queue.failed, Colors.redAccent),
                    _count('متبقي', _queue.pending, Colors.amberAccent),
                  ],
                ),
                if (_queue.failed > 0) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _queue.isRunning ? null : _queue.retryFailed,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        'إعادة محاولة الفاشل فقط (${_queue.failed})',
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'تستمر العملية أثناء التنقل داخل التطبيق. لا تغلق أو تعِد تحميل التبويب قبل انتهاء الرفع.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontFamily: 'Cairo',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'لا توجد عمليات رفع حاليًا.',
                  style: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
                ),
              ),
            )
          else
            ...items.reversed.map(_itemCard),
        ],
      ),
    );
  }

  Widget _count(String label, int value, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$label: ',
        style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
      ),
      Text(
        '$value',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    ],
  );

  Widget _itemCard(UploadQueueItem item) {
    final (label, color, icon) = switch (item.status) {
      UploadItemStatus.pending => (
        'في الانتظار',
        Colors.white60,
        Icons.schedule,
      ),
      UploadItemStatus.uploading => (
        'جاري رفع الصورة',
        Colors.amberAccent,
        Icons.cloud_upload_outlined,
      ),
      UploadItemStatus.saving => (
        'جاري حفظ البيانات',
        Colors.lightBlueAccent,
        Icons.save_outlined,
      ),
      UploadItemStatus.success => (
        'اكتمل بنجاح',
        Colors.greenAccent,
        Icons.check_circle_outline,
      ),
      UploadItemStatus.failed => ('فشل', Colors.redAccent, Icons.error_outline),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF202128),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: item.status == UploadItemStatus.failed
              ? Colors.redAccent.withValues(alpha: .45)
              : Colors.white10,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.filename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'Cairo',
                    fontSize: 12,
                  ),
                ),
                if (item.error != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    'السبب: ${item.error}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontFamily: 'Cairo',
                      fontSize: 12,
                    ),
                  ),
                ],
                if (item.status == UploadItemStatus.saving &&
                    item.cloudinaryUrl != null)
                  const Text(
                    'الصورة اترفعت؛ جاري حفظ سجل المعرض فقط.',
                    style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontFamily: 'Cairo',
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
