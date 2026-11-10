part of 'paris_client_measurements_page.dart';

extension _MeasurementData on _ParisClientMeasurementsPageState {
  // ============================================================================
  // آلية الحفظ التلقائي الذكي (Auto-Save)
  // ============================================================================
  void _triggerAutoSave() {
    if (!_loaded || _loadFailed) return;
    _userEdited = true;
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
  // تحميل البيانات: الكاش المحلي الأول (فوري) وبعدها تحديث هادي من السيرفر
  // ============================================================================
  Future<void> _loadSavedData() async {
    _loadFailed = false;

    final cached = await ClientDetailsRepository.loadCached(widget.clientId);
    if (!mounted) return;
    if (cached != null) _applyDetails(cached);

    try {
      final fresh = await ClientDetailsRepository.loadServer(widget.clientId);
      if (!mounted) return;
      if (!_loaded) {
        _applyDetails(fresh);
      } else if (fresh.signature != _loadedSignature &&
          !_userEdited) {
        // السيرفر عنده نسخة أحدث ومفيش تعديل شغال دلوقتي
        _applyDetails(fresh);
      }
    } catch (e) {
      debugPrint('Failed to load client data: $e');
      if (!mounted) return;
      if (!_loaded) _rebuild(() => _loadFailed = true);
    }
  }

  void _applyDetails(ClientDetails d) {
    final loadedMeasurements = <_Measurement>[];
    final loadedBalconies = <_Balcony>[];
    final loadedTrash = <_DeletedCard>[];

    for (final raw in d.measurements) {
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
      // استثناءات القماش (اختيارية — القيم الغايبة = الافتراضي)
      m.heavyEnabled = raw['heavy_enabled'] != false;
      m.heavyWidthOverride = (raw['heavy_width'] as num?)?.toDouble();
      m.heavyRatioOverride = (raw['heavy_ratio'] as num?)?.toDouble();
      m.lightWidthOverride = (raw['light_width'] as num?)?.toDouble();
      m.lightRatioOverride = (raw['light_ratio'] as num?)?.toDouble();
      m.blackoutEnabled = raw['blackout_enabled'] == true;
      m.blackoutType = (raw['blackout_type'] ?? 'fabric_blackout3d').toString();
      m.blackoutWidthOverride = (raw['blackout_width'] as num?)?.toDouble();
      m.blackoutRatioOverride = (raw['blackout_ratio'] as num?)?.toDouble();
      loadedMeasurements.add(m);
    }

    for (final raw in d.deletedCards) {
      loadedTrash.add(_DeletedCard.fromMap(raw));
    }

    for (final raw in d.balconies) {
      final b = _Balcony();
      b.name.text = (raw['name'] ?? '').toString();
      b.parts.text = (raw['parts'] ?? '').toString();
      b.syncSidesFromParts();
      final h = raw['height'];
      if (h != null && h.toString().trim().isNotEmpty) {
        b.height.text = h.toString();
      }
      b.customAvez = (raw['custom_avez'] as num?)?.toInt();
      b.enabled = raw['enabled'] != false;
      loadedBalconies.add(b);
    }

    final oldMeasurements = [..._measurements];
    final oldBalconies = [..._balconies];

    _loadedSignature = d.signature;
    _rebuild(() {
      if (loadedMeasurements.isNotEmpty) {
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
      _loaded = true;
      _loadFailed = false;
    });

    // نتخلص من الكنترولرز القديمة بعد ما الشاشة تتبني بالجديدة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (loadedMeasurements.isNotEmpty) {
        for (final m in oldMeasurements) {
          m.dispose();
        }
      }
      for (final b in oldBalconies) {
        b.dispose();
      }
    });
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
          'title': m.name.text.trim(),
          'width': _Measurement.toDouble(m.width.text),
          'height': _Measurement.toDouble(m.height.text),
          'method': m.method.name,
          'ceiling': m.ceiling.name,
          'velvet_sides': m.velvetSides,
          'light_layers': m.lightLayers,
          'light_sides': m.lightSides,
          'wheels': m.wheels.text.trim(),
          // استثناءات القماش: بتتحفظ بس لو موجودة (null = القاعدة الافتراضية)
          'heavy_enabled': m.heavyEnabled,
          'heavy_width': m.heavyWidthOverride,
          'heavy_ratio': m.heavyRatioOverride,
          'light_width': m.lightWidthOverride,
          'light_ratio': m.lightRatioOverride,
          'blackout_enabled': m.blackoutEnabled,
          'blackout_type': m.blackoutType,
          'blackout_width': m.blackoutWidthOverride,
          'blackout_ratio': m.blackoutRatioOverride,
          'heavy_meters': c.heavyMeters,
          'light_meters': c.lightMeters,
          'blackout_meters': c.blackoutMeters,
          'heavy_height': c.heavyHeight,
          'light_height': c.lightHeight,
          'blackout_height': c.blackoutHeight,
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
              'title': b.name.text.trim(),
              'parts': b.parts.text.trim(),
              'total_width': b.totalWidth,
              'height': _Measurement.toDouble(b.height.text),
              'custom_avez': b.customAvez,
              'avezCount': b.customAvez ?? 0,
              'enabled': b.enabled,
            },
          )
          .toList();

      final trash = _trash.map((t) => t.toMap()).toList();

      final outcome = await ClientDetailsRepository.save(
        clientId: widget.clientId,
        clientFields: {
          'name': _nameController.text.trim(),
          'installation_date': _installationDate == null
              ? null
              : Timestamp.fromDate(_installationDate!),
        },
        details: ClientDetails(
          measurements: measurements,
          balconies: balconies,
          deletedCards: trash,
        ),
      );

      if (!mounted) return;
      _rebuild(() {
        _isAutoSaving = false;
        _savedSuccess = true;
        _savedLocalOnly = outcome == WriteOutcome.queued;
      });

      if (!isAuto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome == WriteOutcome.queued
                  ? 'اتحفظ على الجهاز، وهيترفع لما النت يرجع ✨'
                  : 'تم حفظ مقاسات العميل بنجاح ✨',
            ),
            backgroundColor: const Color(0xFF1E7E34),
            duration: const Duration(seconds: 2),
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
  // الإضافة السريعة: المقاس الجديد بياخد نفس نوع الستارة والارتفاع بتوع آخر مقاس
  // (غالبًا الشبابيك في نفس الشقة شبه بعض)، وبعدها بيفتح للتعديل على طول.
  _Measurement _buildMeasurement({_Measurement? like}) {
    final last = like ?? (_measurements.isEmpty ? null : _measurements.last);
    final item = _Measurement();
    item.name.text = 'شباك ${_toArabic(_measurements.length + 1)}';
    item.width.text = '3.00';
    item.height.text = (last != null && last.height.text.trim().isNotEmpty)
        ? last.height.text
        : '2.95';
    if (last != null) {
      item.method = last.method;
      item.ceiling = last.ceiling;
      item.velvetSides = last.velvetSides;
      item.lightLayers = last.lightLayers;
      item.lightSides = last.lightSides;
    }
    return item;
  }

  void _addMeasurement() {
    final item = _buildMeasurement();
    _rebuild(() => _measurements.add(item));
    _triggerAutoSave();
    _scrollToEnd(_aptScroll);
    _openCard(item);
  }

  // بتتنادى من المحرر: تضيف مقاس جديد بنفس إعدادات الحالي وتفضل جوه المحرر.
  _Measurement _appendMeasurementLike(_Measurement like) {
    final item = _buildMeasurement(like: like);
    _rebuild(() => _measurements.add(item));
    _triggerAutoSave();
    _scrollToEnd(_aptScroll);
    return item;
  }

  // البلكونة الجديدة بتفتح مفتوحة، وباقي البلكونات بتتطوي عشان المساحة
  void _addBalcony() {
    final last = _balconies.isEmpty ? null : _balconies.last;
    final b = _Balcony();
    b.name.text = 'بلكونة ${_toArabic(_balconies.length + 1)}';
    if (last != null && last.height.text.trim().isNotEmpty) {
      b.height.text = last.height.text;
    }
    _rebuild(() {
      for (final other in _balconies) {
        other.isExpanded = false;
      }
      b.isExpanded = true;
      _balconies.add(b);
    });
    _triggerAutoSave();
    _scrollToEnd(_balcScroll);
    _openBalconyEditor(b);
  }

  void _scrollToEnd(ScrollController c) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !c.hasClients) return;
      c.animateTo(
        c.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
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
      // التكرار بينسخ الاستثناءات كمان (نسخة مطابقة للمقاس الأصلي)
      copy.heavyEnabled = item.heavyEnabled;
      copy.heavyWidthOverride = item.heavyWidthOverride;
      copy.heavyRatioOverride = item.heavyRatioOverride;
      copy.lightWidthOverride = item.lightWidthOverride;
      copy.lightRatioOverride = item.lightRatioOverride;
      copy.blackoutEnabled = item.blackoutEnabled;
      copy.blackoutType = item.blackoutType;
      copy.blackoutWidthOverride = item.blackoutWidthOverride;
      copy.blackoutRatioOverride = item.blackoutRatioOverride;
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
      copy.syncSidesFromParts();
      copy.height.text = item.height.text;
      copy.customAvez = item.customAvez;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم نقل البلكونة إلى المحذوفات'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () {
            if (_trash.isNotEmpty && _trash.first.isBalcony) {
              _rebuild(() {
                final restored = _trash.removeAt(0);
                _balconies.insert(
                  index.clamp(0, _balconies.length).toInt(),
                  restored.toBalcony(),
                );
              });
              _triggerAutoSave();
            }
          },
        ),
      ),
    );
  }

  // ==========================================================================
  // قوالب المقاسات (بتتحفظ على الجهاز)
  // ==========================================================================
  Future<void> _saveAsTemplate(_Measurement item) async {
    final c = TextEditingController(text: item.name.text.trim());
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _panel,
          title: Text('حفظ كقالب', style: TextStyle(color: AppPalette.text)),
          content: TextField(
            controller: c,
            autofocus: true,
            style: TextStyle(color: AppPalette.text),
            decoration: const InputDecoration(hintText: 'اسم القالب (مثال: شباك صالون)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('إلغاء', style: TextStyle(color: _muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
              child: Text('حفظ', style: TextStyle(color: _gold)),
            ),
          ],
        ),
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final list = await _TemplateStore.load();
    list.removeWhere((t) => t.name == name);
    list.insert(0, _MeasurementTemplate.fromItem(item, name));
    await _TemplateStore.save(list);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ القالب "$name"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addFromTemplate(_MeasurementTemplate t) {
    final item = _Measurement();
    t.applyTo(item);
    _rebuild(() => _measurements.add(item));
    _triggerAutoSave();
    _scrollToEnd(_aptScroll);
    _openCard(item);
  }

  Future<void> _pickTemplate() async {
    final list = await _TemplateStore.load();
    if (!mounted) return;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مفيش قوالب لسه. افتح أي مقاس واضغط "حفظ كقالب".'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    'إضافة من قالب',
                    style: TextStyle(
                      color: AppPalette.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final t in List<_MeasurementTemplate>.of(list))
                        ListTile(
                          title: Text(
                            t.name,
                            style: TextStyle(
                              color: AppPalette.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${_toArabic(_Measurement.toDouble(t.width).toStringAsFixed(2))} × '
                            '${_toArabic(_Measurement.toDouble(t.height).toStringAsFixed(2))} م • '
                            '${t.method.label} • ${t.ceiling.label}',
                            style: TextStyle(color: _muted, fontSize: 12.5),
                          ),
                          trailing: IconButton(
                            tooltip: 'حذف القالب',
                            icon: Icon(
                              Icons.delete_outline,
                              color: AppPalette.redStrong,
                            ),
                            onPressed: () async {
                              list.remove(t);
                              await _TemplateStore.save(list);
                              setSheet(() {});
                              if (list.isEmpty && ctx.mounted) {
                                Navigator.of(ctx).pop();
                              }
                            },
                          ),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _addFromTemplate(t);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
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
          colorScheme: AppPalette.isDark
              ? ColorScheme.dark(primary: _gold, surface: _panel)
              : ColorScheme.light(primary: _gold, surface: _panel),
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
