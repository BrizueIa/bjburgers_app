import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dashboard_repository.dart';

final dashboardSnapshotProvider = StreamProvider((ref) {
  return ref.watch(dashboardRepositoryProvider).watchSnapshot();
});
