import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/caja_repository.dart';

final activeCashSessionProvider = StreamProvider((ref) {
  return ref.watch(cajaRepositoryProvider).watchActiveSession();
});

final cashSessionsProvider = StreamProvider((ref) {
  return ref.watch(cajaRepositoryProvider).watchSessions();
});

final cashMovementsProvider = StreamProvider.family((ref, String sessionId) {
  return ref.watch(cajaRepositoryProvider).watchMovements(sessionId);
});
