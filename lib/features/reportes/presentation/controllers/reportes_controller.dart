import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reportes_repository.dart';

class ReportRangeSelection {
  const ReportRangeSelection({required this.preset, required this.offset});

  final ReportRangePreset preset;
  final int offset;

  ReportRangeSelection copyWith({ReportRangePreset? preset, int? offset}) {
    return ReportRangeSelection(
      preset: preset ?? this.preset,
      offset: offset ?? this.offset,
    );
  }
}

final reportRangeProvider = StateProvider<ReportRangeSelection>((ref) {
  return const ReportRangeSelection(preset: ReportRangePreset.today, offset: 0);
});

final reportSnapshotProvider = FutureProvider((ref) {
  final selection = ref.watch(reportRangeProvider);
  final range = ReportDateRange.fromPreset(
    selection.preset,
    offset: selection.offset,
  );
  return ref.watch(reportesRepositoryProvider).fetchReport(range);
});
