class PromoProductSlotConfig {
  const PromoProductSlotConfig({
    this.fixedProductName,
    this.selectableProductNames = const [],
  });

  final String? fixedProductName;
  final List<String> selectableProductNames;

  bool get needsSelection => selectableProductNames.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'fixed_product_name': fixedProductName,
      'selectable_product_names': selectableProductNames,
    };
  }

  factory PromoProductSlotConfig.fromJson(Map<String, dynamic> json) {
    return PromoProductSlotConfig(
      fixedProductName: json['fixed_product_name'] as String?,
      selectableProductNames:
          (json['selectable_product_names'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
    );
  }
}

class PromoConfig {
  const PromoConfig({
    required this.id,
    required this.title,
    required this.dayLabel,
    required this.totalPrice,
    required this.description,
    required this.slots,
  });

  final String id;
  final String title;
  final String dayLabel;
  final double totalPrice;
  final String description;
  final List<PromoProductSlotConfig> slots;

  int get count => slots.length;

  PromoConfig copyWith({
    String? id,
    String? title,
    String? dayLabel,
    double? totalPrice,
    String? description,
    List<PromoProductSlotConfig>? slots,
  }) {
    return PromoConfig(
      id: id ?? this.id,
      title: title ?? this.title,
      dayLabel: dayLabel ?? this.dayLabel,
      totalPrice: totalPrice ?? this.totalPrice,
      description: description ?? this.description,
      slots: slots ?? this.slots,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'day_label': dayLabel,
      'total_price': totalPrice,
      'description': description,
      'slots': slots.map((slot) => slot.toJson()).toList(),
    };
  }

  factory PromoConfig.fromJson(Map<String, dynamic> json) {
    return PromoConfig(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      dayLabel: json['day_label'] as String? ?? '',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      slots: (json['slots'] as List<dynamic>? ?? const [])
          .map(
            (item) => PromoProductSlotConfig.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

const defaultPromoConfigs = [
  PromoConfig(
    id: 'promo_jueves',
    title: 'Promo Jueves',
    dayLabel: 'Jueves',
    totalPrice: 100,
    description: '2 Clasicas por 100',
    slots: [
      PromoProductSlotConfig(fixedProductName: 'Clasica'),
      PromoProductSlotConfig(fixedProductName: 'Clasica'),
    ],
  ),
  PromoConfig(
    id: 'promo_viernes',
    title: 'Promo Viernes',
    dayLabel: 'Viernes',
    totalPrice: 100,
    description: '1 clasico y 1 hot dog a eleccion',
    slots: [
      PromoProductSlotConfig(fixedProductName: 'Hot Dog Clasico'),
      PromoProductSlotConfig(
        selectableProductNames: [
          'Hot Dog Clasico',
          'Salchi-Dog',
          'Hot Dog Jack Daniels',
        ],
      ),
    ],
  ),
  PromoConfig(
    id: 'promo_sabado',
    title: 'Promo Sabado',
    dayLabel: 'Sabado',
    totalPrice: 69,
    description: 'Salchiburger a precio de Clasica',
    slots: [PromoProductSlotConfig(fixedProductName: 'Salchiburger')],
  ),
  PromoConfig(
    id: 'promo_domingo',
    title: 'Promo Domingo',
    dayLabel: 'Domingo',
    totalPrice: 125,
    description: '2 Hawaianas por 125',
    slots: [
      PromoProductSlotConfig(fixedProductName: 'Hawaiana'),
      PromoProductSlotConfig(fixedProductName: 'Hawaiana'),
    ],
  ),
];
