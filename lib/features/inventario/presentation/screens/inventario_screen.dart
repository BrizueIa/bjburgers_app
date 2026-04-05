import 'package:flutter/material.dart';

import '../../../../core/widgets/module_screen_template.dart';

class InventarioScreen extends StatelessWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScreenTemplate(
      title: 'Inventario',
      description:
          'Este modulo concentrara ingredientes, productos simples, productos compuestos y recetas por ingrediente.',
      highlights: [
        'CRUD de ingredientes e insumos.',
        'Productos simples con costo directo y productos compuestos con receta.',
        'Calculo futuro de costo actual y margen segun ultimo precio de compra.',
      ],
    );
  }
}
