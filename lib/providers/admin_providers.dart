import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/models/moderation_log.dart';
import 'package:tarnobrzeg112/models/report_model.dart';
import 'package:tarnobrzeg112/models/unit_model.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';

final unitsProvider = StreamProvider<List<UnitModel>>((ref) {
  return ref.watch(unitsRepositoryProvider).watchUnits();
});

final reportsProvider = StreamProvider<List<ReportModel>>((ref) {
  return ref.watch(moderationRepositoryProvider).watchReports();
});

final moderationLogsProvider = StreamProvider<List<ModerationLog>>((ref) {
  return ref.watch(moderationRepositoryProvider).watchLogs();
});
