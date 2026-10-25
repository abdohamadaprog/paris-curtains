part of '../clients_list_page.dart';

extension _ClientDialog on _ClientsListPageState {
  Future<void> _addClient() => _clientDialog();

  Future<void> _editClient(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _clientDialog(doc: doc);

  /// نافذة موحّدة لإضافة عميل جديد أو تعديل بياناته (بما فيها العملاء القدام).
  Future<void> _clientDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final isEdit = doc != null;
    final data = doc?.data() ?? <String, dynamic>{};
    final nameController = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );
    final phoneController = TextEditingController(
      text: (data['phone'] ?? '').toString(),
    );
    final addressController = TextEditingController(
      text: (data['address'] ?? '').toString(),
    );
    final notesController = TextEditingController(
      text: (data['notes'] ?? '').toString(),
    );
    DateTime? installationDate = _dateFrom(data['installation_date']);
    DateTime? registrationDate = _dateFrom(data['created_at']);
    final wasDone = data['installation_done'] == true;
    var done = wasDone;
    var doneTouched = false;
    final formKey = GlobalKey<FormState>();
    final fmt = DateFormat('yyyy-MM-dd');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Future<DateTime?> pick(BuildContext ctx, DateTime? initial) =>
        showDatePicker(
          context: ctx,
          initialDate: initial ?? DateTime.now(),
          firstDate: DateTime(2015),
          lastDate: DateTime(2100),
        );

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _dialogColor(context),
          title: Text(
            isEdit ? 'تعديل بيانات العميل' : 'عميل جديد',
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
                    autofocus: !isEdit,
                    textInputAction: TextInputAction.next,
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
                    textInputAction: TextInputAction.next,
                    style: TextStyle(color: _primaryText(context)),
                    decoration: _inputDecoration('رقم الهاتف'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.event_note_outlined,
                      color: _gold,
                    ),
                    title: Text(
                      'تاريخ التسجيل',
                      style: TextStyle(color: _primaryText(context)),
                    ),
                    subtitle: Text(
                      registrationDate == null
                          ? 'النهارده (تلقائي)'
                          : fmt.format(registrationDate!),
                      style: const TextStyle(color: _gold),
                    ),
                    trailing: (!isEdit && registrationDate != null)
                        ? IconButton(
                            tooltip: 'رجوع للتاريخ التلقائي',
                            icon: const Icon(Icons.clear, color: _gold),
                            onPressed: () =>
                                setDialogState(() => registrationDate = null),
                          )
                        : null,
                    onTap: () async {
                      final picked = await pick(context, registrationDate);
                      if (picked != null) {
                        setDialogState(() => registrationDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month, color: _gold),
                    title: Text(
                      'تاريخ التركيب',
                      style: TextStyle(color: _primaryText(context)),
                    ),
                    subtitle: Text(
                      installationDate == null
                          ? 'غير محدد'
                          : fmt.format(installationDate!),
                      style: const TextStyle(color: _gold),
                    ),
                    trailing: installationDate == null
                        ? null
                        : IconButton(
                            tooltip: 'مسح التاريخ',
                            icon: const Icon(Icons.clear, color: _gold),
                            onPressed: () =>
                                setDialogState(() => installationDate = null),
                          ),
                    onTap: () async {
                      final picked = await pick(context, installationDate);
                      if (picked != null) {
                        setDialogState(() {
                          installationDate = picked;
                          // عميل قديم تاريخه فات: نعتبره اتركّب إلا لو غيّرت بإيدك
                          if (!doneTouched) {
                            done = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                            ).isBefore(today);
                          }
                        });
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: _gold,
                    title: Text(
                      'تم التركيب',
                      style: TextStyle(color: _primaryText(context)),
                    ),
                    subtitle: Text(
                      'للعملاء اللي اتركّب لهم قبل كده',
                      style: TextStyle(
                        color: _mutedText(context),
                        fontSize: 11.5,
                      ),
                    ),
                    value: done,
                    onChanged: (v) => setDialogState(() {
                      done = v;
                      doneTouched = true;
                    }),
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
              child: Text(isEdit ? 'حفظ التعديل' : 'حفظ'),
            ),
          ],
        ),
      ),
    );

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();
    final notes = notesController.text.trim();
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    notesController.dispose();
    if (save != true || !mounted) return;

    // تنبيه لو الرقم مسجّل لعميل تاني
    final owner = phone.isEmpty
        ? null
        : _duplicatePhoneOwner(phone, excludeId: doc?.id);
    if (owner != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _dialogColor(ctx),
          title: Text(
            'الرقم متسجّل قبل كده',
            style: TextStyle(color: _primaryText(ctx)),
          ),
          content: Text(
            'الرقم ده مسجّل باسم "$owner". تكمّل الحفظ؟',
            style: TextStyle(color: _primaryText(ctx)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لا'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('كمّل'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    try {
      final fields = <String, dynamic>{
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
        'installation_date': installationDate == null
            ? null
            : Timestamp.fromDate(installationDate!),
      };
      if (!isEdit || done != wasDone) {
        fields['installation_done'] = done;
        fields['installation_done_at'] = done
            ? (installationDate != null
                  ? Timestamp.fromDate(installationDate!)
                  : FieldValue.serverTimestamp())
            : null;
      }
      if (isEdit) {
        if (registrationDate != null) {
          fields['created_at'] = Timestamp.fromDate(registrationDate!);
        }
        await doc.reference.update(fields);
        if (mounted) _message('تم تعديل بيانات العميل');
      } else {
        fields['created_at'] = registrationDate == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(registrationDate!);
        await FirebaseFirestore.instance.collection('clients').add(fields);
        if (mounted) _message('تم إضافة العميل بنجاح');
      }
    } catch (e) {
      if (mounted) _message('تعذر حفظ العميل: $e');
    }
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
}
