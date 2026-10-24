part of '../clients_list_page.dart';

extension _ClientHelpers on _ClientsListPageState {
  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _surfaceColor(BuildContext context) =>
      _isDark(context) ? AppColors.surfaceDark : Colors.white;

  Color _dialogColor(BuildContext context) =>
      _isDark(context) ? AppColors.surfaceDark2 : AppColors.background;

  Color _primaryText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  Color _mutedText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: .68);

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: _mutedText(context)),
    filled: true,
    fillColor: _isDark(context) ? AppColors.glassWhite : AppColors.bgCreamy,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _ar(Object? n) => (n ?? '').toString().replaceAllMapped(
    RegExp(r'[0-9]'),
    (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
  );

  // آخر 10 أرقام من التليفون للمقارنة (بيتجاهل 0 / +20 / المسافات)
  String _phoneKey(String phone) {
    final d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  // لو الرقم مسجّل لعميل تاني بيرجع اسمه
  String? _duplicatePhoneOwner(String phone, {String? excludeId}) {
    final key = _phoneKey(phone);
    if (key.length < 8) return null;
    for (final d in _allDocs) {
      if (d.id == excludeId) continue;
      final other = (d.data()['phone'] ?? '').toString();
      if (other.isNotEmpty && _phoneKey(other) == key) {
        return (d.data()['name'] ?? 'بدون اسم').toString();
      }
    }
    return null;
  }

  // ===== إجراءات سريعة من الكارت =====
  String _intlPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('20')) return digits;
    return '20${digits.startsWith('0') ? digits.substring(1) : digits}';
  }

  Future<void> _launch(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _message('تعذر فتح الرابط');
    } catch (_) {
      if (mounted) _message('تعذر فتح الرابط');
    }
  }

  void _call(String phone) => _launch(Uri(scheme: 'tel', path: phone));

  void _whatsapp(String phone, String name) {
    final text = Uri.encodeComponent('السلام عليكم أ/ $name، معاك باريس للستائر');
    _launch(Uri.parse('https://wa.me/${_intlPhone(phone)}?text=$text'));
  }

  void _openMap(String address) {
    _launch(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
      ),
    );
  }

  Future<void> _toggleDone(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool done,
  ) async {
    try {
      await doc.reference.update({
        'installation_done': !done,
        'installation_done_at': !done ? FieldValue.serverTimestamp() : null,
      });
      if (mounted) {
        _message(!done ? 'تم تسجيل تنفيذ الشغل' : 'تم إلغاء حالة التنفيذ');
      }
    } catch (e) {
      if (mounted) _message('تعذر تحديث حالة التنفيذ: $e');
    }
  }

  // لون ونص موعد التركيب: النهارده / بكرة / فات الموعد
  (String, Color) _dateBadge(DateTime? date, bool done) {
    if (date == null) return ('موعد التركيب غير محدد', _mutedText(context));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = day.difference(today).inDays;
    final text = DateFormat('yyyy/MM/dd').format(date);
    if (done) return ('تم التركيب • $text', const Color(0xFF72C69A));
    if (diff < 0) return ('فات الموعد • $text', const Color(0xFFEF5350));
    if (diff == 0) return ('النهارده • $text', const Color(0xFFFFB74D));
    if (diff == 1) return ('بكرة • $text', const Color(0xFFFFB74D));
    return (text, _gold);
  }
}
