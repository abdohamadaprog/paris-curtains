part of '../clients_list_page.dart';

const Color _gold = AppColors.primaryGold;

// مراحل الشغل: المصدر الوحيد في core/constants/work_stage.dart
const Map<int, Color> _stageColors = WorkStage.colors;
const Map<int, String> _stageLabels = WorkStage.labels;

int _stageOf(Map<String, dynamic> data) => WorkStage.fromData(data);
