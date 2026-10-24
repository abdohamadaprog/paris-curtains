part of '../paris_client_measurements_page.dart';

extension _MeasurementData on _ParisClientMeasurementsPageState {
  // ============================================================================
  // آلية الحفظ التلقائي الذكي (Auto-Save)
  // ============================================================================
  void _triggerAutoSave() {
    if (!_loaded || _loadFailed) return;
    _rebuild(() {
      _isAutoSaving = true;
      _savedSuccess = false;
    });
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 650), () {
      _performSave(isAuto: true);
    });
  }

  // ============================================================================
  // تحميل البيانات من Firestore
  // ============================================================================
  Future<void> _loadSavedData() async {
    _loadFailed = false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();

      if (!mounted) return;
      if (!doc.exists) {
        _rebuild(() => _loaded = true);
        return;
      }

      final data = doc.data() ?? <String, dynamic>{};
      final loadedMeasurements = <_Measurement>[];
      final loadedBalconies = <_Balcony>[];
      final loadedTrash = <_DeletedCard>[];

      for (final raw in (data['measurements'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final m = _Measurement();
        m.name.text = (raw['name'] ?? '').toString();
        m.width.text = (raw['width'] ?? '').toString();
        m.height.text = (raw['height'] ?? '').toString();
        m.method = _WorkMethod.values.firstWhere(
          (v) => v.name == raw['method'],
          orElse: () => _WorkMethod.wave,
        );
        m.ceiling = _CeilingType.values.firstWhere(
          (v) => v.name == raw['ceiling'],
          orElse: () => _CeilingType.kaboli,
        );
        m.velvetSides = (raw['velvet_sides'] as num?)?.toInt() ?? 2;
        m.lightLayers = (raw['light_layers'] as num?)?.toInt() ?? 1;
        m.lightSides = (raw['light_sides'] as num?)?.toInt() ?? 2;
        m.wheels.text = (raw['wheels'] ?? '').toString();
        m.enabled = raw['enabled'] != false;
        loadedMeasurements.add(m);
      }

      for (final raw in (data['deleted_cards'] as List? ?? const [])) {
        if (raw is Map) {
          loadedTrash.add(_DeletedCard.fromMap(Map<String, dynamic>.from(raw)));
        }
      }

      for (final raw in (data['balconies'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final b = _Balcony();
        b.name.text = (raw['name'] ?? '').toString();
        b.parts.text = (raw['parts'] ?? '').toString();
        b.enabled = raw['enabled'] != false;
        loadedBalconies.add(b);
      }

      if (!mounted) {
        for (final m in loadedMeasurements) {
          m.dispose();
        }
        for (final b in loadedBalconies) {
          b.dispose();
        }
        return;
      }

      _rebuild(() {
        if (loadedMeasurements.isNotEmpty) {
          for (final m in _measurements) {
            m.dispose();
          }
          _measurements
            ..clear()
            ..addAll(loadedMeasurements);
        }
        _balconies
          ..clear()
          ..addAll(loadedBalconies);
        _trash
          ..clear()
          ..addAll(loadedTrash);
        _nameController.text = (data['name'] ?? widget.clientName).toString();
        final date = data['installation_date'];
        if (date is Timestamp) _installationDate = date.toDate();
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Failed to load client data: $e');
      if (!mounted) return;
      _loadFailed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تعذر تحميل بيانات العميل. تأكد من الاتصال.'),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            onPressed: _loadSavedData,
          ),
        ),
      );
    }
  }

  // ============================================================================
  // حفظ البيانات في Firestore (تلقائي أو يدوي)
  // ============================================================================
  Future<void> _performSave({bool isAuto = false}) async {
    if (_saving) return;
    if (!_loaded) return;

    if (!isAuto) _rebuild(() => _saving = true);

    try {
      final measurements = _measurements.map((m) {
        final c = m.calculation;
        return <String, dynamic>{
          'id': m.id,
          'type': 'measurement',
          'name': m.name.text.trim(),
          'width': _Measurement.toDouble(m.width.text),
          'height': _Measurement.toDouble(m.height.text),
          'method': m.method.name,
          'ceiling': m.ceiling.name,
          'velvet_sides': m.velvetSides,
          'light_layers': m.lightLayers,
          'light_sides': m.lightSides,
          'wheels': m.wheels.text.trim(),
          'heavy_meters': c.heavyMeters,
          'light_meters': c.lightMeters,
          'heavy_height': c.heavyHeight,
          'light_height': c.lightHeight,
          'heavy_wheels': c.heavyWheels,
          'light_wheels': c.lightWheels,
          'heavy_tape_meters': c.heavyTapeMeters,
          'light_tape_meters': c.lightTapeMeters,
          'enabled': m.enabled,
        };
      }).toList();

      final balconies = _balconies
          .map(
            (b) => <String, dynamic>{
              'id': b.id,
              'name': b.name.text.trim(),
              'parts': b.parts.text.trim(),
              'total_width': b.totalWidth,
              'enabled': b.enabled,
            },
          )
          .toList();

      final trash = _trash.map((t) => t.toMap()).toList();

      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .set({
            'name': _nameController.text.trim(),
            'installation_date': _installationDate == null
                ? null
                : Timestamp.fromDate(_installationDate!),
            'measurements': measurements,
            'balconies': balconies,
            'deleted_cards': trash,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      _rebuild(() {
        _isAutoSaving = false;
        _savedSuccess = true;
      });

      if (!isAuto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ مقاسات العميل بنجاح ✨'),
            backgroundColor: Color(0xFF1E7E34),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to save data: $e');
      if (mounted) {
        _rebuild(() {
          _isAutoSaving = false;
          _savedSuccess = false;
        });
      }
    } finally {
      if (mounted && !isAuto) _rebuild(() => _saving = false);
    }
  }

  // ============================================================================
  // إضافة وتكرار وحذف الكروت
  // ============================================================================
  void _addMeasurement() {
    _rebuild(() {
      final item = _Measurement();
      item.name.text = 'شباك ${_toArabic(_measurements.length + 1)}';
      item.width.text = '3.00';
      item.height.text = '2.95';
      _measurements.add(item);
    });
    _triggerAutoSave();
  }

  void _addBalcony() {
    _rebuild(() {
      final b = _Balcony();
      b.name.text = 'بلكونة ${_toArabic(_balconies.length + 1)}';
      _balconies.add(b);
    });
    _triggerAutoSave();
  }

  void _duplicateMeasurement(_Measurement item) {
    _rebuild(() {
      final copy = _Measurement();
      copy.name.text = '${item.name.text} (نسخة)';
      copy.width.text = item.width.text;
      copy.height.text = item.height.text;
      copy.method = item.method;
      copy.ceiling = item.ceiling;
      copy.velvetSides = item.velvetSides;
      copy.lightLayers = item.lightLayers;
      copy.lightSides = item.lightSides;
      copy.wheels.text = item.wheels.text;
      copy.enabled = item.enabled;
      _measurements.add(copy);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تكرار المقاس'),
        duration: Duration(seconds: 1),
      ),
    );
    _triggerAutoSave();
  }

  void _duplicateBalcony(_Balcony item) {
    _rebuild(() {
      final copy = _Balcony();
      copy.name.text = '${item.name.text} (نسخة)';
      copy.parts.text = item.parts.text;
      copy.enabled = item.enabled;
      _balconies.add(copy);
    });
    _triggerAutoSave();
  }

  void _deleteMeasurement(int index) {
    _rebuild(() {
      final item = _measurements.removeAt(index);
      _trash.insert(0, _DeletedCard.measurement(item));
    });
    _triggerAutoSave();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم نقل المقاس إلى المحذوفات'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () {
            if (_trash.isNotEmpty) {
              _rebuild(() {
                final restored = _trash.removeAt(0);
                _measurements.insert(index, restored.toMeasurement());
              });
              _triggerAutoSave();
            }
          },
        ),
      ),
    );
  }

  void _deleteBalcony(int index) {
    _rebuild(() {
      final item = _balconies.removeAt(index);
      _trash.insert(0, _DeletedCard.balcony(item));
    });
    _triggerAutoSave();
  }

  Future<void> _pickInstallationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _installationDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: _gold, surface: _panel),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _rebuild(() => _installationDate = picked);
      _triggerAutoSave();
    }
  }
}
