import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_colors.dart';

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

  bool _isDone(Map<String, dynamic> data) {
    return data['installation_done'] == true;
  }

  Future<void> _toggleDone(DocumentSnapshot doc, bool done) async {
    await doc.reference.update({
      'installation_done': done,
      'installation_done_at': done ? FieldValue.serverTimestamp() : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGold.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightGold.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'أجندة التركيبات',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.lightGold,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('clients')
                        .where('installation_date', isNull: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGold,
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      final events = <DateTime, List<DocumentSnapshot>>{};

                      for (final doc in docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['installation_date'] == null) continue;
                        final date =
                            (data['installation_date'] as Timestamp).toDate();
                        final normalizedDate = _normalizeDate(date);
                        events.putIfAbsent(normalizedDate, () => []).add(doc);
                      }

                      final selectedDayEvents =
                          events[_normalizeDate(_selectedDay!)] ?? [];
                      final doneCount = selectedDayEvents.where((doc) {
                        return _isDone(doc.data() as Map<String, dynamic>);
                      }).length;

                      return Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.all(15),
                            padding: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryGold.withValues(
                                  alpha: 0.28,
                                ),
                              ),
                            ),
                            child: TableCalendar(
                              locale: 'ar_EG',
                              firstDay: DateTime(2023, 1, 1),
                              lastDay: DateTime(2030, 12, 31),
                              focusedDay: _focusedDay,
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDay, day),
                              eventLoader: (day) {
                                return events[_normalizeDate(day)] ?? [];
                              },
                              headerStyle: const HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: false,
                                titleTextStyle: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.lightGold,
                                ),
                                leftChevronIcon: Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                ),
                                rightChevronIcon: Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                ),
                              ),
                              daysOfWeekStyle: const DaysOfWeekStyle(
                                weekdayStyle: TextStyle(color: Colors.grey),
                                weekendStyle: TextStyle(
                                  color: AppColors.lightGold,
                                ),
                              ),
                              calendarStyle: CalendarStyle(
                                defaultTextStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                                weekendTextStyle: const TextStyle(
                                  color: AppColors.lightGold,
                                ),
                                outsideTextStyle: const TextStyle(
                                  color: Colors.white24,
                                ),
                                selectedDecoration: BoxDecoration(
                                  color: AppColors.primaryGold,
                                  shape: BoxShape.circle,
                                ),
                                todayDecoration: BoxDecoration(
                                  color: AppColors.primaryGold.withValues(
                                    alpha: 0.28,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryGold,
                                  ),
                                ),
                                markerDecoration: const BoxDecoration(
                                  color: AppColors.primaryGold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (context, date, dayEvents) {
                                  if (dayEvents.isEmpty) return const SizedBox();
                                  final allDone = dayEvents.every((event) {
                                    final data =
                                        (event as DocumentSnapshot).data()
                                            as Map<String, dynamic>;
                                    return _isDone(data);
                                  });
                                  return Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        color: allDone
                                            ? AppColors.success
                                            : AppColors.primaryGold,
                                        shape: BoxShape.circle,
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
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.list_alt,
                                  color: AppColors.primaryGold,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'شغل يوم: ${DateFormat('yyyy-MM-dd', 'ar').format(_selectedDay!)}',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (selectedDayEvents.isNotEmpty)
                                  Text(
                                    '$doneCount / ${selectedDayEvents.length} تم',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: doneCount ==
                                              selectedDayEvents.length
                                          ? AppColors.success
                                          : AppColors.lightGold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: selectedDayEvents.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.event_available,
                                          size: 50,
                                          color: Colors.white12,
                                        ),
                                        Text(
                                          'لا توجد تركيبات في هذا اليوم',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            color: Colors.white24,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                    ),
                                    itemCount: selectedDayEvents.length,
                                    itemBuilder: (context, index) {
                                      final doc = selectedDayEvents[index];
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final done = _isDone(data);

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        padding: const EdgeInsets.all(15),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceDark,
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          border: Border(
                                            right: BorderSide(
                                              color: done
                                                  ? AppColors.success
                                                  : AppColors.primaryGold,
                                              width: 4,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color:
                                                    (done
                                                            ? AppColors.success
                                                            : AppColors
                                                                .primaryGold)
                                                        .withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                done
                                                    ? Icons.check_rounded
                                                    : Icons.person,
                                                color: done
                                                    ? AppColors.success
                                                    : AppColors.primaryGold,
                                              ),
                                            ),
                                            const SizedBox(width: 15),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    data['name'] ?? 'عميل',
                                                    style: const TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    done
                                                        ? 'الشغل اتعمل في اليوم ده'
                                                        : 'لسه الشغل مش معمول',
                                                    style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontSize: 12,
                                                      color: done
                                                          ? AppColors.success
                                                          : AppColors.lightGold,
                                                    ),
                                                  ),
                                                  if ((data['address'] ?? '')
                                                      .toString()
                                                      .isNotEmpty)
                                                    Text(
                                                      data['address'].toString(),
                                                      style: const TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontSize: 11,
                                                        color: Color(0xFFB8B5AF),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Switch(
                                              value: done,
                                              activeThumbColor:
                                                  AppColors.success,
                                              onChanged: (value) =>
                                                  _toggleDone(doc, value),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
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
        ],
      ),
    );
  }
}
