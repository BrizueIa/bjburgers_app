import 'package:flutter/material.dart';

import '../../../../core/widgets/module_screen_template.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScreenTemplate(
      title: 'POS',
      description:
          'Aqui se cobraran pedidos, se calculara feria y se registraran ventas por efectivo o transferencia.',
      highlights: [
        'Cobro rapido con total, monto recibido y cambio.',
        'Entrada futura desde comandas o venta directa.',
        'Impacto automatico en caja y reportes.',
      ],
    );
  }
}
