import 'package:flutter/material.dart';

import '../../../../core/widgets/module_screen_template.dart';

class ComprasScreen extends StatelessWidget {
  const ComprasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScreenTemplate(
      title: 'Compras',
      description:
          'Aqui se registraran surtidos, costos unitarios y actualizaciones del ultimo precio de compra.',
      highlights: [
        'Registro de compras por fecha, cantidad y costo total.',
        'Actualizacion del costo unitario por ingrediente.',
        'Historial para recalculo de margenes.',
      ],
    );
  }
}
