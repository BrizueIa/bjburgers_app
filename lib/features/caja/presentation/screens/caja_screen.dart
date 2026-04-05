import 'package:flutter/material.dart';

import '../../../../core/widgets/module_screen_template.dart';

class CajaScreen extends StatelessWidget {
  const CajaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScreenTemplate(
      title: 'Caja',
      description:
          'La caja separara efectivo y transferencia, registrara aperturas, movimientos y cortes.',
      highlights: [
        'Una sola sesion activa a la vez.',
        'Cortes con diferencia entre esperado y real.',
        'Restricciones por modo admin para movimientos sensibles.',
      ],
    );
  }
}
