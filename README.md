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

La app puede arrancar sin Supabase. Cuando tengas tu proyecto creado, ejecuta con:

```bash
flutter run \
  --dart-define=SUPABASE_URL=tu_url \
  --dart-define=SUPABASE_ANON_KEY=tu_anon_key
```

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
