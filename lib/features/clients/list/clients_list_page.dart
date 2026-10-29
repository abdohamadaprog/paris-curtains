import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/work_stage.dart';
import '../../../core/theme/theme_manager.dart';
import '../../auth/login_page.dart';
import '../measurements/paris_client_measurements_page.dart';

part 'client_card.dart';
part 'client_dialog.dart';
part 'client_helpers.dart';

/// بيانات خفيفة لكل عميل (بتتحسب مرة واحدة عند وصول البيانات، مش في كل build)
class _ClientItem {
  _ClientItem({
    required this.doc,
    required this.name,
    required this.searchKey,
    required this.phone,
    required this.address,
    required this.installDate,
    required this.registrationDate,
    required this.done,
    required this.stage,
    required this.createdMs,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String name;
  final String searchKey;
  final String phone;
  final String address;
  final DateTime? installDate;
  final DateTime? registrationDate;
  final bool done;
  final int stage;
  final int createdMs;
}

/// توحيد الاسم للبحث: يتجاهل الهمزات والتشكيل والتاء المربوطة وحالة الحروف
String _normalizeName(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// صفحة إدارة العملاء الخاصة بلوحة تحكم باريس للستائر.
/// تستخدم مجموعة Firestore الحالية: clients
class ClientsListPage extends StatefulWidget {
  const ClientsListPage({super.key, this.initialStage = 0});

  /// فلتر مرحلة مبدئي (١-٤) — ٠ يعني كل المراحل
  final int initialStage;

  @override
  State<ClientsListPage> createState() => _ClientsListPageState();
}

class _ClientsListPageState extends State<ClientsListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  String _search = '';
  int _sortMode = 0; // 0 موعد التركيب • 1 الأحدث تسجيلاً • 2 الاسم
  int _stageFilter = 0; // 0 = كل المراحل
  bool _loaded = false;
  bool _accessDenied = false; // Firestore رفض القراءة (مفيش جلسة أدمن)

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allDocs = const [];
  List<_ClientItem> _items = const [];
  List<_ClientItem> _current = const [];
  List<_ClientItem> _archive = const [];

  @override
  void initState() {
    super.initState();
    _stageFilter = widget.initialStage.clamp(0, 4);
    _tabs = TabController(length: 2, vsync: this);
    _loadFromCache();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tabs.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ===== تحميل البيانات =====

  /// أول ما الصفحة تفتح: اعرض آخر نسخة محفوظة على الجهاز فورًا،
  /// وبعدها الـ stream بيحدّث من السيرفر.
  Future<void> _loadFromCache() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('clients')
          .get(const GetOptions(source: Source.cache));
      if (!mounted || _loaded || snap.docs.isEmpty) return;
      _applyDocs(snap.docs);
    } catch (_) {
      // مفيش نسخة محفوظة، عادي — الـ stream هيجيب البيانات.
    }
  }

  void _listen() {
    _sub = FirebaseFirestore.instance
        .collection('clients')
        .snapshots()
        .listen(
          (snap) {
            if (mounted) _applyDocs(snap.docs);
          },
          onError: (Object error) {
            if (!mounted) return;
            // رفض الصلاحية بنوضّحه بدل ما القايمة تفضل فاضية من غير تفسير.
            // أي خطأ تاني (مثلاً النت) بنكمّل بآخر بيانات معروضة.
            final denied =
                error is FirebaseException && error.code == 'permission-denied';
            setState(() {
              _loaded = true;
              if (denied) _accessDenied = true;
            });
          },
        );
  }

  void _applyDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    _allDocs = docs;
    _items = docs.map(_toItem).toList();
    setState(() {
      _loaded = true;
      _accessDenied = false;
      _refilter();
    });
  }

  _ClientItem _toItem(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final created = data['created_at'];
    final name = (data['name'] ?? 'بدون اسم').toString().trim();
    return _ClientItem(
      doc: doc,
      name: name,
      searchKey: _normalizeName(name),
      phone: (data['phone'] ?? '').toString().trim(),
      address: (data['address'] ?? '').toString().trim(),
      installDate: _dateFrom(data['installation_date']),
      registrationDate: _dateFrom(created),
      done: _stageOf(data) == 4,
      stage: _stageOf(data),
      createdMs: created is Timestamp ? created.millisecondsSinceEpoch : 0,
    );
  }

  /// بيفلتر بالاسم ويرتّب ويقسّم لـ (شغل حالي / أرشيف) — بيتنادى بس
  /// لما البيانات أو البحث أو الترتيب يتغيروا.
  void _refilter() {
    final query = _normalizeName(_search);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = <_ClientItem>[];
    final archive = <_ClientItem>[];

    for (final c in _items) {
      if (query.isNotEmpty && !c.searchKey.contains(query)) continue;
      if (_stageFilter != 0 && c.stage != _stageFilter) continue;
      final d = c.installDate;
      if (d != null && d.isBefore(today)) {
        archive.add(c);
      } else {
        current.add(c);
      }
    }

    current.sort(_comparator(false));
    archive.sort(_comparator(true));
    _current = current;
    _archive = archive;
  }

  int Function(_ClientItem, _ClientItem) _comparator(bool archived) {
    switch (_sortMode) {
      case 1:
        return (a, b) => b.createdMs.compareTo(a.createdMs);
      case 2:
        return (a, b) => a.name.compareTo(b.name);
      default:
        return (a, b) {
          final ad = a.installDate;
          final bd = b.installDate;
          if (archived) {
            return (bd?.millisecondsSinceEpoch ?? 0).compareTo(
              ad?.millisecondsSinceEpoch ?? 0,
            );
          }
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        };
    }
  }

  // ===== الواجهة =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark(context)
          ? const Color(0xFF0F172A)
          : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchRow(context),
            _buildTabs(context),
            _buildStageFilter(context),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator(color: _gold))
                  : _accessDenied
                  ? _buildAccessDenied(context)
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _clientList(_current, false),
                        _clientList(_archive, true),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClient,
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
        label: const Text(
          'إضافة عميل',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = _isDark(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 4),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
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
                    const Icon(Icons.curtains, color: _gold, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'العملاء',
                  style: TextStyle(
                    color: _primaryText(context),
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                Text(
                  _loaded ? '${_ar(_items.length)} عميل' : 'ستائر باريس',
                  style: TextStyle(color: _mutedText(context), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
            onPressed: () => themeManager.toggleTheme(),
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              focusNode: _searchFocusNode,
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() {
                _search = value;
                _refilter();
              }),
              style: TextStyle(color: _primaryText(context)),
              decoration: _inputDecoration('ابحث باسم العميل').copyWith(
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: _gold),
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
                          setState(() {
                            _search = '';
                            _refilter();
                          });
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<int>(
            tooltip: 'ترتيب العملاء',
            color: _dialogColor(context),
            initialValue: _sortMode,
            onSelected: (v) => setState(() {
              _sortMode = v;
              _refilter();
            }),
            itemBuilder: (_) => [
              for (final entry in const {
                0: 'حسب موعد التركيب',
                1: 'الأحدث تسجيلاً',
                2: 'الاسم (أ - ي)',
              }.entries)
                PopupMenuItem<int>(
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
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isDark(context)
                    ? AppColors.glassWhite
                    : AppColors.bgCreamy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sort_rounded, color: _gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabs,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _gold,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: _mutedText(context),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        unselectedLabelStyle: const TextStyle(fontSize: 13.5),
        splashBorderRadius: BorderRadius.circular(10),
        tabs: [
          Tab(height: 38, text: 'شغل حالي (${_ar(_current.length)})'),
          Tab(height: 38, text: 'الأرشيف (${_ar(_archive.length)})'),
        ],
      ),
    );
  }

  /// فلتر المراحل: الكل + ١ أحمر + ٢ أصفر + ٣ أزرق + ٤ أخضر (بالعدد)
  Widget _buildStageFilter(BuildContext context) {
    final counts = {1: 0, 2: 0, 3: 0, 4: 0};
    final query = _normalizeName(_search);
    var total = 0;
    for (final c in _items) {
      if (query.isNotEmpty && !c.searchKey.contains(query)) continue;
      counts[c.stage] = (counts[c.stage] ?? 0) + 1;
      total++;
    }

    Widget chip({
      required bool selected,
      required Color color,
      required String label,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.18)
                  : _surfaceColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.25),
                width: selected ? 1.4 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.30),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? color : _mutedText(context),
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        children: [
          chip(
            selected: _stageFilter == 0,
            color: _gold,
            label: 'الكل (${_ar(total)})',
            onTap: () => setState(() {
              _stageFilter = 0;
              _refilter();
            }),
          ),
          for (final stage in const [1, 2, 3, 4])
            chip(
              selected: _stageFilter == stage,
              color: _stageColors[stage]!,
              label: '${_ar(stage)} • ${_ar(counts[stage])}',
              onTap: () => setState(() {
                _stageFilter = _stageFilter == stage ? 0 : stage;
                _refilter();
              }),
            ),
        ],
      ),
    );
  }

  /// الجلسة انتهت أو الحساب مش أدمن: رسالة واضحة وزرار للدخول
  Widget _buildAccessDenied(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 52,
              color: _mutedText(context),
            ),
            const SizedBox(height: 12),
            Text(
              'مفيش صلاحية لعرض العملاء',
              style: TextStyle(
                color: _primaryText(context),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'الجلسة انتهت أو الحساب مش أدمن. سجّل دخول بحساب الأدمن.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedText(context), fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text(
                'تسجيل الدخول',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
