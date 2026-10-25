import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/theme_manger.dart';
import 'paris_client_measurements_page.dart';

part 'clients_list/client_card.dart';
part 'clients_list/client_dialog.dart';
part 'clients_list/client_helpers.dart';
part 'clients_list/client_theme.dart';

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
  int _sortMode =
      0; // 0 موعد التركيب • 1 الأحدث تسجيلاً • 2 الأقدم تسجيلاً • 3 الاسم
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allDocs = const [];

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
              child: Row(
                children: [
                  Expanded(
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
                  PopupMenuButton<int>(
                    tooltip: 'ترتيب العملاء',
                    icon: const Icon(Icons.sort_rounded, color: _gold),
                    color: _dialogColor(context),
                    initialValue: _sortMode,
                    onSelected: (v) => setState(() => _sortMode = v),
                    itemBuilder: (_) => [
                      for (final entry in const {
                        0: 'حسب موعد التركيب',
                        1: 'الأحدث تسجيلاً',
                        2: 'الأقدم تسجيلاً',
                        3: 'الاسم (أ - ي)',
                      }.entries)
                        PopupMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: entry.key == _sortMode
                                  ? _gold
                                  : _primaryText(context),
                              fontWeight: entry.key == _sortMode
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('clients')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    final err = snapshot.error;
                    final denied =
                        err is FirebaseException &&
                        err.code == 'permission-denied';
                    final user = FirebaseAuth.instance.currentUser;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              denied
                                  ? 'الصلاحيات رفضت قراءة العملاء'
                                  : 'حصل خطأ أثناء تحميل العملاء',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              'السبب: $err\n'
                              'الحساب: ${user?.email ?? 'غير مسجّل دخول'}\n'
                              'الإيميل متحقق منه: ${user?.emailVerified}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _mutedText(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _gold),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  _allDocs = docs;
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
}
