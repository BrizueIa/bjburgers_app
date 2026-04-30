import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/comandas_repository.dart';

final sellableProductsProvider = StreamProvider((ref) {
  return ref.watch(comandasRepositoryProvider).watchSellableProducts();
});

final todaysOrdersProvider = StreamProvider((ref) {
  return ref.watch(comandasRepositoryProvider).watchTodayOrders();
});

final orderItemsProvider = StreamProvider.family((ref, String orderId) {
  return ref.watch(comandasRepositoryProvider).watchOrderItems(orderId);
});
