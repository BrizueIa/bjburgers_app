import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/admin/admin_mode_controller.dart';
import '../../../../core/storage/app_settings_controller.dart';
import '../../../../core/sync/sync_status_controller.dart';
import '../../../../core/widgets/module_screen_template.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(adminModeProvider);
    final settings = ref.watch(appSettingsProvider);
    final sync = ref.watch(syncStatusProvider);

    return ModuleScreenTemplate(
      title: settings.businessName,
      description:
          'Base operativa de la app lista para crecer: navegacion adaptativa, modo admin, configuracion local y cimientos para sincronizacion offline-first.',
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          Chip(
            avatar: Icon(
              admin.enabled
                  ? Icons.lock_open_rounded
                  : Icons.lock_outline_rounded,
              size: 18,
            ),
            label: Text(admin.enabled ? 'Admin activo' : 'Admin apagado'),
          ),
          Chip(
            avatar: Icon(
              sync.isOnline
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              size: 18,
            ),
            label: Text(sync.statusLabel),
          ),
        ],
      ),
      highlights: const [
        'Dashboard con shell responsivo para movil y desktop.',
        'Router base con modulos: POS, Comandas, Inventario, Compras, Caja, Reportes y Settings.',
        'Persistencia inicial de nombre del negocio, PIN admin y URL del menu digital.',
        'Control operativo con modo admin global listo para crecer a sincronizacion real.',
        'Estado de conectividad y disparador manual para sincronizacion base.',
        'Documento maestro de implementacion agregado al proyecto.',
      ],
    );
  }
}
