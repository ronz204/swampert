# Swampert — Sistema de diseño de interfaz

> Nota de alcance: este documento define la identidad visual de Swampert — paleta, tipografía, layout de las dos pantallas obligatorias (Dashboard / Consultas) y el elemento de firma del diseño. No cubre lógica de negocio ni estructura de componentes Svelte en detalle; es la referencia visual antes de escribir una sola línea de UI.

## Concepto: un panel de instrumentos, no un chat

Swampert no es una herramienta conversacional — es una **consola de observabilidad**, en la misma familia que Grafana, Datadog o LangSmith. Lo que un operador necesita en pantalla es lo mismo que necesita alguien mirando el panel de una sala de control: estado de ejecución en tiempo real, costo acumulado, y una señal inconfundible cuando algo falla. La identidad visual parte de ahí, no de una estética genérica de "producto de IA".

Por eso se descartan a propósito los tres looks que dominan el diseño generado por IA ahora mismo: fondo crema con acento terracota, negro con un solo acento neón, o layout tipo periódico con reglas finas. Ninguno de los tres dice nada sobre lo que hace Swampert. En su lugar, la paleta se deriva directamente de las tres dimensiones que el dominio necesita distinguir de un vistazo: **actividad** (¿qué está corriendo?), **costo** (¿cuánto sale?) y **falla** (¿qué se rompió?). Cada color del sistema representa una de esas tres preguntas — no son acentos decorativos, son las mismas categorías que ya existen en `execution_status` y `error_severity`.

## Paleta de colores

| Token | Hex | Uso |
|---|---|---|
| `--color-void` | `#12161C` | Fondo base. Gris-azulado casi negro, no negro puro — evita el cliché "dark mode neón". |
| `--color-panel` | `#1B222B` | Superficie de tarjetas, tablas, paneles laterales. |
| `--color-ink` | `#E7EAEE` | Texto primario sobre fondo oscuro. |
| `--color-current` | `#3FB8AF` | **Actividad.** Acento primario: ejecuciones en curso, agentes activos, elementos interactivos primarios (botones, links, foco). |
| `--color-ledger` | `#E8A33D` | **Costo.** Todo lo relacionado a tokens y `estimated_cost` — números de gasto, KPI de costo, barras de token usage. |
| `--color-alarm` | `#E5484D` | **Falla.** Errores, severidad crítica, estados `failed`. Reservado exclusivamente para esto — si se usa en otro lado, pierde su función de alerta. |

Tokens secundarios (derivados, no forman parte de la identidad principal pero completan los estados del dominio):

| Token | Hex | Uso |
|---|---|---|
| `--color-success` | `#4CAF7D` | Estado `completed`, severidad `low`. |
| `--color-caution` | `#E0793C` | Severidad `medium`/`high` (paso intermedio entre ledger y alarm). |
| `--color-border` | `#2A313B` | Bordes, separadores, líneas de tabla. |
| `--color-subtext` | `#8B94A3` | Texto secundario, timestamps, metadatos. |

**Regla de accesibilidad para color+estado:** ningún estado se comunica solo por color. Cada badge de `status`/`severity` combina color + forma (punto lleno = completed/low, anillo = running/medium, triángulo = failed/critical) para que el sistema siga siendo legible para daltonismo rojo-verde, que es exactamente el par de colores más usado acá (`--color-alarm` vs `--color-success`).

## Tipografía

Tres roles, sin mezclar familias al azar — las tres vienen de la misma tradición de diseño técnico (IBM Plex fue diseñada explícitamente para paneles de datos e interfaces de ingeniería), salvo el display, que se elige aparte para dar personalidad a los títulos sin sacrificar legibilidad de datos.

| Rol | Fuente | Uso |
|---|---|---|
| Display | **Space Grotesk** | Títulos de pantalla, números grandes de KPI (`3,009`-style). Geométrica, con carácter técnico, usada con moderación. |
| Cuerpo / UI | **IBM Plex Sans** | Labels, botones, texto de navegación, copys de estado vacío/error. |
| Datos / mono | **IBM Plex Mono** | UUIDs, timestamps, conteos de tokens, fragmentos de SQL, previsualización de JSON (`reasoning`, `config`, `details`). |

**Escala tipográfica** (rem, base 16px):

```
--text-display-xl: 3rem     /* KPI hero, ej. costo total del período */
--text-display-lg: 2rem     /* Títulos de pantalla (Dashboard / Consultas) */
--text-heading: 1.25rem     /* Encabezados de tarjeta/sección */
--text-body: 0.9375rem      /* Texto de UI general */
--text-caption: 0.8125rem   /* Metadatos, timestamps, ayudas de filtro */
--text-mono-data: 0.875rem  /* IDs, SQL, JSON — siempre en Plex Mono */
```

Regla de uso: **ningún dato numérico o identificador se pone en Space Grotesk o Plex Sans** — todo `id`, `token`, conteo o timestamp va en Plex Mono, incluso dentro de una tarjeta de KPI. Esto imita la convención real de herramientas de observabilidad (los números siempre en monoespaciada para que las cifras alineen verticalmente y sean fáciles de comparar de un vistazo).

## Layout general (shell)

```
┌──────┬────────────────────────────────────────────────────┐
│      │  [Company: Acme Corp ▾]      [Rango de fecha ▾]    │
│ nav  ├────────────────────────────────────────────────────┤
│ rail │                                                     │
│      │   [ Dashboard ]   [ Consultas ]   ← pestañas        │
│ ──── │  ───────────────────────────────────────────────    │
│ 🏢   │                                                     │
│ 📊   │              (contenido de la pantalla activa)      │
│ 🔍   │                                                     │
│      │                                                     │
└──────┴────────────────────────────────────────────────────┘
```

- **Rail lateral izquierdo**, angosto, solo iconos (colapsable): switcher de `company` (multi-tenant, siempre visible arriba del todo — es el primer dato que un usuario de una empresa necesita confirmar), y navegación entre módulos futuros.
- **Barra superior**: selector de rango de fechas global (afecta ambas pantallas) y las dos pestañas Dashboard/Consultas, con transición de layout completa entre una y otra — nunca conviven.
- El fondo del shell usa `--color-void`; cada tarjeta o panel flota sobre él en `--color-panel` con `--color-border` de 1px, sin sombras pesadas (una consola de datos no necesita profundidad dramática).

## Pantalla 1 — Dashboard

Propósito: lectura rápida, cero interacción de filtrado. KPIs primero, gráficos después.

```
┌─────────────┬─────────────┬─────────────┬─────────────┐
│ Ejecuciones  │ Costo total │ Tasa error  │ Agentes     │
│ 24h          │ (--ledger)  │ (--alarm)   │ activos     │
│  1,204        │  $312.40     │  3.2%       │  18         │
└─────────────┴─────────────┴─────────────┴─────────────┘
┌───────────────────────┬─────────────────────────────────┐
│ Ejecuciones por status │  Costo por swarm (barras)        │
│ (dona)                 │                                   │
├───────────────────────┴─────────────────────────────────┤
│  Tendencia de ejecuciones y errores (línea, 30 días)      │
└────────────────────────────────────────────────────────┘
```

- Fila de tarjetas KPI: número en Space Grotesk (`--text-display-xl`), label en Plex Sans arriba en `--color-subtext`. Cada tarjeta usa el color semántico correspondiente solo como acento fino (borde superior de 2px o ícono), nunca como fondo sólido — mantiene la superficie neutra y dejar el color para lo que importa.
- Gráficos: dona para distribución de `execution_status`, barras para costo por `swarm`, línea para tendencia temporal (ejecuciones vs errores superpuestos, usando `--color-current` y `--color-alarm` respectivamente — la comparación visual entre actividad y falla es el punto central del gráfico).
- Sin tablas de datos crudos ni filtros en esta pantalla — si algo necesita explorarse en detalle, esa es exactamente la señal para ir a Consultas.

## Pantalla 2 — Consultas

Propósito: exploración tabular con filtros, layout completamente distinto al Dashboard.

```
┌────────────┬──────────────────────────────────────────┐
│ FILTROS     │  Chips: [Status: failed ×] [Swarm: X ×]  │
│             │  ────────────────────────────────────    │
│ ▸ Status    │  id       execution  agent   status  cost │
│  ☑ completed│  a1b2...  #4471      writer  ● done  1.20 │
│  ☐ running  │  c3d4...  #4472      reviewr ▲ fail  0.85 │
│  ☐ failed   │  ...                                       │
│             │                                            │
│ ▸ Swarm      │                                            │
│  🔍 buscar   │                                            │
│  ☐ Swarm A (42)                                            │
│  ☐ Swarm B (17)                                            │
│             │                                            │
│ ▸ Rango fecha│                                            │
│  ○ Últimos 7d│                                            │
│  ○ 30d       │                                            │
│  ○ Custom    │                                            │
│             │                                            │
│ [Reiniciar] [Aplicar]                                     │
└────────────┴──────────────────────────────────────────┘
```

- Panel de filtros fijo a la izquierda (más ancho que el rail de navegación, es un panel de contenido, no de navegación global).
- Cada grupo de filtro es colapsable (`▸`/`▾`), con contador de registros junto a cada opción (ej. `Swarm A (42)`), buscador solo cuando la lista supera ~8 opciones.
- Chips de filtros activos arriba de la tabla, cada uno removible individualmente sin abrir el panel.
- La tabla usa Plex Mono para todas las columnas de datos (ids, costos, timestamps) y el badge de `status`/`severity` con la combinación color+forma descrita en la paleta.
- Botones **Reiniciar** (texto plano, `--color-subtext`) y **Aplicar** (relleno `--color-current`) — distinción clara entre acción destructiva/neutral y acción de confirmación.

## Elemento de firma: la cinta de traza (trace ribbon)

El elemento distintivo y recurrente del diseño es una **cinta horizontal de segmentos conectados**, uno por cada `ExecutionStep` de una ejecución — literalmente la unidad más chica de trazabilidad del dominio, convertida en el motivo visual central:

```
●───●───●───▲───○
```

- Cada segmento es un punto pequeño coloreado por el status de ese step (`--color-success`, `--color-current` si está en curso, `--color-alarm` si ahí ocurrió el `ExecutionError`).
- Aparece en tres lugares con el mismo componente, reforzando que es *la* firma visual del producto, no una decoración aislada:
  1. **Fila de tabla en Consultas**: como preview compacto de una ejecución, antes de expandir el detalle.
  2. **Detalle de ejecución** (al expandir una fila): la cinta completa, con cada segmento clickeable para ver el `reasoning` de ese step en Plex Mono.
  3. **Encabezado de sección en Dashboard**: una cinta decorativa (datos reales agregados del día, no decorativa-falsa) separando la fila de KPIs de la fila de gráficos.
- Animación: al cargar, los segmentos aparecen en secuencia (50ms de stagger cada uno) — un solo momento orquestado, no efectos sueltos. Respeta `prefers-reduced-motion` mostrando la cinta completa sin animar.

## Voz de la interfaz

- Estados vacíos y errores hablan en la voz del sistema, no de una persona: *"No hay ejecuciones en este rango de fechas"*, no *"¡Ups, no encontramos nada!"*.
- Los errores nunca se disculpan y nunca son vagos: *"La ejecución falló en el paso 4 (herramienta: `web_search`)"*, no *"Algo salió mal"*.
- Acciones nombradas por lo que hacen, no por cómo funciona el sistema: *"Reiniciar filtros"*, no *"Reset query params"*.

## Piso de calidad

- Contraste mínimo AA (4.5:1) entre `--color-ink` y `--color-void`/`--color-panel` — verificado, no asumido.
- Foco de teclado visible en todos los elementos interactivos: anillo de 2px en `--color-current` con offset, nunca `outline: none` sin reemplazo.
- Responsive: el rail lateral colapsa a iconos-solamente bajo 1024px; el panel de filtros de Consultas pasa a modal deslizable en mobile en vez de columna fija.
- Un solo riesgo estético (la cinta de traza animada) — todo lo demás alrededor se mantiene disciplinado y sin decoración adicional.