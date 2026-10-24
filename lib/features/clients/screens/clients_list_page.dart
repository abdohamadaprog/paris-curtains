import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/theme_manger.dart';
import 'paris_client_measurements_page.dart';

/// صفحة إدارة العملاء الخاصة بلوحة تحكم باريس للستائر.
/// تستخدم مجموعة Firestore الحالية: clients
class ClientsListPage extends StatefulWidget {
  const ClientsListPage({super.key});

  @override
  State<ClientsListPage> createState() => _ClientsListPageState();
}

class _ClientsListPageState extends State<ClientsListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _search = '';
  static const Color _gold = AppColors.primaryGold;

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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _addClient() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? installationDate;
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _dialogColor(context),
          title: Text(
            'عميل جديد',
            style: TextStyle(color: _primaryText(context)),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    style: TextStyle(color: _primaryText(context)),
                    decoration: _inputDecoration('اسم العميل'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'اكتب اسم العميل'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: _primaryText(context)),
                    decoration: _inputDecoration('رقم الهاتف'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    style: TextStyle(color: _primaryText(context)),
                    decoration: _inputDecoration('العنوان'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    style: TextStyle(color: _primaryText(context)),
                    decoration: _inputDecoration('ملاحظات'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month, color: _gold),
                    title: const Text(
                      'تاريخ التركيب',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      installationDate == null
                          ? 'اختياري'
                          : DateFormat('yyyy-MM-dd').format(installationDate!),
                      style: const TextStyle(color: _gold),
                    ),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: installationDate ?? now,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => installationDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await FirebaseFirestore.instance.collection('clients').add({
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'notes': notesController.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
          'installation_date': installationDate == null
              ? null
              : Timestamp.fromDate(installationDate!),
          'installation_done': false,
        });
        if (mounted) _message('تم إضافة العميل بنجاح');
      } catch (e) {
        if (mounted) _message('تعذر حفظ العميل: $e');
      }
    }
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    notesController.dispose();
  }

  Future<void> _editClient(String id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final key = GlobalKey<FormState>();
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _dialogColor(context),
        title: Text(
          'تعديل اسم العميل',
          style: TextStyle(color: _primaryText(context)),
        ),
        content: Form(
          key: key,
          child: TextFormField(
            controller: controller,
            style: TextStyle(color: _primaryText(context)),
            decoration: _inputDecoration('اسم العميل'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'اكتب اسم العميل' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        await FirebaseFirestore.instance.collection('clients').doc(id).update({
          'name': controller.text.trim(),
        });
        if (mounted) _message('تم تعديل اسم العميل');
      } catch (e) {
        if (mounted) _message('تعذر تعديل العميل: $e');
      }
    }
    controller.dispose();
  }

  Future<void> _deleteClient(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _dialogColor(context),
        title: Text(
          'حذف العميل؟',
          style: TextStyle(color: _primaryText(context)),
        ),
        content: Text(
          'هل تريد حذف "$name"؟',
          style: TextStyle(color: _mutedText(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance.collection('clients').doc(id).delete();
      if (mounted) _message('تم حذف العميل');
    } catch (e) {
      if (mounted) _message('تعذر حذف العميل: $e');
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = _isDark(context);
    final textColor = _primaryText(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // رأس عائم بنفس هوية HomeAppBar، لكن كل إجراء هنا مستقل لصفحة العملاء.
            Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withValues(alpha: .94),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: _gold.withValues(alpha: .16)),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: .10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 10, 8),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _gold, width: 1.5),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/paris1.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.curtains, color: _gold, size: 25),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'باريس',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _gold,
                            height: 1.2,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'إدارة العملاء',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _mutedText(context),
                            letterSpacing: .5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'البحث في العملاء',
                    onPressed: () => _searchFocusNode.requestFocus(),
                    icon: const Icon(
                      Icons.search_rounded,
                      color: _gold,
                      size: 27,
                    ),
                  ),
                  IconButton(
                    tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
                    onPressed: () => themeManger.toggleTheme(),
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: _gold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              decoration: BoxDecoration(
                color: _surfaceColor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                controller: _tabs,
                indicatorColor: _gold,
                labelColor: _gold,
                unselectedLabelColor: _mutedText(context),
                tabs: const [
                  Tab(text: 'شغل حالي'),
                  Tab(text: 'الأرشيف'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                focusNode: _searchFocusNode,
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _search = value.trim().toLowerCase()),
                style: TextStyle(color: textColor),
                decoration:
                    _inputDecoration(
                      'بحث عن عميل بالاسم أو الهاتف أو العنوان',
                    ).copyWith(
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _gold,
                      ),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'مسح البحث',
                              icon: Icon(
                                Icons.close_rounded,
                                color: _mutedText(context),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            ),
                    ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('clients')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'حصل خطأ أثناء تحميل العملاء',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _gold),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  final clients = docs.where((doc) {
                    final data = doc.data();
                    final name = (data['name'] ?? '').toString();
                    final phone = (data['phone'] ?? '').toString();
                    final address = (data['address'] ?? '').toString();
                    return name.toLowerCase().contains(_search) ||
                        phone.toLowerCase().contains(_search) ||
                        address.toLowerCase().contains(_search);
                  }).toList();
                  clients.sort((a, b) {
                    final ad = a.data()['created_at'];
                    final bd = b.data()['created_at'];
                    final at = ad is Timestamp ? ad.millisecondsSinceEpoch : 0;
                    final bt = bd is Timestamp ? bd.millisecondsSinceEpoch : 0;
                    return bt.compareTo(at);
                  });
                  final today = DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  );
                  return TabBarView(
                    controller: _tabs,
                    children: [
                      _clientList(
                        clients.where((doc) {
                          final date = _dateFrom(
                            doc.data()['installation_date'],
                          );
                          return date == null || !date.isBefore(today);
                        }).toList(),
                        false,
                      ),
                      _clientList(
                        clients.where((doc) {
                          final date = _dateFrom(
                            doc.data()['installation_date'],
                          );
                          return date != null && date.isBefore(today);
                        }).toList(),
                        true,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClient,
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 6,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 23),
        label: const Text(
          'إضافة عميل',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _clientList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> clients,
    bool archived,
  ) {
    if (clients.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              archived ? Icons.archive_outlined : Icons.people_outline,
              color: _mutedText(context).withValues(alpha: .45),
              size: 44,
            ),
            const SizedBox(height: 10),
            Text(
              archived ? 'الأرشيف فارغ' : 'لا يوجد شغل حالي',
              style: TextStyle(color: _mutedText(context), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final doc = clients[index];
        final data = doc.data();
        final name = (data['name'] ?? 'بدون اسم').toString().trim();
        final phone = (data['phone'] ?? '').toString().trim();
        final address = (data['address'] ?? '').toString().trim();
        final notes = (data['notes'] ?? '').toString().trim();
        final date = _dateFrom(data['installation_date']);
        final registrationDate = _dateFrom(data['created_at']);
        final done = data['installation_done'] == true;

        return Card(
          color: _surfaceColor(context),
          margin: const EdgeInsets.symmetric(vertical: 6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: done
                  ? const Color(0xFF72C69A).withValues(alpha: .45)
                  : _gold.withValues(alpha: .20),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ParisClientMeasurementsPage(
                    clientId: doc.id,
                    clientName: name,
                    phone: phone.isEmpty ? null : phone,
                    address: address.isEmpty ? null : address,
                    registrationDate: registrationDate,
                    installationDate: date,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: _gold.withValues(alpha: .15),
                    child: Text(
                      name.isNotEmpty ? name.characters.first : '?',
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'بدون اسم' : name,
                          style: TextStyle(
                            color: _primaryText(context),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                color: _gold,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  phone,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: _mutedText(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: _gold,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  address,
                                  style: TextStyle(
                                    color: _mutedText(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _clientInfoChip(
                              icon: Icons.calendar_month_outlined,
                              label: date == null
                                  ? 'موعد التركيب غير محدد'
                                  : DateFormat('yyyy/MM/dd').format(date),
                              color: _gold,
                            ),
                            if (registrationDate != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 5,
                                ),
                                child: Text(
                                  'تسجيل: ${DateFormat('yyyy/MM/dd').format(registrationDate)}',
                                  style: TextStyle(
                                    color: _mutedText(context),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            _clientInfoChip(
                              icon: done
                                  ? Icons.check_circle_outline
                                  : Icons.pending_outlined,
                              label: done ? 'تم تنفيذ الشغل' : 'لم يتم التنفيذ',
                              color: done
                                  ? const Color(0xFF72C69A)
                                  : _mutedText(context),
                            ),
                          ],
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'ملاحظات: $notes',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _mutedText(context).withValues(alpha: .8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'إجراءات العميل',
                    iconColor: _mutedText(context),
                    color: _dialogColor(context),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editClient(doc.id, name);
                      } else if (value == 'delete') {
                        await _deleteClient(doc.id, name);
                      } else if (value == 'done') {
                        try {
                          await doc.reference.update({
                            'installation_done': !done,
                            'installation_done_at': !done
                                ? FieldValue.serverTimestamp()
                                : null,
                          });
                          if (mounted) {
                            _message(
                              !done
                                  ? 'تم تسجيل تنفيذ الشغل'
                                  : 'تم إلغاء حالة التنفيذ',
                            );
                          }
                        } catch (e) {
                          if (mounted) _message('تعذر تحديث حالة التنفيذ: $e');
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          'تعديل الاسم',
                          style: TextStyle(color: _primaryText(context)),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'done',
                        child: Text(
                          done ? 'إلغاء تنفيذ الشغل' : 'تسجيل إن الشغل اتعمل',
                          style: TextStyle(color: _primaryText(context)),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'حذف العميل',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _clientInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
