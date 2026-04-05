# BJ Burguers App - Plan Maestro de Implementacion

## 1. Objetivo del sistema

Construir una aplicacion Flutter multiplataforma para `Android`, `Linux` y `Windows` enfocada en la operacion diaria de un negocio de comida, con soporte para trabajo `offline-first`, sincronizacion con `Supabase`, control operativo mediante `PIN admin`, y modulos para dashboard, POS, comandas, inventario, compras, caja, reportes y configuracion.

El sistema sera `monousuario`, sin login visible, con una sola cuenta tecnica para sincronizar datos entre dispositivos.

## 2. Principios del sistema

### 2.1 Operacion general
- La app abre directamente sin login.
- Debe funcionar aunque no haya internet.
- Al volver la conexion, debe sincronizar automaticamente.
- Debe poder usarse en laptop y movil con los mismos datos.

### 2.2 Seguridad operativa
- No habra autenticacion tradicional.
- Existira un `modo admin` protegido con `PIN global sincronizado`.
- Si el modo admin esta desactivado, se bloquean cambios de precios, costos, recetas, compras, movimientos manuales de caja, cortes y configuraciones sensibles.

### 2.3 Modelo contable
- Los costos se calculan con `ultimo precio de compra`.
- Las ventas registran ingresos reales por metodo de pago.
- Las comandas afectan la operacion.
- El POS afecta ventas y caja.
- Inventario y compras afectan costos y margenes.

## 3. Stack tecnologico

### 3.1 Frontend
- Flutter
- Material 3 adaptado a movil y desktop

### 3.2 Estado y arquitectura
- `flutter_riverpod`
- `go_router`

### 3.3 Persistencia local
- `drift`
- `sqlite3`

### 3.4 Sincronizacion y nube
- `supabase_flutter`

### 3.5 Utilidades
- `connectivity_plus`
- `shared_preferences`
- `intl`
- `uuid`

## 4. Arquitectura general

Se usara arquitectura por modulos y capas.

```text
lib/
  app/
    bootstrap/
    router/
    theme/
    shell/
  core/
    admin/
    config/
    storage/
    sync/
    widgets/
  features/
    dashboard/
      data/
      domain/
      presentation/
    pos/
      data/
      domain/
      presentation/
    comandas/
      data/
      domain/
      presentation/
    inventario/
      data/
      domain/
      presentation/
    compras/
      data/
      domain/
      presentation/
    caja/
      data/
      domain/
      presentation/
    reportes/
      data/
      domain/
      presentation/
    settings/
      data/
      domain/
      presentation/
```

## 5. Modulos funcionales

### 5.1 Dashboard
- Ventas del dia
- Ingresos por efectivo y transferencia
- Utilidad estimada del dia
- Cantidad de pedidos
- Caja esperada
- Estado de sincronizacion

### 5.2 Inventario
- CRUD de ingredientes
- CRUD de productos
- Productos simples y compuestos
- Recetas por ingrediente
- Costo actual y margen estimado

### 5.3 Compras
- Registro de surtidos por fecha
- Cantidad comprada y costo total
- Calculo de costo unitario
- Actualizacion del costo actual usando ultimo precio
- Historial por ingrediente

### 5.4 Comandas
- Crear nueva comanda
- Agregar productos
- Notas y modificaciones
- Estados: pendiente, preparando, listo, entregado, cancelado
- Acceso rapido al menu digital
- Mover comanda al POS

### 5.5 POS
- Cobrar comandas o ventas directas
- Efectivo o transferencia
- Calculadora de cambio
- Registro de venta y su impacto en caja

### 5.6 Caja
- Abrir caja con monto inicial
- Movimientos manuales: deposito, retiro, ajuste
- Separar fisico y digital
- Cierre y corte
- Comparacion de teorico vs real

### 5.7 Reportes
- Ventas por fecha
- Ventas por metodo de pago
- Ventas por producto
- Utilidad estimada
- Compras y cortes

### 5.8 Settings
- Nombre del negocio
- PIN admin global
- Estado del modo admin
- Imagen o URL del menu digital
- Estado de sincronizacion
- Ultima sincronizacion

## 6. Modelo de datos

### settings
- id
- business_name
- admin_pin
- admin_mode_enabled
- digital_menu_image_url
- created_at
- updated_at

### ingredients
- id
- name
- unit_name
- current_unit_cost
- is_active
- created_at
- updated_at
- deleted_at
- device_id
- sync_status

### ingredient_purchases
- id
- ingredient_id
- purchased_quantity
- total_cost
- unit_cost
- purchased_at
- note
- created_at
- updated_at
- deleted_at
- device_id
- sync_status

### products
- id
- name
- category_name
- product_type
- sale_price
- direct_cost
- is_active
- display_order
- created_at
- updated_at
- deleted_at
- device_id
- sync_status

### product_recipe_items
- id
- product_id
- ingredient_id
- quantity_used
- is_optional
- created_at
- updated_at
- deleted_at
- device_id
- sync_status

### orders
- id
- order_number
- status
- notes
- total_estimated
- created_at
- updated_at
- deleted_at
- device_id
- sync_status

### order_items
- id
- order_id
- product_id
- product_name_snapshot
- unit_price_snapshot
- base_cost_snapshot
- quantity
- notes
- removed_ingredients_json
- created_at
- updated_at
- deleted_at
- device_id
- sync_status

### sales
- id
- sale_number
- source_order_id
- total_amount
- estimated_cost
- estimated_profit
- payment_method
- paid_amount
- change_amount
- sold_at
- created_at
- updated_at
- deleted_at
- device_id
- sync_status

### sale_items
- id
- sale_id
- product_id
- product_name_snapshot
- unit_price_snapshot
- unit_cost_snapshot
- quantity
- line_total
- line_cost_total
- created_at
- updated_at
- deleted_at
- device_id
- sync_status

### cash_sessions
- id
- opened_at
- opening_amount
- closed_at
- closing_expected_cash
- closing_real_cash
- transfer_total
- difference_amount
- status
- note
- created_at
- updated_at
- deleted_at
- device_id
- sync_status

### cash_movements
- id
- cash_session_id
- movement_type
- payment_method
- amount
- note
- reference_type
- reference_id
- created_at
- updated_at
- deleted_at
- device_id
- sync_status

### sync_queue
- id
- entity_type
- entity_id
- operation_type
- payload_json
- status
- retry_count
- last_error
- created_at
- updated_at

### app_assets
- id
- asset_type
- remote_url
- local_path
- created_at
- updated_at
- device_id
- sync_status

## 7. Reglas de negocio

### Productos
- `simple`: usa `direct_cost`
- `compuesto`: usa receta

### Costos
- El costo actual del ingrediente se toma de la ultima compra registrada.
- El costo de un producto compuesto es la suma de `cantidad usada x costo unitario actual`.

### Utilidad
- `utilidad estimada = precio de venta - costo estimado`

### Comandas
- No generan ingreso por si solas.
- Al cobrarse, crean una venta.

### Caja
- Solo una caja activa a la vez.
- Ventas en efectivo incrementan caja fisica.
- Ventas en transferencia incrementan caja digital.
- Depositos, retiros y ajustes requieren admin.

### Admin
- El PIN es global.
- Se sincroniza entre dispositivos.
- Si admin esta apagado, solo se permite operacion de venta, comanda y consulta.

## 8. Estrategia offline-first

### Persistencia local
Toda accion debe guardarse primero en SQLite.

### Cola de sincronizacion
Cada cambio importante crea o actualiza un registro en `sync_queue`.

### Subida de cambios
Cuando hay internet:
- se recorren cambios pendientes
- se suben a Supabase
- se marcan como sincronizados

### Descarga de cambios
Al abrir la app o al forzar sync:
- se consultan cambios remotos recientes
- se aplican localmente

### Resolucion de conflictos
- Catalogos y settings: `last write wins`
- Ventas, compras y caja: preferencia por inserciones inmutables

## 9. Supabase

### Objetivo
Servir como respaldo y sincronizacion central entre dispositivos.

### Uso
- una sola cuenta tecnica para toda la app
- sin login visible para el usuario
- almacenamiento de datos operativos
- almacenamiento de imagen del menu digital

### Configuracion inicial
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## 10. Navegacion y UX

### Movil
- navegacion inferior
- accesos rapidos visibles

### Desktop
- sidebar fija
- paneles amplios

### Accesos rapidos globales
- nueva comanda
- cobrar en POS
- abrir o cerrar caja
- registrar compra
- ver menu digital

## 11. Fases de implementacion

### Fase 1 - Fundacion tecnica
- limpiar template inicial
- crear arquitectura por modulos
- configurar tema y shell adaptativo
- integrar Riverpod
- integrar go_router
- configurar cimientos de almacenamiento local
- preparar bootstrap de Supabase
- crear modulo settings
- crear modo admin con PIN global

### Fase 2 - Inventario y compras
- CRUD de ingredientes
- CRUD de productos
- recetas por ingrediente
- compras
- calculo de ultimo costo
- calculo de costo de producto
- margen estimado

### Fase 3 - Comandas y POS
- crear comandas
- cola de estados
- personalizacion quitando ingredientes
- mover al POS
- cobrar y generar ventas
- calculadora de cambio

### Fase 4 - Caja
- apertura de caja
- movimientos manuales
- cierres y cortes
- separacion de efectivo y transferencia

### Fase 5 - Dashboard y reportes
- KPI diarios
- resumen del dia
- filtros por rango
- ventas por metodo de pago y producto

### Fase 6 - Pulido y despliegue
- mejoras UX
- optimizacion de sync
- build Android, Windows y Linux
- documentacion de instalacion

## 12. Roadmap tecnico detallado

1. Definir dependencias y estructura base del proyecto.
2. Definir esquema local de drift.
3. Definir esquema remoto en Supabase.
4. Implementar repositorios base y sync engine.
5. Implementar settings y modo admin.
6. Implementar inventario.
7. Implementar compras.
8. Implementar formulas de costo y margen.
9. Implementar comandas.
10. Implementar POS.
11. Implementar caja.
12. Implementar dashboard.
13. Implementar reportes.
14. Probar sincronizacion real entre dispositivos.
15. Validar flujo completo de compra -> costo -> comanda -> cobro -> caja -> reportes.

## 13. Casos de uso prioritarios

1. Registrar una compra de carnes y actualizar costo.
2. Ver como ese nuevo costo cambia el margen de una hamburguesa.
3. Recibir una comanda con hamburguesa sin verduras.
4. Mover la comanda al POS y cobrarla en efectivo.
5. Ver la feria rapidamente.
6. Confirmar que la venta impacta caja y dashboard.
7. Hacer corte al final del dia.
8. Abrir la app en otro dispositivo y sincronizar datos.

## 14. Riesgos y mitigaciones

### Riesgo
Datos duplicados por sync.

### Mitigacion
- UUID por entidad
- `sync_queue` clara
- operaciones idempotentes

### Riesgo
Caja inconsistente.

### Mitigacion
- una sola sesion activa
- validaciones fuertes de dominio
- movimientos bien tipados

### Riesgo
Ediciones simultaneas desde dos dispositivos.

### Mitigacion
- monousuario
- sincronizacion frecuente
- `last write wins` donde aplique
- evitar editar registros sensibles ya cerrados

### Riesgo
Uso sin internet prolongado.

### Mitigacion
- base local completa
- UI con estado de sync
- reintentos automaticos

## 15. Criterios de calidad

- La app debe funcionar sin internet.
- La app debe sincronizar al reconectar.
- Los costos deben usar ultimo precio de compra.
- El POS debe ser rapido y simple.
- Las comandas deben ser claras visualmente.
- Caja debe distinguir fisico y digital.
- El sistema debe responder bien en laptop y movil.
- Las restricciones de modo admin deben cumplirse.

## 16. Fuera del MVP inicial

- impresion de tickets
- exportacion a PDF o Excel
- notificaciones
- multiples cajas
- multiples usuarios
- roles avanzados
- soporte para hardware POS
- estadisticas avanzadas
- integracion publica del menu

## 17. Resultado esperado del MVP

Al finalizar el MVP, el sistema debe permitir:
- registrar ingredientes y productos
- registrar compras y actualizar costos
- calcular margenes
- crear y gestionar comandas
- cobrar pedidos
- controlar caja
- revisar dashboard
- consultar reportes
- sincronizar entre movil y laptop
- operar aun sin internet
