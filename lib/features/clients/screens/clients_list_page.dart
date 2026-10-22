import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// صفحة إدارة العملاء الخاصة بلوحة تحكم باريس للستاير.
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
  String _search = '';
  static const Color _background = Color(0xFF101018);
  static const Color _gold = Color(0xFFFFD54F);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
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
          backgroundColor: const Color(0xFF20202B),
          title: const Text('عميل جديد', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('اسم العميل'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'اكتب اسم العميل' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('رقم الهاتف'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('العنوان'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    style: const TextStyle(color: Colors.white),
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
        backgroundColor: const Color(0xFF20202B),
        title: const Text(
          'تعديل اسم العميل',
          style: TextStyle(color: Colors.white),
        ),
        content: Form(
          key: key,
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
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
        backgroundColor: const Color(0xFF20202B),
        title: const Text('حذف العميل؟', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل تريد حذف "$name"؟',
          style: const TextStyle(color: Colors.white70),
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
    hintStyle: const TextStyle(color: Colors.white54),
    filled: true,
    fillColor: Colors.white10,
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
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        title: const Text(
          'إدارة العملاء',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _gold,
          labelColor: _gold,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'شغل حالي'),
            Tab(text: 'الأرشيف'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('بحث عن عميل...').copyWith(
                prefixIcon: const Icon(Icons.search, color: _gold),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
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
                  return const Center(
                    child: Text(
                      'حصل خطأ أثناء تحميل العملاء',
                      style: TextStyle(color: Colors.redAccent),
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
                  final name = (doc.data()['name'] ?? '').toString();
                  return name.toLowerCase().contains(_search);
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
                        final date = _dateFrom(doc.data()['installation_date']);
                        return date == null || !date.isBefore(today);
                      }).toList(),
                      false,
                    ),
                    _clientList(
                      clients.where((doc) {
                        final date = _dateFrom(doc.data()['installation_date']);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClient,
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(
          'عميل جديد',
          style: TextStyle(fontWeight: FontWeight.bold),
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
        child: Text(
          archived ? 'الأرشيف فارغ' : 'لا يوجد شغل حالي',
          style: const TextStyle(color: Colors.white60, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final doc = clients[index];
        final data = doc.data();
        final name = (data['name'] ?? 'بدون اسم').toString();
        final date = _dateFrom(data['installation_date']);
        final done = data['installation_done'] == true;
        return Card(
          color: const Color(0xFF20202B),
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white10),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _gold.withValues(alpha: .15),
              child: Text(
                name.isNotEmpty ? name.characters.first : '?',
                style: const TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              [
                if (date == null)
                  'لم يتم تحديد موعد تركيب'
                else
                  'موعد التركيب: ${DateFormat('yyyy/MM/dd').format(date)}',
                done ? 'الشغل اتعمل' : 'لسه مش معمول',
              ].join(' • '),
              style: TextStyle(
                color: done ? const Color(0xFF72C69A) : Colors.white60,
              ),
            ),
            trailing: PopupMenuButton<String>(
              iconColor: Colors.white70,
              color: const Color(0xFF30303D),
              onSelected: (value) async {
                if (value == 'edit') _editClient(doc.id, name);
                if (value == 'delete') _deleteClient(doc.id, name);
                if (value == 'done') {
                  await doc.reference.update({
                    'installation_done': !done,
                    'installation_done_at': !done
                        ? FieldValue.serverTimestamp()
                        : null,
                  });
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text(
                    'تعديل الاسم',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                PopupMenuItem(
                  value: 'done',
                  child: Text(
                    done ? 'إلغاء تنفيذ الشغل' : 'تسجيل إن الشغل اتعمل',
                    style: const TextStyle(color: Colors.white),
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
          ),
        );
      },
    );
  }
}
