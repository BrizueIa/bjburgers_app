# BJ Burguers App - Tasks y Avance

Este documento se actualiza durante el desarrollo para consultar el avance real del proyecto.

## Estado general

- Fase actual: `Sync engine local con cola de pendientes`
- Estado del proyecto: `la app ya opera localmente y sincroniza con una cola basica en lugar de depender solo de snapshots completos`
- Ultima actualizacion: `2026-04-05`

## Resumen de avance

### Completado
- Documento maestro creado en `docs/implementation_plan.md`
- Arquitectura base modular creada en `lib/`
- Navegacion adaptativa movil/desktop implementada
- Tema visual base implementado
- Settings iniciales implementados
- Modo admin con PIN global local implementado
- Bootstrap inicial para Supabase por `dart-define`
- Estado base de conectividad y sincronizacion simulado
- Pantallas placeholder para todos los modulos creadas
- Base local con `drift` implementada
- Esquema local inicial para ingredientes, compras, productos y recetas creado
- CRUD inicial funcional de ingredientes y productos implementado
- Registro de compras funcional con actualizacion automatica de costo unitario implementado
- Calculo visual de costo y margen para productos implementado
- Proyecto Supabase inicializado en el repo
- Primera migracion SQL creada para el esquema remoto base
- Servicio inicial de sincronizacion app <-> Supabase implementado
- Sincronizacion manual real desde settings para configuracion, ingredientes, productos, recetas y compras implementada
- Plantilla local de secretos creada para `SUPABASE_URL` y `SUPABASE_ANON_KEY`
- Carga de configuracion por `.env` integrada para ejecutar facil desde VS Code o `flutter run`
- Esquema local ampliado con comandas, items de comanda, ventas y detalle de ventas
- Esquema local ampliado con sesiones y movimientos de caja
- Modulo de comandas funcional con cola, estados y personalizacion basica de ingredientes
- Modulo POS funcional con calculadora de cambio y registro de ventas
- Modulo de caja funcional con apertura, movimientos, integracion con ventas y corte
- Dashboard conectado a datos reales de ventas, compras, comandas y caja
- Sincronizacion manual ampliada a comandas, ventas y caja
- Modulo de reportes funcional con rangos, productos, ventas, compras y sesiones de caja
- Cola local de sincronizacion implementada para mutaciones principales
- Pull remoto refinado para upserts incrementales sin limpiar tablas completas en cada sync
- Pull remoto ahora evita pisar entidades que aun tienen cambios pendientes en cola local
- Archivado local de ingredientes y productos preparado con soft delete sincronizable
- Migracion RLS agregada para permitir sincronizacion con la clave anon actual
- README actualizado
- Analisis y tests base pasando

### En progreso
- Flujo de trabajo por ramas y merges en GitHub
- Enlace autenticado del CLI a Supabase pendiente de permisos locales

### Pendiente inmediato
- Profundizar estrategia de sincronizacion real por colas y conflictos
- Refinar estrategia de sincronizacion para manejar borrados y conflictos finos
- Extender soft delete al resto de modulos segun necesidad operativa
- Extender dashboard/reportes con filtros personalizados y mas detalle historico
- Endurecer seguridad remota cuando exista una estrategia de identidad mas robusta

## Backlog por fases

## Fase 1 - Fundacion tecnica

### Completadas
- [x] Crear documento maestro del proyecto
- [x] Reemplazar template inicial de Flutter
- [x] Integrar `flutter_riverpod`
- [x] Integrar `go_router`
- [x] Crear shell responsivo
- [x] Crear estructura modular de features
- [x] Crear pantalla de settings inicial
- [x] Crear modo admin con PIN global
- [x] Preparar bootstrap base para Supabase
- [x] Preparar estado base de sincronizacion
- [x] Actualizar README y tests
- [x] Publicar base inicial en GitHub

### Pendientes de cierre fino
- [ ] Conectar Supabase real cuando exista el proyecto
- [x] Definir base local real con `drift`

## Fase 2 - Inventario y Compras

- [x] Definir tablas `ingredients`, `ingredient_purchases`, `products`, `product_recipe_items`
- [x] Implementar base de datos local con `drift`
- [x] CRUD de ingredientes
- [x] CRUD de productos simples
- [x] CRUD de productos compuestos
- [x] Editor inicial de receta por ingrediente
- [x] Registro de compras
- [x] Calculo de costo unitario por ultima compra
- [x] Calculo de costo de producto
- [x] Calculo de margen estimado
- [ ] Mejorar validaciones y estados vacios del flujo de inventario
- [ ] Agregar eliminacion segura o archivado mas completo
- [ ] Preparar inventario para sincronizacion remota
- [x] Preparar sincronizacion remota manual inicial de inventario/compras

## Fase 3 - Comandas y POS

- [x] Definir tablas `orders`, `order_items`, `sales`, `sale_items`
- [x] Crear flujo de nueva comanda
- [x] Agregar productos a comanda
- [x] Permitir quitar ingredientes y notas
- [x] Cola visual de comandas
- [x] Mover comanda a cobro
- [x] POS con efectivo y transferencia
- [x] Calculadora de cambio
- [x] Registro de venta
- [x] Impactar caja automaticamente al cobrar
- [x] Sincronizar comandas y ventas con Supabase

## Fase 4 - Caja

- [x] Definir tablas `cash_sessions` y `cash_movements`
- [x] Abrir caja
- [x] Registrar apertura inicial
- [x] Registrar movimientos manuales
- [x] Restringir acciones por modo admin
- [x] Realizar corte
- [x] Mostrar diferencia teorico vs real
- [x] Sincronizar caja con Supabase

## Fase 5 - Dashboard y Reportes

- [x] KPI diarios reales
- [x] Resumen de ventas
- [x] Resumen de caja
- [x] Utilidad estimada
- [x] Reportes por rango de fecha
- [x] Ventas por metodo de pago
- [x] Productos mas vendidos
- [ ] Filtros personalizados por fecha
- [ ] Reportes mas detallados de compras y cortes

## Fase 6 - Sync real y despliegue

- [x] Crear proyecto Supabase
- [x] Definir primera migracion de tablas remotas
- [x] Aplicar migraciones remotas con `supabase db push`
- [x] Implementar sincronizacion manual inicial desde la app
- [x] Implementar cola basica local de sincronizacion
- [ ] Resolver conflictos simples
- [ ] Manejar borrados y limpieza remota incremental
- [x] Reducir resync destructivo con upserts incrementales en pulls remotos
- [ ] Pruebas entre movil y laptop
- [ ] Build Android
- [ ] Build Linux
- [ ] Build Windows

## Notas operativas

- La app es monousuario.
- No habra login visible.
- El control sensible se hace por `modo admin` con `PIN global sincronizado`.
- La contabilidad de costos usara `ultimo precio de compra`.

## Proxima tarea recomendada

Pulir `sync` para borrados/conflictos y despues agregar filtros personalizados y detalle historico avanzado en reportes.
