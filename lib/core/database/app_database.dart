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
  RealColumn get stockQuantity => real().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

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
  RealColumn get stockQuantity => real().nullable()();
  BoolColumn get trackStock => boolean().withDefault(const Constant(false))();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

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

class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get orderNumber => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get notes => text().nullable()();
  RealColumn get totalEstimated => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get productId => text().nullable().references(Products, #id)();
  TextColumn get productNameSnapshot => text()();
  RealColumn get unitPriceSnapshot => real()();
  RealColumn get baseCostSnapshot => real().withDefault(const Constant(0))();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get notes => text().nullable()();
  TextColumn get removedIngredientsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get saleNumber => text()();
  TextColumn get sourceOrderId => text().nullable().references(Orders, #id)();
  RealColumn get totalAmount => real()();
  RealColumn get estimatedCost => real().withDefault(const Constant(0))();
  RealColumn get estimatedProfit => real().withDefault(const Constant(0))();
  TextColumn get paymentMethod => text()();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  RealColumn get changeAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get soldAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().nullable().references(Products, #id)();
  TextColumn get productNameSnapshot => text()();
  RealColumn get unitPriceSnapshot => real()();
  RealColumn get unitCostSnapshot => real().withDefault(const Constant(0))();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  RealColumn get lineTotal => real().withDefault(const Constant(0))();
  RealColumn get lineCostTotal => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CashSessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get openedAt => dateTime()();
  RealColumn get openingAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get closedAt => dateTime().nullable()();
  RealColumn get closingExpectedCash => real().nullable()();
  RealColumn get closingRealCash => real().nullable()();
  RealColumn get transferTotal => real().withDefault(const Constant(0))();
  RealColumn get differenceAmount => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CashMovements extends Table {
  TextColumn get id => text()();
  TextColumn get cashSessionId => text().references(CashSessions, #id)();
  TextColumn get movementType => text()();
  TextColumn get paymentMethod => text().nullable()();
  RealColumn get amount => real().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  TextColumn get referenceType => text().nullable()();
  TextColumn get referenceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncQueueEntries extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operationType => text()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Ingredients,
    Products,
    ProductRecipeItems,
    IngredientPurchases,
    Orders,
    OrderItems,
    Sales,
    SaleItems,
    CashSessions,
    CashMovements,
    SyncQueueEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e) : super();

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(orders);
        await migrator.createTable(orderItems);
        await migrator.createTable(sales);
        await migrator.createTable(saleItems);
      }
      if (from < 3) {
        await migrator.createTable(cashSessions);
        await migrator.createTable(cashMovements);
      }
      if (from < 4) {
        await migrator.createTable(syncQueueEntries);
      }
      if (from < 5) {
        await migrator.addColumn(
          ingredients,
          ingredients.deletedAt as GeneratedColumn<Object>,
        );
        await migrator.addColumn(
          products,
          products.deletedAt as GeneratedColumn<Object>,
        );
      }
      if (from < 6) {
        await migrator.addColumn(
          ingredients,
          ingredients.stockQuantity as GeneratedColumn<Object>,
        );
      }
      if (from < 7) {
        await migrator.addColumn(
          products,
          products.stockQuantity as GeneratedColumn<Object>,
        );
        await migrator.addColumn(
          products,
          products.trackStock as GeneratedColumn<Object>,
        );
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'bjburguers_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
