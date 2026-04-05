import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Ingredients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get unitName => text().withDefault(const Constant('unidad'))();
  RealColumn get currentUnitCost => real().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get categoryName => text().nullable()();
  TextColumn get productType => text()();
  RealColumn get salePrice => real()();
  RealColumn get directCost => real().withDefault(const Constant(0))();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ProductRecipeItems extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get ingredientId => text().references(Ingredients, #id)();
  RealColumn get quantityUsed => real()();
  BoolColumn get isOptional => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class IngredientPurchases extends Table {
  TextColumn get id => text()();
  TextColumn get ingredientId => text().references(Ingredients, #id)();
  RealColumn get purchasedQuantity => real()();
  RealColumn get totalCost => real()();
  RealColumn get unitCost => real()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get purchasedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Ingredients, Products, ProductRecipeItems, IngredientPurchases],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e) : super();

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'bjburguers_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
