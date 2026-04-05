# BJ Burguers App

Sistema operativo para `Android`, `Linux` y `Windows` enfocado en dashboard, POS, comandas, inventario, compras, caja y reportes.

## Estado actual

La Fase 1 ya deja listo:

- arquitectura modular por features
- `Riverpod` y `go_router`
- shell responsivo para movil y desktop
- configuracion operativa local
- `modo admin` con `PIN` global local
- bootstrap inicial para `Supabase`
- base para evolucionar a sync `offline-first`

## Documento maestro

El plan detallado vive en `docs/implementation_plan.md`.

## Configuracion de Supabase

La app puede arrancar sin Supabase. Como el repo es publico, no guardes la URL ni la anon key directo en codigo o en archivos versionados.

1. Crea tu archivo local copiando `env/app_config.example.json` a `env/app_config.json`
2. Rellena ahi tus valores reales de Supabase
3. Ejecuta la app con `--dart-define-from-file`

Ejemplo:

```bash
cp env/app_config.example.json env/app_config.json
```

```bash
flutter run --dart-define-from-file=env/app_config.json
```

Para builds:

```bash
flutter build apk --dart-define-from-file=env/app_config.json
flutter build linux --dart-define-from-file=env/app_config.json
flutter build windows --dart-define-from-file=env/app_config.json
```

`env/app_config.json` esta ignorado por Git.

Para trabajar el esquema remoto con CLI:

```bash
supabase link --project-ref valahdxrscbcxuehyaxq
supabase db push
```

Las migraciones viven en `supabase/migrations/`.

La pantalla `Settings` ya permite lanzar una sincronizacion manual real entre la app local y Supabase para:

- configuracion del negocio
- ingredientes
- productos
- recetas
- compras

## Comandos utiles

```bash
flutter pub get
flutter analyze
flutter test
```

`Este código no puede ser usado ni comercializado sin permiso`
