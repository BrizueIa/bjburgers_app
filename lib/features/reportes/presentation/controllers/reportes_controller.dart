import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reportes_repository.dart';

final reportRangeProvider = StateProvider<ReportRangePreset>((ref) {
  return ReportRangePreset.today;
});

final reportSnapshotProvider = FutureProvider((ref) {
  final preset = ref.watch(reportRangeProvider);
  final range = ReportDateRange.fromPreset(preset);
  return ref.watch(reportesRepositoryProvider).fetchReport(range);
});
