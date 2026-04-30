# Design System

Direccion visual oficial para `bjburguers_app`.

## Objetivo

La app debe sentirse como una herramienta de operacion diaria, no como una landing page.

Prioridades:
- velocidad visual
- lectura inmediata
- una mano en movil
- densidad util en Pixel 7
- consistencia entre modulos

## Dispositivo Base

La referencia principal de mobile es Pixel 7.

Suposiciones de diseno:
- ancho util aproximado: 380 a 412 dp
- uso frecuente con una mano
- sesiones largas de operacion
- necesidad de ver mas informacion sin scroll excesivo

## Principios

1. Primero operacion, despues decoracion.
2. Una tarjeta solo existe si separa informacion importante.
3. Nada de heroes, banners grandes o bloques explicativos largos.
4. Los estados vacios deben ser cortos y directos.
5. El color de acento se usa para accion o estado, no para pintar toda la pantalla.
6. Cada pantalla debe mostrar la mayor cantidad de informacion util posible sin ruido.

## Lenguaje Visual

### Superficies

- fondo general: calido claro, neutro
- paneles y cards: casi blanco
- bordes: suaves, visibles, sin sombras fuertes
- evitar gradientes de fondo en pantallas principales

### Radios

- radio base: `14`
- radio card: `16`
- radio pill/chip: `999`
- evitar radios grandes tipo `28+` salvo casos excepcionales

### Elevacion

- preferir `0`
- usar borde antes que sombra
- sombras fuertes no son parte del sistema

### Color

- `primary`: carbon oscuro
- `secondary`: dorado sobrio
- `primaryContainer`: neutro calido para indicadores e iconos
- no usar naranja saturado como fondo principal de componentes

## Tipografia

- titulos: peso `700` o `800`
- valores metricos: grandes pero compactos
- texto secundario: corto y util
- evitar subtitulos descriptivos largos

## Espaciado

- padding de pantalla movil: `16`
- separacion corta entre bloques: `10` a `14`
- padding interno de card: `16` a `18`
- evitar layouts demasiado aireados

## Componentes

### AppBar

- simple, plana, sin gradientes
- titulo alineado a la izquierda
- acciones minimas y claras

### Cards

- compactas
- informacion apilada con jerarquia clara
- icono pequeno dentro de contenedor sobrio
- no usar cards gigantes de una sola metrica cuando se pueda usar grid

### Botones

- alto aproximado: `44` a `46`
- filled button oscuro
- outlined button neutro
- copy corto: verbos directos

### Inputs

- relleno claro
- borde visible
- radio `14`
- labels breves

### Navigation Bar

- fondo claro
- indicador discreto
- labels cortos
- no usar barra oscura pesada en mobile

### Bottom Sheets

- compactos
- encabezado corto
- lista densa

## Patrones de Pantalla

### Dashboard

- usar grid de 2 columnas en mobile para metricas
- usar pills para estado rapido
- resumir modulos con bloques compactos

### Listas operativas

- usar `ListTile` denso
- reducir padding vertical
- mostrar accion o estado sin texto ornamental

### Estados vacios

Usar una de estas variantes:
- solo icono
- icono + accion
- texto corto de una linea si es indispensable

No usar:
- parrafos explicativos
- tips largos
- marketing copy

## Copy

Reglas:
- corto
- operativo
- sin tutoriales dentro de la UI
- sin frases como "aqui puedes...", "usa esta vista para...", "te permite..."

Ejemplos correctos:
- `No hay caja abierta`
- `Comanda no disponible`
- `Sin ventas`

Ejemplos incorrectos:
- `Esta vista muestra...`
- `Usa la pestana...`
- `Aqui podras...`

## Regla Para Nuevos Cambios

Cualquier nuevo modulo, componente o pantalla debe seguir este documento antes de introducir:
- nuevos colores
- nuevos radios
- layouts hero
- bloques explicativos
- componentes decorativos grandes

Si hay duda entre dos opciones validas, usar la mas compacta y menos ornamental.
