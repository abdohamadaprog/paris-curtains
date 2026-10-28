part of '../clients_list_page.dart';

extension _ClientCard on _ClientsListPageState {
  Widget _clientList(List<_ClientItem> items, bool archived) {
    if (items.isEmpty) {
      final searching = _search.trim().isNotEmpty;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching
                  ? Icons.search_off_rounded
                  : archived
                  ? Icons.archive_outlined
                  : Icons.people_outline,
              color: _mutedText(context).withValues(alpha: .45),
              size: 46,
            ),
            const SizedBox(height: 10),
            Text(
              searching
                  ? 'مفيش عميل بالاسم ده'
                  : archived
                  ? 'الأرشيف فاضي'
                  : 'مفيش شغل حالي',
              style: TextStyle(color: _mutedText(context), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: items.length,
      itemExtent: 78, // ارتفاع ثابت = تمرير أسرع
      itemBuilder: (context, index) => _clientTile(items[index]),
    );
  }

  void _openClient(_ClientItem c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParisClientMeasurementsPage(
          clientId: c.doc.id,
          clientName: c.name,
          phone: c.phone.isEmpty ? null : c.phone,
          address: c.address.isEmpty ? null : c.address,
          registrationDate: c.registrationDate,
          installationDate: c.installDate,
        ),
      ),
    );
  }

  /// الدايرة الصغيرة جنب الاسم: بتعرض رقم المرحلة بلونها،
  /// واضغط عليها تختار ١ أحمر • ٢ أصفر • ٣ أزرق • ٤ أخضر.
  Widget _stageCircle(_ClientItem c, Color color) {
    return PopupMenuButton<int>(
      tooltip: 'مرحلة الشغل',
      initialValue: c.stage,
      color: _dialogColor(context),
      onSelected: (stage) => _setStage(c.doc, stage),
      itemBuilder: (_) => [
        for (final stage in const [1, 2, 3, 4])
          PopupMenuItem<int>(
            value: stage,
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _stageColors[stage],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _stageColors[stage]!.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_ar(stage)} • ${_stageLabels[stage]}',
                  style: TextStyle(
                    color: stage == c.stage
                        ? _stageColors[stage]
                        : _primaryText(context),
                    fontWeight: stage == c.stage
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
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 9),
            ],
          ),
          child: Text(
            _ar(c.stage),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  /// كارت العميل: خلفية نيون بلون المرحلة (مش صورة) + اسم العميل فقط.
  Widget _clientTile(_ClientItem c) {
    final color = _stageColors[c.stage]!;
    final dark = _isDark(context);
    final title = c.name.isEmpty ? 'بدون اسم' : c.name;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: dark ? 0.10 : 0.09),
            _surfaceColor(context),
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: dark ? 0.65 : 0.55),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: dark ? 0.30 : 0.20),
              blurRadius: 14,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openClient(c),
            child: Row(
              children: [
                const SizedBox(width: 8),
                _stageCircle(c, color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _primaryText(context),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'إجراءات العميل',
                  iconColor: _mutedText(context),
                  color: _dialogColor(context),
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        await _editClient(c.doc);
                      case 'call':
                        _call(c.phone);
                      case 'whatsapp':
                        _whatsapp(c.phone, c.name);
                      case 'map':
                        _openMap(c.address);
                      case 'delete':
                        await _deleteClient(c.doc.id, c.name);
                    }
                  },
                  itemBuilder: (_) => [
                    _menuItem(
                      'edit',
                      Icons.edit_outlined,
                      'تعديل بيانات العميل',
                    ),
                    if (c.phone.isNotEmpty)
                      _menuItem('call', Icons.call_outlined, 'اتصال'),
                    if (c.phone.isNotEmpty)
                      _menuItem('whatsapp', Icons.chat_outlined, 'واتساب'),
                    if (c.address.isNotEmpty)
                      _menuItem(
                        'map',
                        Icons.location_on_outlined,
                        'فتح الخريطة',
                      ),
                    _menuItem(
                      'delete',
                      Icons.delete_outline_rounded,
                      'حذف العميل',
                      color: Colors.redAccent,
                    ),
                  ],
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final c = color ?? _primaryText(context);
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? _mutedText(context)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: c)),
        ],
      ),
    );
  }
}
