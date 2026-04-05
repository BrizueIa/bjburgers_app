import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pos_repository.dart';

final readyOrdersProvider = StreamProvider((ref) {
  return ref.watch(posRepositoryProvider).watchReadyOrders();
});

final posOrderItemsProvider = StreamProvider.family((ref, String orderId) {
  return ref.watch(posRepositoryProvider).watchOrderItems(orderId);
});

final salesHistoryProvider = StreamProvider((ref) {
  return ref.watch(posRepositoryProvider).watchSales();
});
