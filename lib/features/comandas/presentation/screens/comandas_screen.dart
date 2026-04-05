import 'package:flutter/material.dart';

import '../../../../core/widgets/module_screen_template.dart';

class ComandasScreen extends StatelessWidget {
  const ComandasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScreenTemplate(
      title: 'Comandas',
      description:
          'La cola operativa permitira tomar pedidos, personalizar ingredientes y moverlos al cobro.',
      highlights: [
        'Estados de pedido: pendiente, preparando, listo y entregado.',
        'Notas operativas y modificaciones como quitar ingredientes.',
        'Acceso rapido al menu digital subido desde configuracion.',
      ],
    );
  }
}
