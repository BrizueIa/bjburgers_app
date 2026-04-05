# BJ Burguers App - Tasks y Avance

Este documento se actualiza durante el desarrollo para consultar el avance real del proyecto.

## Estado general

- Fase actual: `Fase 2 estable + base remota inicial en preparacion`
- Estado del proyecto: `ya existe persistencia local real y primer esquema Supabase versionado`
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
- README actualizado
- Analisis y tests base pasando

### En progreso
- Flujo de trabajo por ramas y merges en GitHub
- Enlace autenticado del CLI a Supabase pendiente de permisos locales

### Pendiente inmediato
- Profundizar estrategia de sincronizacion real por colas y conflictos
- Profundizar Fase 2 con validaciones, eliminaciones seguras y edicion avanzada de recetas
- Extender sync a comandas, POS, ventas y caja

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

- [ ] Definir tablas `orders`, `order_items`, `sales`, `sale_items`
- [ ] Crear flujo de nueva comanda
- [ ] Agregar productos a comanda
- [ ] Permitir quitar ingredientes y notas
- [ ] Cola visual de comandas
- [ ] Mover comanda a cobro
- [ ] POS con efectivo y transferencia
- [ ] Calculadora de cambio
- [ ] Registro de venta

## Fase 4 - Caja

- [ ] Definir tablas `cash_sessions` y `cash_movements`
- [ ] Abrir caja
- [ ] Registrar apertura inicial
- [ ] Registrar movimientos manuales
- [ ] Restringir acciones por modo admin
- [ ] Realizar corte
- [ ] Mostrar diferencia teorico vs real

## Fase 5 - Dashboard y Reportes

- [ ] KPI diarios reales
- [ ] Resumen de ventas
- [ ] Resumen de caja
- [ ] Utilidad estimada
- [ ] Reportes por rango de fecha
- [ ] Ventas por metodo de pago
- [ ] Productos mas vendidos

## Fase 6 - Sync real y despliegue

- [x] Crear proyecto Supabase
- [x] Definir primera migracion de tablas remotas
- [x] Aplicar migraciones remotas con `supabase db push`
- [x] Implementar sincronizacion manual inicial desde la app
- [ ] Implementar cola real de sincronizacion
- [ ] Resolver conflictos simples
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

Empezar `Fase 3` con `comandas` y `POS`, usando el inventario y los costos actuales como base para tomar pedidos, cobrar y afectar caja.
