part of '../clients_list_page.dart';

extension _ClientCard on _ClientsListPageState {
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

    // الترتيب حسب اختيارك من زر الترتيب (الافتراضي: الشغل الحالي الأقرب موعدًا
    // فوق، والأرشيف الأحدث فوق)
    final sorted = [...clients];
    int ms(dynamic v) => v is Timestamp ? v.millisecondsSinceEpoch : 0;
    sorted.sort((a, b) {
      switch (_sortMode) {
        case 1:
          return ms(b.data()['created_at']).compareTo(ms(a.data()['created_at']));
        case 2:
          return ms(a.data()['created_at']).compareTo(ms(b.data()['created_at']));
        case 3:
          return (a.data()['name'] ?? '').toString().compareTo(
            (b.data()['name'] ?? '').toString(),
          );
        default:
          final ad = _dateFrom(a.data()['installation_date']);
          final bd = _dateFrom(b.data()['installation_date']);
          if (archived) {
            return (bd?.millisecondsSinceEpoch ?? 0).compareTo(
              ad?.millisecondsSinceEpoch ?? 0,
            );
          }
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
      }
    });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
      itemCount: sorted.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 2),
            child: Text(
              '${_ar(sorted.length)} عميل',
              style: TextStyle(color: _mutedText(context), fontSize: 12),
            ),
          );
        }
        final doc = sorted[index - 1];
        final data = doc.data();
        final name = (data['name'] ?? 'بدون اسم').toString().trim();
        final phone = (data['phone'] ?? '').toString().trim();
        final address = (data['address'] ?? '').toString().trim();
        final notes = (data['notes'] ?? '').toString().trim();
        final date = _dateFrom(data['installation_date']);
        final registrationDate = _dateFrom(data['created_at']);
        final done = data['installation_done'] == true;
        var mCount = 0;
        var heavySum = 0.0;
        var lightSum = 0.0;
        final rawMeasurements = data['measurements'];
        if (rawMeasurements is List) {
          for (final raw in rawMeasurements) {
            if (raw is Map && raw['enabled'] != false) {
              mCount++;
              heavySum += (raw['heavy_meters'] as num?)?.toDouble() ?? 0;
              lightSum += (raw['light_meters'] as num?)?.toDouble() ?? 0;
            }
          }
        }
        String meters(double v) =>
            _ar(v == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(1));
        final (dateLabel, dateColor) = _dateBadge(date, done);
        final overdue = dateColor == const Color(0xFFEF5350);
        const doneColor = Color(0xFF72C69A);

        Widget action(IconData icon, Color color, String tip, VoidCallback f) {
          return IconButton(
            tooltip: tip,
            onPressed: f,
            icon: Icon(icon, color: color, size: 20),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 34),
          );
        }

        return Card(
          color: _surfaceColor(context),
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: overdue
                  ? const Color(0xFFEF5350).withValues(alpha: .55)
                  : done
                  ? doneColor.withValues(alpha: .45)
                  : _gold.withValues(alpha: .20),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
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
              padding: const EdgeInsets.fromLTRB(10, 8, 2, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // السطر 1: الأفاتار + الاسم + علامة التنفيذ + القائمة
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _gold.withValues(alpha: .15),
                        child: Text(
                          name.isNotEmpty ? name.characters.first : '?',
                          style: const TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name.isEmpty ? 'بدون اسم' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _primaryText(context),
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      action(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        done ? doneColor : _mutedText(context),
                        done ? 'إلغاء تنفيذ الشغل' : 'تسجيل إن الشغل اتعمل',
                        () => _toggleDone(doc, done),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'إجراءات العميل',
                        iconColor: _mutedText(context),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        color: _dialogColor(context),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _editClient(doc);
                          } else if (value == 'delete') {
                            await _deleteClient(doc.id, name);
                          } else if (value == 'done') {
                            await _toggleDone(doc, done);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(
                              'تعديل بيانات العميل',
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

                  // السطر 2: التليفون • العنوان (سطر واحد)
                  if (phone.isNotEmpty || address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Text(
                        [
                          if (phone.isNotEmpty) phone,
                          if (address.isNotEmpty) address,
                        ].join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _mutedText(context),
                          fontSize: 12,
                        ),
                      ),
                    ),

                  // السطر 3: الموعد + أزرار الاتصال والواتساب والخريطة
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _clientInfoChip(
                            icon: Icons.calendar_month_outlined,
                            label: dateLabel,
                            color: dateColor,
                          ),
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        action(
                          Icons.call_rounded,
                          doneColor,
                          'اتصال',
                          () => _call(phone),
                        ),
                        action(
                          Icons.chat_rounded,
                          const Color(0xFF25D366),
                          'واتساب',
                          () => _whatsapp(phone, name),
                        ),
                      ],
                      if (address.isNotEmpty)
                        action(
                          Icons.location_on_rounded,
                          _gold,
                          'فتح الخريطة',
                          () => _openMap(address),
                        ),
                    ],
                  ),

                  if (mCount > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8, top: 2),
                      child: Text(
                        '${_ar(mCount)} مقاس • ${meters(heavySum)} م ثقيل'
                        '${lightSum > 0 ? ' • ${meters(lightSum)} م خفيف' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8, top: 2),
                      child: Text(
                        'ملاحظات: $notes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _mutedText(context).withValues(alpha: .8),
                          fontSize: 11.5,
                        ),
                      ),
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
