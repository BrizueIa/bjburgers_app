import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../data/inventory_repository.dart';

final ingredientsProvider = StreamProvider<List<Ingredient>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchIngredients();
});

final productSummariesProvider = StreamProvider<List<ProductSummary>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchProductSummaries();
});

final recipeProvider = StreamProvider.family<List<RecipeLineSummary>, String>((
  ref,
  productId,
) {
  return ref.watch(inventoryRepositoryProvider).watchRecipe(productId);
});
