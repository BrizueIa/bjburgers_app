class Product {
  const Product({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.available,
    required this.comboEligible,
    required this.removableIngredients,
  });

  final String id;
  final String name;
  final int priceCents;
  final bool available;
  final bool comboEligible;
  final List<String> removableIngredients;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    priceCents: json['priceCents'] as int,
    available: json['available'] as bool,
    comboEligible: json['comboEligible'] as bool,
    removableIngredients: List<String>.from(
      json['removableIngredients'] as List<dynamic>,
    ),
  );
}

class Modifier {
  const Modifier({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.available,
  });
  final String id;
  final String name;
  final int priceCents;
  final bool available;
  factory Modifier.fromJson(Map<String, dynamic> json) => Modifier(
    id: json['id'] as String,
    name: json['name'] as String,
    priceCents: json['priceCents'] as int,
    available: json['available'] as bool,
  );
}

class CatalogData {
  const CatalogData({required this.products, required this.modifiers});
  final List<Product> products;
  final List<Modifier> modifiers;
  factory CatalogData.fromJson(Map<String, dynamic> json) => CatalogData(
    products: (json['products'] as List<dynamic>)
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList(),
    modifiers: (json['modifiers'] as List<dynamic>)
        .map((item) => Modifier.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class DraftItem {
  DraftItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.removedIngredients = const [],
    this.modifierIds = const [],
    this.combo = false,
    this.drinkProductId,
    this.note = '',
  });
  String productId;
  String productName;
  int quantity;
  List<String> removedIngredients;
  List<String> modifierIds;
  bool combo;
  String? drinkProductId;
  String note;

  factory DraftItem.fromJson(Map<String, dynamic> json) => DraftItem(
    productId: json['productId'] as String,
    productName: json['productName'] as String,
    quantity: json['quantity'] as int,
    removedIngredients: List<String>.from(
      json['removedIngredients'] as List<dynamic>,
    ),
    modifierIds: List<String>.from(json['modifierIds'] as List<dynamic>),
    combo: json['combo'] as bool,
    drinkProductId: json['drinkProductId'] as String?,
    note: json['note'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'removedIngredients': removedIngredients,
    'modifierIds': modifierIds,
    'combo': combo,
    if (drinkProductId != null) 'drinkProductId': drinkProductId,
    'note': note,
  };
}

class OrderDraft {
  OrderDraft({
    required this.rawMessage,
    required this.customerName,
    required this.neighborhood,
    required this.streetAndNumber,
    required this.references,
    required this.deliveryNotes,
    required this.items,
    required this.unresolvedLines,
  });
  String rawMessage;
  String customerName;
  String neighborhood;
  String streetAndNumber;
  String references;
  String deliveryNotes;
  List<DraftItem> items;
  List<String> unresolvedLines;

  factory OrderDraft.empty() => OrderDraft(
    rawMessage: '',
    customerName: '',
    neighborhood: '',
    streetAndNumber: '',
    references: '',
    deliveryNotes: '',
    items: [],
    unresolvedLines: [],
  );
  factory OrderDraft.fromJson(Map<String, dynamic> json) => OrderDraft(
    rawMessage: json['rawMessage'] as String,
    customerName: json['customerName'] as String,
    neighborhood: json['neighborhood'] as String,
    streetAndNumber: json['streetAndNumber'] as String,
    references: json['references'] as String,
    deliveryNotes: json['deliveryNotes'] as String,
    items: (json['items'] as List<dynamic>)
        .map((item) => DraftItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    unresolvedLines: List<String>.from(
      json['unresolvedLines'] as List<dynamic>,
    ),
  );
}

class OrderEvent {
  const OrderEvent({
    required this.type,
    this.status,
    required this.note,
    required this.createdAt,
  });
  final String type;
  final String? status;
  final String note;
  final DateTime createdAt;
  factory OrderEvent.fromJson(Map<String, dynamic> json) => OrderEvent(
    type: json['type'] as String,
    status: json['status'] as String?,
    note: json['note'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class OrderItem {
  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.removedIngredients,
    required this.modifiers,
    this.combo,
    required this.note,
    required this.lineTotalCents,
  });
  final String productName;
  final int quantity;
  final List<String> removedIngredients;
  final List<dynamic> modifiers;
  final Map<String, dynamic>? combo;
  final String note;
  final int lineTotalCents;
  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    productName: json['productName'] as String,
    quantity: json['quantity'] as int,
    removedIngredients: List<String>.from(
      json['removedIngredients'] as List<dynamic>,
    ),
    modifiers: List<dynamic>.from(json['modifiers'] as List<dynamic>),
    combo: json['combo'] as Map<String, dynamic>?,
    note: json['note'] as String,
    lineTotalCents: json['lineTotalCents'] as int,
  );
}

class Order {
  const Order({
    required this.id,
    required this.status,
    required this.customerName,
    required this.neighborhood,
    required this.streetAndNumber,
    required this.references,
    required this.deliveryNotes,
    required this.totalCents,
    required this.subtotalCents,
    required this.createdAt,
    required this.updatedAt,
    required this.spinCodeIssued,
    required this.items,
    required this.events,
  });
  final String id;
  final String status;
  final String customerName;
  final String neighborhood;
  final String streetAndNumber;
  final String references;
  final String deliveryNotes;
  final int totalCents;
  final int subtotalCents;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool spinCodeIssued;
  final List<OrderItem> items;
  final List<OrderEvent> events;
  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    status: json['status'] as String,
    customerName: json['customerName'] as String,
    neighborhood: json['neighborhood'] as String,
    streetAndNumber: json['streetAndNumber'] as String,
    references: json['references'] as String,
    deliveryNotes: json['deliveryNotes'] as String,
    subtotalCents: json['subtotalCents'] as int,
    totalCents: json['totalCents'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    spinCodeIssued: json['spinCodeIssued'] as bool,
    items: (json['items'] as List<dynamic>)
        .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    events: (json['events'] as List<dynamic>)
        .map((item) => OrderEvent.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

String money(int cents) => '\$${(cents / 100).toStringAsFixed(0)}';
