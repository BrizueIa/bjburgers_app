import 'package:flutter/material.dart';

import '../../../../core/widgets/module_screen_template.dart';

class ReportesScreen extends StatelessWidget {
  const ReportesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScreenTemplate(
      title: 'Reportes',
      description:
          'La capa inicial de reportes mostrara ventas, ingresos, utilidad estimada y comportamiento de caja.',
      highlights: [
        'Filtros por fecha y resumen diario.',
        'Ventas por metodo de pago y por producto.',
        'Cortes e historial operativo para consulta.',
      ],
    );
  }
}
