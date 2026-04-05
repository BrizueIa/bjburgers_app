# BJ Burguers App - Tasks y Avance

Este documento se actualiza durante el desarrollo para consultar el avance real del proyecto.

## Estado general

- Fase actual: `Fase 1 completada`
- Estado del proyecto: `base funcional lista para seguir construyendo`
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
- README actualizado
- Analisis y tests base pasando

### En progreso
- Preparacion de repositorio Git y publicacion inicial en GitHub

### Pendiente inmediato
- Fase 2: inventario y compras
- Esquema real de base local con `drift`
- Proyecto Supabase real
- Tablas remotas y estrategia de sincronizacion real

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

### Pendientes de cierre fino
- [ ] Conectar Supabase real cuando exista el proyecto
- [ ] Definir base local real con `drift`

## Fase 2 - Inventario y Compras

- [ ] Definir tablas `ingredients`, `ingredient_purchases`, `products`, `product_recipe_items`
- [ ] Implementar base de datos local con `drift`
- [ ] CRUD de ingredientes
- [ ] CRUD de productos simples
- [ ] CRUD de productos compuestos
- [ ] Editor de receta por ingrediente
- [ ] Registro de compras
- [ ] Calculo de costo unitario por ultima compra
- [ ] Calculo de costo de producto
- [ ] Calculo de margen estimado

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

- [ ] Crear proyecto Supabase
- [ ] Definir tablas remotas
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

Empezar `Fase 2` construyendo el esquema `drift` y el modulo de `inventario/compras`, porque de ahi dependen costos, margenes, POS y reportes.
