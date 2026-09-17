import 'package:flutter_test/flutter_test.dart';

import 'package:bj_burgers_operacion/domain/models.dart';

void main() {
  test(
    'serializa la vista previa confirmable sin campos opcionales vacíos',
    () {
      final item = DraftItem(
        productId: 'clasica',
        productName: 'Clásica',
        quantity: 2,
        removedIngredients: ['Cebolla'],
        modifierIds: ['extra-tocino'],
        combo: false,
      );
      expect(item.toJson(), {
        'productId': 'clasica',
        'quantity': 2,
        'removedIngredients': ['Cebolla'],
        'modifierIds': ['extra-tocino'],
        'combo': false,
        'note': '',
      });
    },
  );

  test('conserva el precio en centavos para el detalle operativo', () {
    final order = Order.fromJson({
      'id': '123',
      'status': 'new',
      'customerName': 'Ana',
      'neighborhood': 'Canarios',
      'streetAndNumber': 'Calle 1',
      'references': '',
      'deliveryNotes': '',
      'subtotalCents': 6900,
      'totalCents': 6900,
      'createdAt': '2026-09-16T00:00:00.000Z',
      'updatedAt': '2026-09-16T00:00:00.000Z',
      'spinCodeIssued': false,
      'items': [],
      'events': [],
    });
    expect(order.totalCents, 6900);
    expect(money(order.totalCents), '\$69');
  });
}
