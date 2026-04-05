import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/purchases_repository.dart';

final purchasesProvider = StreamProvider((ref) {
  return ref.watch(purchasesRepositoryProvider).watchPurchases();
});
