import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

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

  // توحيد صيغة التاريخ لإزالة الوقت
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // 1. الخلفية المضيئة
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonCyan.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(color: AppColors.neonCyan, blurRadius: 100),
                ],
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
                color: AppColors.neonGold.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(color: AppColors.neonGold, blurRadius: 100),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 2. الهيدر
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
                      Text(
                        "أجندة التركيبات",
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
                        color: Colors.white54,
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
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return Center(
                          child: CircularProgressIndicator(
                            color: AppColors.neonCyan,
                          ),
                        );

                      var docs = snapshot.data?.docs ?? [];

                      // تجميع الأحداث
                      Map<DateTime, List<DocumentSnapshot>> events = {};
                      for (var doc in docs) {
                        var data = doc.data() as Map<String, dynamic>;
                        if (data['installation_date'] != null) {
                          DateTime date =
                              (data['installation_date'] as Timestamp).toDate();
                          DateTime normalizedDate = _normalizeDate(date);
                          if (events[normalizedDate] == null)
                            events[normalizedDate] = [];
                          events[normalizedDate]!.add(doc);
                        }
                      }

                      List<DocumentSnapshot> selectedDayEvents =
                          events[_normalizeDate(_selectedDay!)] ?? [];

                      return Column(
                        children: [
                          // 3. التقويم (النيون)
                          Container(
                            margin: const EdgeInsets.all(15),
                            padding: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.glassWhite,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white10),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                ),
                              ],
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

                              // الستايل الفخم
                              headerStyle: HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: false,
                                titleTextStyle: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.neonCyan,
                                ),
                                leftChevronIcon: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                ),
                                rightChevronIcon: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                ),
                              ),

                              // 🔥🔥 هنا تم التصحيح 🔥🔥
                              daysOfWeekStyle: const DaysOfWeekStyle(
                                weekdayStyle: TextStyle(
                                  color: Colors.grey,
                                ), // تم التعديل
                                weekendStyle: TextStyle(
                                  color: Colors.redAccent,
                                ),
                              ),

                              calendarStyle: CalendarStyle(
                                defaultTextStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                                weekendTextStyle: const TextStyle(
                                  color: Colors.redAccent,
                                ),
                                outsideTextStyle: const TextStyle(
                                  color: Colors.white24,
                                ),
                                // اليوم المختار (ذهبي)
                                selectedDecoration: BoxDecoration(
                                  color: AppColors.neonGold,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.neonGold.withOpacity(
                                        0.5,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                // النهاردة (تركواز شفاف)
                                todayDecoration: BoxDecoration(
                                  color: AppColors.neonCyan.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.neonCyan),
                                ),
                                // نقط المواعيد (برتقالي)
                                markerDecoration: BoxDecoration(
                                  color: AppColors.neonOrange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 10),

                          // عنوان القائمة
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.list_alt,
                                  color: AppColors.neonGold,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "مواعيد يوم: ${DateFormat('yyyy-MM-dd', 'ar').format(_selectedDay!)}",
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 4. قائمة المواعيد (زجاجية)
                          Expanded(
                            child: selectedDayEvents.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.event_available,
                                          size: 50,
                                          color: Colors.white12,
                                        ),
                                        Text(
                                          "لا توجد تركيبات في هذا اليوم",
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
                                      var data =
                                          selectedDayEvents[index].data()
                                              as Map<String, dynamic>;
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        padding: const EdgeInsets.all(15),
                                        decoration: BoxDecoration(
                                          color: AppColors.glassWhite,
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          border: Border(
                                            right: BorderSide(
                                              color: AppColors.neonOrange,
                                              width: 4,
                                            ),
                                          ), // شريط برتقالي
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppColors.neonOrange
                                                    .withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: AppColors.neonOrange,
                                              ),
                                            ),
                                            const SizedBox(width: 15),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    data['name'] ?? "عميل",
                                                    style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  Text(
                                                    "موعد التركيب",
                                                    style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
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
