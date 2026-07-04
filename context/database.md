# Swampert — Modelado de persistencia

> Nota de alcance: este documento traduce el modelo de dominio (`modeling.md`) a su forma concreta de **tablas en PostgreSQL**: qué columnas tiene cada una, qué tipo de dato usar, cómo se relacionan entre sí, dónde van los índices y cómo se particiona lo que crece sin límite. No cubre la arquitectura de la aplicación (backend, API, frontend) — solo la base de datos en sí.
>
> Convención: la prosa está en español, pero los nombres de tablas, columnas y tipos van en inglés, tal cual se van a escribir en el SQL real (por convención de código).

## Vista general de las tablas

Swampert se modela con diez tablas sustantivas (más una tabla puente de relación muchos-a-muchos). En orden, desde lo más estable hasta lo más volátil:

1. `companies`
2. `users`
3. `agents`
4. `swarms`
5. `swarm_agents` (tabla puente)
6. `tasks`
7. `executions`
8. `execution_steps`
9. `token_costs`
10. `execution_errors`
11. `audit_logs`

## Convenciones generales

Antes de entrar tabla por tabla, algunas convenciones que aplican a todo el esquema:

- **Clave primaria**: todas las tablas usan `UUID` como clave primaria (columna `id`), generado en el momento de la inserción. Se elige `UUID` en vez de un entero autoincremental porque, al ser un sistema donde distintos procesos pueden crear registros de forma concurrente (varios agents escribiendo steps al mismo tiempo, por ejemplo), un identificador que no depende de una secuencia centralizada evita cuellos de botella y colisiones.
- **Aislamiento por company**: toda tabla cuyo contenido pertenece a una company específica tiene una columna `company_id` (referenciando a `companies.id`), y esa columna es la base sobre la que se aplican las políticas de *Row-Level Security*. Esto es así incluso en tablas donde `company_id` podría inferirse indirectamente (por ejemplo, a través de `swarm_id`) — se duplica intencionalmente para que las políticas de seguridad y los índices de filtrado no dependan de un `JOIN`.
- **Timestamps**: toda tabla tiene como mínimo `created_at` (`TIMESTAMPTZ`, con default al momento de la inserción). Las tablas cuyo estado cambia con el tiempo (como `executions`) también tienen `updated_at`.
- **Estados como ENUM**: cualquier columna que representa un conjunto cerrado de valores posibles (estados, roles, severidades) se modela como un tipo `ENUM` de PostgreSQL, nunca como texto libre. Esto evita valores inválidos a nivel de base de datos, sin depender de que la aplicación los valide.

## Tabla por tabla

### `companies`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | Clave primaria |
| `name` | `TEXT` | |
| `tax_id` | `TEXT` | Único |
| `plan` | `ENUM(company_plan)` | `basic`, `pro`, `enterprise` |
| `is_active` | `BOOLEAN` | Default `true` |
| `created_at` | `TIMESTAMPTZ` | |

Es la tabla raíz de todo el esquema: todas las demás tablas, directa o indirectamente, cuelgan de acá.

### `users`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | Clave primaria |
| `company_id` | `UUID` | FK → `companies.id` |
| `name` | `TEXT` | |
| `email` | `TEXT` | Único |
| `role` | `ENUM(user_role)` | `admin`, `member`, `viewer` |
| `is_active` | `BOOLEAN` | Default `true` |
| `created_at` | `TIMESTAMPTZ` | |

**Índice recomendado**: `(company_id)` — casi toda consulta sobre users parte de "los users de esta company".

### `agents`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | Clave primaria |
| `company_id` | `UUID` | FK → `companies.id` |
| `name` | `TEXT` | |
| `role` | `TEXT` | Ej: "researcher", "writer", "reviewer" |
| `base_model` | `TEXT` | Ej: "model-x-v2" (dato descriptivo, no se valida contra un proveedor real) |
| `tools` | `ARRAY(TEXT)` | Lista de herramientas que el agent tiene disponibles |
| `config` | `JSONB` | Parámetros libres de configuración (instrucciones, límites, etc.) |
| `is_active` | `BOOLEAN` | Default `true` |
| `created_at` | `TIMESTAMPTZ` | |

**Por qué `ARRAY` y `JSONB` acá**: la lista de tools es naturalmente una lista corta y homogénea (por eso `ARRAY` alcanza), mientras que `config` es heterogénea y puede variar de agent a agent (por eso conviene `JSONB`, que no obliga a un esquema fijo de columnas).

**Índice recomendado**: `(company_id)`, y un índice `GIN` sobre `config` si se espera filtrar agents por algún parámetro específico dentro del JSON.

### `swarms`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | Clave primaria |
| `company_id` | `UUID` | FK → `companies.id` |
| `name` | `TEXT` | |
| `description` | `TEXT` | |
| `status` | `ENUM(swarm_status)` | `active`, `paused`, `archived` |
| `created_at` | `TIMESTAMPTZ` | |

**Índice recomendado**: `(company_id, status)` — el dashboard casi siempre pide "los swarms activos de esta company".

### `swarm_agents` (tabla puente)

| Columna | Tipo | Notas |
|---|---|---|
| `swarm_id` | `UUID` | FK → `swarms.id` |
| `agent_id` | `UUID` | FK → `agents.id` |
| `added_at` | `TIMESTAMPTZ` | |

Clave primaria compuesta: `(swarm_id, agent_id)`. Esta tabla resuelve la relación muchos-a-muchos entre swarms y agents (un agent puede participar en más de un swarm, y un swarm tiene varios agents). Al ser una tabla puente pura, no cuenta dentro de las "diez tablas sustantivas" del modelo, aunque es igual de necesaria.

### `tasks`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | Clave primaria |
| `company_id` | `UUID` | FK → `companies.id` |
| `swarm_id` | `UUID` | FK → `swarms.id` |
| `title` | `TEXT` | |
| `description` | `TEXT` | |
| `status` | `ENUM(task_status)` | `pending`, `in_progress`, `completed`, `failed` |
| `priority` | `ENUM(task_priority)` | `low`, `medium`, `high` |
| `created_at` | `TIMESTAMPTZ` | |

**Índice recomendado**: `(company_id, status)` y `(swarm_id)`.

### `executions`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | Clave primaria |
| `company_id` | `UUID` | FK → `companies.id` |
| `task_id` | `UUID` | FK → `tasks.id` |
| `attempt_number` | `INTEGER` | 1, 2, 3... para reintentos de la misma task |
| `status` | `ENUM(execution_status)` | `pending`, `running`, `completed`, `failed` |
| `started_at` | `TIMESTAMPTZ` | |
| `finished_at` | `TIMESTAMPTZ` | Nulo mientras está en curso |

Esta es una de las tablas de mayor volumen del sistema (crece con cada intento de cada task), y es la principal candidata a **particionamiento por rango de fecha** (por ejemplo, una partición por mes sobre `started_at`).

**Índices recomendados**:
- `(company_id, started_at)` — el filtro más común del dashboard es "executions de esta company en tal rango de fechas".
- `(task_id)` — para reconstruir el historial de intentos de una task puntual.
- `(status)` — útil para vistas tipo "todas las executions fallidas".

### `execution_steps`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | Clave primaria |
| `execution_id` | `UUID` | FK → `executions.id` |
| `agent_id` | `UUID` | FK → `agents.id` |
| `step_number` | `INTEGER` | Orden dentro de la execution |
| `reasoning` | `JSONB` | El "chain-of-thought" del agent en ese step: estructura libre, puede incluir sub-pasos, tools invocadas, resultados intermedios |
| `tools_used` | `ARRAY(TEXT)` | Subconjunto de los tools del agent, usados en este step puntual |
| `occurred_at` | `TIMESTAMPTZ` | |

Esta es, probablemente, la tabla de mayor volumen de todo el sistema (cada execution puede generar muchos steps). El campo `reasoning` es el ejemplo más claro de por qué se necesita `JSONB`: el "pensamiento" de un agent no tiene una forma fija, columna por columna.

**Índices recomendados**:
- `(execution_id, step_number)` — para reconstruir la secuencia completa de una execution en orden.
- Un índice `GIN` sobre `reasoning` si se necesita buscar dentro del contenido del JSON (por ejemplo, "steps donde se usó tal tool según el reasoning").

### `token_costs`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | Clave primaria |
| `execution_id` | `UUID` | FK → `executions.id` |
| `step_id` | `UUID` | FK → `execution_steps.id`, nulo si el costo es a nivel de execution completa |
| `input_tokens` | `INTEGER` | |
| `output_tokens` | `INTEGER` | |
| `estimated_cost` | `NUMERIC(10,4)` | En la moneda de referencia del sistema |
| `recorded_at` | `TIMESTAMPTZ` | |

**Índice recomendado**: `(execution_id)` — la consulta típica es "sumar el costo total de esta execution".

### `execution_errors`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | Clave primaria |
| `execution_id` | `UUID` | FK → `executions.id` |
| `step_id` | `UUID` | FK → `execution_steps.id`, nulo si el error es a nivel de execution completa |
| `error_type` | `TEXT` | |
| `message` | `TEXT` | |
| `severity` | `ENUM(error_severity)` | `low`, `medium`, `high`, `critical` |
| `occurred_at` | `TIMESTAMPTZ` | |

**Índice recomendado**: `(execution_id)`, y `(severity)` si se espera un panel de "errores críticos recientes".

### `audit_logs`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | Clave primaria |
| `company_id` | `UUID` | FK → `companies.id` |
| `user_id` | `UUID` | FK → `users.id` |
| `action` | `TEXT` | Ej: "create_agent", "update_swarm" |
| `entity_type` | `TEXT` | Nombre de la tabla/entidad afectada |
| `entity_id` | `UUID` | Id del registro afectado |
| `details` | `JSONB` | Datos adicionales del cambio (valores anteriores/nuevos, por ejemplo) |
| `occurred_at` | `TIMESTAMPTZ` | |

Al igual que `executions`, esta tabla crece indefinidamente y es candidata natural a **particionamiento por rango de fecha** sobre `occurred_at`. Es una tabla de solo inserción: nunca se actualiza ni se borra un registro existente.

**Índice recomendado**: `(company_id, occurred_at)`.

## Cómo se relacionan las tablas entre sí

```
companies
  ├── users
  ├── agents ──┐
  ├── swarms ───┼── swarm_agents (puente muchos-a-muchos)
  │       └── tasks
  │              └── executions
  │                     ├── execution_steps
  │                     ├── token_costs
  │                     └── execution_errors
  └── audit_logs
```

La forma del árbol refleja directamente los agregados descritos en `modeling.md`: `executions` es el nodo con más "hijos" porque es, ni más ni menos, el agregado más rico del dominio.

## Seguridad a nivel de fila (RLS)

Todas las tablas que tienen columna `company_id` (es decir, todas menos `swarm_agents`, que hereda el aislamiento a través de sus llaves foráneas) llevan una política de RLS que restringe el acceso únicamente a las filas cuya `company_id` coincide con la company del usuario autenticado. Esto convierte el aislamiento multi-tenant en una garantía de la propia base de datos, no en una responsabilidad que recae en cada consulta escrita a mano.

## Particionamiento

Las dos tablas de crecimiento indefinido — `executions` y `audit_logs` — se particionan por rango sobre su columna de fecha principal (`started_at` y `occurred_at`, respectivamente), con una partición por mes. Esto permite que las consultas que filtran por un rango de fechas (que son, en la práctica, casi todas las del dashboard) descarten de entrada las particiones irrelevantes, en vez de recorrer todo el historial acumulado.

## Sobre la normalización y las columnas JSONB/ARRAY

Como se explica en `concepts.md`, el uso de `JSONB` (en `config`, `reasoning` y `details`) y `ARRAY` (en `tools` y `tools_used`) es una decisión de diseño deliberada, no una violación descuidada de la normalización. Para la demostración formal de 1FN → 2FN → 3FN conviene apoyarse en tablas "limpias" como `companies`, `users` o `swarms`, dejando aparte, documentada, la justificación de por qué las columnas semi-estructuradas no comprometen la integridad del modelo.