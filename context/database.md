# Swampert — Modelado de persistencia

> Nota de alcance: este documento traduce el modelo de dominio (`modeling.md`) a su forma concreta de **tablas en PostgreSQL**: qué columnas tiene cada una, qué tipo de dato usar (con su sintaxis real de Postgres), cómo se relacionan entre sí (y de qué tipo es cada relación), dónde van los índices y cómo se particiona lo que crece sin límite. No cubre la arquitectura de la aplicación (backend, API, frontend) — solo la base de datos en sí.


## Esquemas lógicos

Swampert usa **dos esquemas de dominio**, más un tercero de infraestructura que no cuenta contra el modelo de negocio:

- **`core`** — todo lo que configura el sistema y cambia con poca frecuencia: `tenants`, `users`, `agents`, `swarms`, `swarm_agents`, `tasks`.
- **`tracer`** — todo lo que el sistema genera al operar: alto volumen, crecimiento indefinido, y los datos candidatos a particionamiento por fecha: `executions`, `execution_steps`, `token_costs`, `execution_errors`, `audit_logs`.
- **`meta`** — infraestructura del propio mecanismo de migraciones (`meta.migrations`), no es parte del dominio y no cuenta contra el mínimo de tablas sustantivas del proyecto.

La justificación del corte `core`/`tracer` es la misma que ya está documentada en `modeling.md`: separa "lo que configura el sistema" (cambia poco, bajo volumen) de "lo que el sistema genera al operar" (alto volumen, se particiona, se traza). Cada tabla en este documento se referencia con su esquema (`core.tenants`, `tracer.executions`, etc.).

## Vista general de las tablas

Swampert se modela con diez tablas sustantivas (más una tabla puente de relación muchos-a-muchos). En orden, desde lo más estable hasta lo más volátil:

1. `core.tenants`
2. `core.users`
3. `core.agents`
4. `core.swarms`
5. `core.swarm_agents` (tabla puente)
6. `core.tasks`
7. `tracer.executions`
8. `tracer.execution_steps`
9. `tracer.token_costs`
10. `tracer.execution_errors`
11. `tracer.audit_logs`

## Convenciones generales

Antes de entrar tabla por tabla, algunas convenciones que aplican a todo el esquema:

- **Clave primaria**: todas las tablas usan `UUID` como clave primaria (columna `id`), generado en el momento de la inserción con `gen_random_uuid()` (provista por `pgcrypto`, ya habilitada para el cifrado de `password`). Se elige `UUID` en vez de un entero autoincremental porque, al ser un sistema donde distintos procesos pueden crear registros de forma concurrente (varios agents escribiendo steps al mismo tiempo, por ejemplo), un identificador que no depende de una secuencia centralizada evita cuellos de botella y colisiones.
- **Aislamiento por tenant**: toda tabla cuyo contenido pertenece a un tenant específico tiene una columna `tenant_id UUID` (referenciando a `core.tenants.id`), y esa columna es la base sobre la que se aplican las políticas de *Row-Level Security*. Esto se aplica **sin excepciones**, incluso en tablas donde `tenant_id` podría inferirse indirectamente (por ejemplo, a través de `execution_id` → `tracer.executions.tenant_id`): se duplica intencionalmente para que las políticas de seguridad y los índices de filtrado no dependan de un `JOIN`.
- **Timestamps**: toda tabla tiene como mínimo `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`. Las tablas cuyo estado cambia con el tiempo (como `tracer.executions`) también tienen `updated_at TIMESTAMPTZ`.
- **Estados como ENUM**: cualquier columna que representa un conjunto cerrado de valores posibles (estados, roles, severidades) se modela como un tipo `ENUM` propio de PostgreSQL (`CREATE TYPE ... AS ENUM (...)`), nunca como texto libre. Los tipos ENUM viven en el mismo esquema que la tabla que los usa (ej. `core.tenant_plan`, `tracer.execution_status`).
- **Extensión `pgcrypto`**: se habilita una única vez con `CREATE EXTENSION IF NOT EXISTS pgcrypto;`, como parte del primer paso de las migraciones (`0001-extensions.sql`), antes de crear cualquier esquema o tabla del dominio. Se usa en dos frentes: `gen_random_uuid()` para las claves primarias, y `crypt()` / `gen_salt('bf')` para el campo `password` de `core.users`.

## Tipos ENUM del modelo

```sql
-- esquema core
CREATE TYPE core.tenant_plan   AS ENUM ('basic', 'pro', 'enterprise');
CREATE TYPE core.user_role     AS ENUM ('admin', 'member', 'viewer');
CREATE TYPE core.swarm_status  AS ENUM ('active', 'paused', 'archived');
CREATE TYPE core.task_status   AS ENUM ('pending', 'progress', 'completed', 'failed');
CREATE TYPE core.task_priority AS ENUM ('low', 'medium', 'high');

-- esquema tracer
CREATE TYPE tracer.execution_status AS ENUM ('pending', 'running', 'completed', 'failed');
CREATE TYPE tracer.error_severity   AS ENUM ('low', 'medium', 'high', 'critical');
```

## Tabla por tabla

### `core.tenants`

| Columna | Tipo Postgres | Notas |
|---|---|---|
| `id` | `UUID` | PK, default `gen_random_uuid()` |
| `name` | `TEXT` | |
| `slug` | `TEXT` | `UNIQUE` — identifica al tenant como subdominio (ej: "acme" → acme.swampert.io) |
| `plan` | `core.tenant_plan` | ENUM |
| `active` | `BOOLEAN` | Default `true` |
| `created_at` | `TIMESTAMPTZ` | Default `now()` |

Es la tabla raíz de todo el esquema: todas las demás tablas, directa o indirectamente, cuelgan de acá.

### `core.users`

| Columna | Tipo Postgres | Notas |
|---|---|---|
| `id` | `UUID` | PK, default `gen_random_uuid()` |
| `tenant_id` | `UUID` | FK → `core.tenants.id` |
| `name` | `TEXT` | |
| `email` | `TEXT` | `UNIQUE` |
| `password` | `TEXT` | Generado con `pgcrypto` (`crypt(texto, gen_salt('bf'))`). Nunca en texto plano ni MD5. |
| `role` | `core.user_role` | ENUM |
| `active` | `BOOLEAN` | Default `true` |
| `created_at` | `TIMESTAMPTZ` | Default `now()` |

**Relación**: `core.tenants` 1 — N `core.users`.

**Índice recomendado**: `(tenant_id)`.

### `core.agents`

| Columna | Tipo Postgres | Notas |
|---|---|---|
| `id` | `UUID` | PK, default `gen_random_uuid()` |
| `tenant_id` | `UUID` | FK → `core.tenants.id` |
| `name` | `TEXT` | |
| `role` | `TEXT` | Ej: "researcher", "writer", "reviewer" |
| `base_model` | `TEXT` | Ej: "model-x-v2" (dato descriptivo, no se valida contra un proveedor real) |
| `tools` | `TEXT[]` | Lista de herramientas que el agent tiene disponibles |
| `config` | `JSONB` | Parámetros libres de configuración (instrucciones, límites, etc.) |
| `active` | `BOOLEAN` | Default `true` |
| `created_at` | `TIMESTAMPTZ` | Default `now()` |

**Relación**: `core.tenants` 1 — N `core.agents`.

**Por qué `TEXT[]` y `JSONB` acá**: la lista de tools es naturalmente una lista corta y homogénea (por eso `TEXT[]` alcanza), mientras que `config` es heterogénea y puede variar de agent a agent (por eso conviene `JSONB`, que no obliga a un esquema fijo de columnas).

**Índice recomendado**: `(tenant_id)`, y un índice `GIN` sobre `config` si se espera filtrar agents por algún parámetro específico dentro del JSON.

### `core.swarms`

| Columna | Tipo Postgres | Notas |
|---|---|---|
| `id` | `UUID` | PK, default `gen_random_uuid()` |
| `tenant_id` | `UUID` | FK → `core.tenants.id` |
| `name` | `TEXT` | |
| `description` | `TEXT` | |
| `status` | `core.swarm_status` | ENUM |
| `created_at` | `TIMESTAMPTZ` | Default `now()` |

**Relación**: `core.tenants` 1 — N `core.swarms`.

**Índice recomendado**: `(tenant_id, status)` — el dashboard casi siempre pide "los swarms activos de este tenant".

### `core.swarm_agents` (tabla puente)

| Columna | Tipo Postgres | Notas |
|---|---|---|
| `swarm_id` | `UUID` | FK → `core.swarms.id` |
| `agent_id` | `UUID` | FK → `core.agents.id` |
| `added_at` | `TIMESTAMPTZ` | Default `now()` |

Clave primaria compuesta: `PRIMARY KEY (swarm_id, agent_id)`.

**Relación**: `core.swarms` N — M `core.agents`, resuelta como dos relaciones 1 — N contra la tabla puente. Al ser una tabla puente pura, no cuenta dentro de las "diez tablas sustantivas" del modelo.

### `core.tasks`

| Columna | Tipo Postgres | Notas |
|---|---|---|
| `id` | `UUID` | PK, default `gen_random_uuid()` |
| `tenant_id` | `UUID` | FK → `core.tenants.id` |
| `swarm_id` | `UUID` | FK → `core.swarms.id` |
| `title` | `TEXT` | |
| `description` | `TEXT` | |
| `status` | `core.task_status` | ENUM |
| `priority` | `core.task_priority` | ENUM |
| `created_at` | `TIMESTAMPTZ` | Default `now()` |

**Relaciones**: `core.tenants` 1 — N `core.tasks`; `core.swarms` 1 — N `core.tasks`.

**Índice recomendado**: `(tenant_id, status)` y `(swarm_id)`.

### `tracer.executions`

| Columna | Tipo Postgres | Notas |
|---|---|---|
| `id` | `UUID` | PK, default `gen_random_uuid()` |
| `tenant_id` | `UUID` | FK → `core.tenants.id` |
| `task_id` | `UUID` | FK → `core.tasks.id` |
| `attempt_number` | `INTEGER` | 1, 2, 3... para reintentos de la misma task |
| `status` | `tracer.execution_status` | ENUM |
| `started_at` | `TIMESTAMPTZ` | |
| `finished_at` | `TIMESTAMPTZ` | Nulo mientras está en curso |

**Relaciones**: `core.tenants` 1 — N `tracer.executions`; `core.tasks` 1 — N `tracer.executions`.

Candidata a **particionamiento por rango de fecha** sobre `started_at`.

**Índices recomendados**:
- `(tenant_id, started_at)` — filtro más común del dashboard.
- `(task_id)` — para reconstruir el historial de intentos de una task.
- `(status)` — para vistas tipo "todas las executions fallidas".

### `tracer.execution_steps`

| Columna | Tipo Postgres | Notas |
|---|---|---|
| `id` | `UUID` | PK, default `gen_random_uuid()` |
| `tenant_id` | `UUID` | FK → `core.tenants.id`. Denormalizado desde `tracer.executions.tenant_id`. |
| `execution_id` | `UUID` | FK → `tracer.executions.id` |
| `agent_id` | `UUID` | FK → `core.agents.id` |
| `step_number` | `INTEGER` | Orden dentro de la execution |
| `reasoning` | `JSONB` | El "chain-of-thought" del agent en ese step: estructura libre |
| `tools_used` | `TEXT[]` | Subconjunto de los tools del agent, usados en este step puntual |
| `occurred_at` | `TIMESTAMPTZ` | Default `now()` |

**Relaciones**: `tracer.executions` 1 — N `tracer.execution_steps`; `core.agents` 1 — N `tracer.execution_steps`.

**Índices recomendados**:
- `(tenant_id)` — para que RLS se resuelva sin `JOIN`.
- `(execution_id, step_number)` — para reconstruir la secuencia completa en orden.
- Índice `GIN` sobre `reasoning` si se necesita buscar dentro del JSON.

### `tracer.token_costs`

| Columna | Tipo Postgres | Notas |
|---|---|---|
| `id` | `UUID` | PK, default `gen_random_uuid()` |
| `tenant_id` | `UUID` | FK → `core.tenants.id`. Denormalizado desde `tracer.executions.tenant_id`. |
| `execution_id` | `UUID` | FK → `tracer.executions.id` |
| `step_id` | `UUID` | FK → `tracer.execution_steps.id`, nulo si el costo es a nivel de execution completa |
| `input_tokens` | `INTEGER` | |
| `output_tokens` | `INTEGER` | |
| `estimated_cost` | `NUMERIC(10,4)` | En la moneda de referencia del sistema |
| `recorded_at` | `TIMESTAMPTZ` | Default `now()` |

**Índices recomendados**: `(tenant_id)` para RLS, y `(execution_id)`.

### `tracer.execution_errors`

| Columna | Tipo Postgres | Notas |
|---|---|---|
| `id` | `UUID` | PK, default `gen_random_uuid()` |
| `tenant_id` | `UUID` | FK → `core.tenants.id`. Denormalizado desde `tracer.executions.tenant_id`. |
| `execution_id` | `UUID` | FK → `tracer.executions.id` |
| `step_id` | `UUID` | FK → `tracer.execution_steps.id`, nulo si el error es a nivel de execution completa |
| `error_type` | `TEXT` | |
| `message` | `TEXT` | |
| `severity` | `tracer.error_severity` | ENUM |
| `occurred_at` | `TIMESTAMPTZ` | Default `now()` |

**Índices recomendados**: `(tenant_id)` para RLS, `(execution_id)`, y `(severity)`.

### `tracer.audit_logs`

| Columna | Tipo Postgres | Notas |
|---|---|---|
| `id` | `UUID` | PK, default `gen_random_uuid()` |
| `tenant_id` | `UUID` | FK → `core.tenants.id` |
| `user_id` | `UUID` | FK → `core.users.id` |
| `action` | `TEXT` | Ej: "create_agent", "update_swarm" |
| `entity_type` | `TEXT` | Nombre de la tabla/entidad afectada |
| `entity_id` | `UUID` | Id del registro afectado |
| `details` | `JSONB` | Datos adicionales del cambio (valores anteriores/nuevos, por ejemplo) |
| `occurred_at` | `TIMESTAMPTZ` | Default `now()` |

Tabla de solo inserción: nunca se actualiza ni se borra un registro existente. Candidata a **particionamiento por rango de fecha** sobre `occurred_at`.

**Índice recomendado**: `(tenant_id, occurred_at)`.

## Cómo se relacionan las tablas entre sí

```
core.tenants
  ├── core.users ──────────────────────────────────── (1—N)
  ├── core.agents ──┐ ────────────────────────────────(1—N)
  ├── core.swarms ───┼── core.swarm_agents (N—M)       (1—N cada lado)
  │       └── core.tasks ─────────────────────────────(1—N)
  │              └── tracer.executions ────────────────(1—N)
  │                     ├── tracer.execution_steps ─────(1—N; + core.agents 1—N)
  │                     ├── tracer.token_costs ─────────(1—N; opcional a step)
  │                     └── tracer.execution_errors ────(1—N; opcional a step)
  └── tracer.audit_logs ───────────────────────────────(1—N; + core.users 1—N)
```

Todas las relaciones del modelo son **1 — N**, con una única excepción **N — M** (`core.swarms` ↔ `core.agents`), resuelta mediante la tabla puente `core.swarm_agents`.

## Seguridad a nivel de fila (RLS)

Todas las tablas del dominio excepto `core.swarm_agents` tienen columna `tenant_id` propia (nueve tablas: `core.users`, `core.agents`, `core.swarms`, `core.tasks`, `tracer.executions`, `tracer.execution_steps`, `tracer.token_costs`, `tracer.execution_errors`, `tracer.audit_logs`), y todas llevan una política de RLS que restringe el acceso a las filas cuya `tenant_id` coincide con el tenant autenticado (vía `current_setting('app.tenant_id')`). `core.swarm_agents` hereda el aislamiento a través de sus llaves foráneas.

## Particionamiento

`tracer.executions` (por `started_at`) y `tracer.audit_logs` (por `occurred_at`) se particionan por rango mensual. Son las únicas tablas de crecimiento ilimitado.

## Sobre la normalización y las columnas JSONB/ARRAY

El uso de `JSONB` (en `config`, `reasoning` y `details`) y `TEXT[]` (en `tools` y `tools_used`) es una decisión de diseño deliberada. Para la demostración formal de 1FN → 2FN → 3FN conviene apoyarse en tablas "limpias" como `core.tenants`, `core.users` o `core.swarms`.
