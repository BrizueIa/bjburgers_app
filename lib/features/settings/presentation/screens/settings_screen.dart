import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/admin/admin_mode_controller.dart';
import '../../../../core/storage/app_settings_controller.dart';
import '../../../../core/sync/sync_status_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _menuController;
  late final TextEditingController _pinController;
  late final TextEditingController _unlockController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    final admin = ref.read(adminModeProvider);
    _nameController = TextEditingController(text: settings.businessName);
    _menuController = TextEditingController(text: settings.digitalMenuUrl);
    _pinController = TextEditingController(text: admin.pin);
    _unlockController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _menuController.dispose();
    _pinController.dispose();
    _unlockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final admin = ref.watch(adminModeProvider);
    final sync = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          _SectionCard(
            title: 'Negocio',
            subtitle: 'Datos operativos visibles en toda la app.',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del negocio',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _menuController,
                  decoration: const InputDecoration(
                    labelText: 'URL o referencia del menu digital',
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ref
                          .read(appSettingsProvider.notifier)
                          .updateBusinessName(_nameController.text.trim());
                      await ref
                          .read(appSettingsProvider.notifier)
                          .updateDigitalMenuUrl(_menuController.text.trim());
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Configuracion guardada.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Guardar cambios'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Modo admin',
            subtitle:
                'Controla cambios de precios, caja y configuraciones sensibles.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
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
                      label: Text(
                        admin.enabled ? 'Admin activo' : 'Admin apagado',
                      ),
                    ),
                    Chip(
                      avatar: const Icon(Icons.pin_rounded, size: 18),
                      label: Text('PIN global: ${admin.pin}'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nuevo PIN global',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final pin = _pinController.text.trim();
                    if (pin.length < 4) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Usa un PIN de al menos 4 digitos.'),
                        ),
                      );
                      return;
                    }

                    await ref.read(adminModeProvider.notifier).updatePin(pin);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('PIN actualizado.')),
                    );
                  },
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Actualizar PIN'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _unlockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'PIN para activar admin',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await ref
                            .read(adminModeProvider.notifier)
                            .enableWithPin(_unlockController.text.trim());
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'Modo admin activado.' : 'PIN incorrecto.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.admin_panel_settings_rounded),
                      label: const Text('Activar admin'),
                    ),
                    OutlinedButton.icon(
                      onPressed: admin.enabled
                          ? () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await ref
                                  .read(adminModeProvider.notifier)
                                  .disable();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Modo admin desactivado.'),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.lock_rounded),
                      label: const Text('Apagar admin'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Sincronizacion base',
            subtitle:
                'Fase 1 deja listo el cimiento para modo offline-first con Supabase.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    sync.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  ),
                  title: Text(sync.statusLabel),
                  subtitle: Text(
                    settings.hasSupabaseConfig
                        ? 'Supabase detectado por dart-define.'
                        : 'Define SUPABASE_URL y SUPABASE_ANON_KEY para activar sync real.',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text('Ultimo intento: ${settings.lastSyncLabel}'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ref
                        .read(appSettingsProvider.notifier)
                        .recordSyncAttempt();
                    await ref.read(syncStatusProvider.notifier).simulateSync();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Sincronizacion base ejecutada.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Forzar sincronizacion'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}
