import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/work_stage.dart';

// نفس ألوان الفاتورة والمقاسات والعملاء
const Color _bg = Color(0xFF0F172A);
const Color _panel = Color(0xFF1E293B);
const Color _line = Color(0xFF334155);
const Color _gold = AppColors.primaryGold;
const Color _muted = Color(0xFF94A3B8);

// مراحل الشغل: المصدر الوحيد في core/constants/work_stage.dart
const Map<int, Color> _stageColors = WorkStage.colors;
const Map<int, String> _stageLabels = WorkStage.labels;

int _stageOf(Map<String, dynamic> data) => WorkStage.fromData(data);

String _ar(Object? n) => (n ?? '').toString().replaceAllMapped(
  RegExp(r'[0-9]'),
  (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
);

typedef _ClientDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

class InstallationAgendaPage extends StatefulWidget {
  const InstallationAgendaPage({super.key});

  @override
  State<InstallationAgendaPage> createState() => _InstallationAgendaPageState();
}

class _InstallationAgendaPageState extends State<InstallationAgendaPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// تغيير مرحلة الشغل — بنحدّث installation_done كمان عشان التقارير تفضل شغالة
  Future<void> _setStage(_ClientDoc doc, int stage) async {
    try {
      await doc.reference.update(WorkStage.updateFields(stage));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحديث المرحلة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('clients')
                    .where('installation_date', isNull: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData &&
                      snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _gold),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final events = <DateTime, List<_ClientDoc>>{};
                  for (final doc in docs) {
                    final ts = doc.data()['installation_date'];
                    if (ts is! Timestamp) continue;
                    events
                        .putIfAbsent(_normalizeDate(ts.toDate()), () => [])
                        .add(doc);
                  }

                  final dayEvents =
                      events[_normalizeDate(_selectedDay!)] ?? <_ClientDoc>[];
                  final doneCount = dayEvents
                      .where((d) => _stageOf(d.data()) == 4)
                      .length;

                  return Column(
                    children: [
                      _buildCalendar(events),
                      _buildDayHeader(dayEvents.length, doneCount),
                      const SizedBox(height: 6),
                      Expanded(
                        child: dayEvents.isEmpty
                            ? _buildEmptyDay()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  24,
                                ),
                                itemCount: dayEvents.length,
                                itemBuilder: (context, i) =>
                                    _buildClientTile(dayEvents[i]),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 10),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'أجندة التركيبات',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 19,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: _gold,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Map<DateTime, List<_ClientDoc>> events) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: TableCalendar<_ClientDoc>(
        locale: 'ar_EG',
        firstDay: DateTime(2023, 1, 1),
        lastDay: DateTime(2030, 12, 31),
        focusedDay: _focusedDay,
        rowHeight: 46,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: (day) => events[_normalizeDate(day)] ?? const [],
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _gold,
          ),
          leftChevronIcon: Icon(Icons.chevron_left_rounded, color: Colors.white),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
          ),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: _muted, fontSize: 12),
          weekendStyle: TextStyle(color: _gold, fontSize: 12),
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle: const TextStyle(color: Colors.white),
          weekendTextStyle: const TextStyle(color: _gold),
          outsideTextStyle: const TextStyle(color: Color(0xFF475569)),
          selectedTextStyle: const TextStyle(
            color: _bg,
            fontWeight: FontWeight.w900,
          ),
          selectedDecoration: const BoxDecoration(
            color: _gold,
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          todayDecoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: _gold),
          ),
        ),
        // نقط صغيرة تحت اليوم: لون كل عميل = مرحلته (لحد ٤ نقط)
        calendarBuilders: CalendarBuilders<_ClientDoc>(
          markerBuilder: (context, date, dayEvents) {
            if (dayEvents.isEmpty) return const SizedBox();
            final stages = dayEvents.map((d) => _stageOf(d.data())).toList()
              ..sort();
            return Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in stages.take(4))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.2),
                        decoration: BoxDecoration(
                          color: _stageColors[s],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _stageColors[s]!.withValues(alpha: 0.7),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) => _focusedDay = focusedDay,
      ),
    );
  }

  Widget _buildDayHeader(int total, int done) {
    final allDone = total > 0 && done == total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'شغل يوم ${_ar(DateFormat('d/M/yyyy').format(_selectedDay!))}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
          if (total > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (allDone ? _stageColors[4]! : _gold).withValues(
                  alpha: 0.14,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_ar(done)} / ${_ar(total)} تم',
                style: TextStyle(
                  color: allDone ? _stageColors[4] : _gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDay() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_rounded, size: 50, color: _line),
          SizedBox(height: 8),
          Text(
            'مفيش تركيبات في اليوم ده',
            style: TextStyle(color: _muted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildClientTile(_ClientDoc doc) {
    final data = doc.data();
    final stage = _stageOf(data);
    final color = _stageColors[stage]!;
    final name = (data['name'] ?? 'عميل').toString();
    final address = (data['address'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.10), _panel),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.3),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 14),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          // دايرة المرحلة: اضغط واختار ١ أحمر • ٢ أصفر • ٣ أزرق • ٤ أخضر
          PopupMenuButton<int>(
            tooltip: 'مرحلة الشغل',
            initialValue: stage,
            color: _panel,
            onSelected: (s) => _setStage(doc, s),
            itemBuilder: (_) => [
              for (final s in const [1, 2, 3, 4])
                PopupMenuItem<int>(
                  value: s,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _stageColors[s],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _stageColors[s]!.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_ar(s)} • ${_stageLabels[s]}',
                        style: TextStyle(
                          color: s == stage ? _stageColors[s] : Colors.white,
                          fontWeight: s == stage
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
                  border: Border.all(color: color, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 9,
                    ),
                  ],
                ),
                child: Text(
                  _ar(stage),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _stageLabels[stage]!,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (address.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: _muted),
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
