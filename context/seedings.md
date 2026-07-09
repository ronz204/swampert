# Plan de seed de datos — Swampert

Objetivo: poblar la base con ~2 000 filas en las tres tablas de mayor volumen
(`tracer.execution_steps`, `tracer.executions`, `tracer.token_costs`) usando
PL/pgSQL puro, sin dependencias externas.

---

## Volúmenes objetivo

| Tabla                       | Filas  | Criterio                            |
|-----------------------------|--------|-------------------------------------|
| `core.tenants`              | 5      | raíz de todo el árbol               |
| `core.users`                | 20     | 4 por tenant                        |
| `core.agents`               | 30     | 6 por tenant                        |
| `core.swarms`               | 20     | 4 por tenant                        |
| `core.swarm_agents`         | ~60    | 3 agents por swarm                  |
| `core.tasks`                | 200    | 10 por swarm                        |
| `tracer.executions`         | ~400   | 2 por task en promedio              |
| `tracer.execution_steps`    | **~2 000** | 5 por execution en promedio     |
| `tracer.token_costs`        | ~600   | 1–2 por execution                   |
| `tracer.execution_errors`   | ~80    | solo executions fallidas (~20 %)    |
| `tracer.audit_logs`         | ~100   | acciones de usuarios distribuidas   |

Las tres tablas marcadas en negrita son las que cumplen el requisito R-11.

---

## Estrategia de resolución de FKs

El mayor problema de un seed multi-tabla es pasar los UUIDs generados a los
inserts siguientes. La solución: **tablas temporales como puente entre bloques**.

```sql
-- antes de los DO blocks
CREATE TEMP TABLE _seed_tenants  (id UUID);
CREATE TEMP TABLE _seed_users    (id UUID, tenant_id UUID);
CREATE TEMP TABLE _seed_agents   (id UUID, tenant_id UUID);
CREATE TEMP TABLE _seed_swarms   (id UUID, tenant_id UUID);
CREATE TEMP TABLE _seed_tasks    (id UUID, swarm_id UUID, tenant_id UUID);
CREATE TEMP TABLE _seed_execs    (id UUID, task_id UUID, tenant_id UUID, started_at TIMESTAMPTZ);
CREATE TEMP TABLE _seed_steps    (id UUID, execution_id UUID, tenant_id UUID);
```

Cada bloque `DO $$` lee la temp table del nivel anterior y escribe en la
del nivel actual. Las temp tables viven solo en la sesión, así que el seed
es idempotente si se ejecuta en una sesión limpia.

---

## Estructura del script: 3 bloques

Dividir en bloques hace que sea fácil detectar en cuál paso falla un error.

### Bloque 1 — catálogo base

Inserta: tenants → users → agents → swarms → swarm_agents → tasks

```sql
DO $$ BEGIN
  -- tenants
  INSERT INTO core.tenants (name, slug, plan, active)
  SELECT
    'Tenant ' || i,
    'tenant-' || i,
    (ARRAY['basic','pro','enterprise']::core.tenant_plan[])[1 + (random()*2)::int],
    true
  FROM generate_series(1, 5) i
  RETURNING id INTO ... -- guardar en _seed_tenants
```

Patrón para elegir un valor aleatorio de un array fijo:
```sql
(ARRAY['a','b','c'])[1 + (random() * 2)::int]
```

Patrón para asignar filas hijas distribuyendo entre padres:
```sql
-- para 20 users entre 5 tenants: asignar tenant por módulo
SELECT id FROM _seed_tenants
ORDER BY id  -- orden determinista
LIMIT 1 OFFSET (i % 5)
```

O con `ORDER BY random() LIMIT 1` cuando queremos distribución más orgánica
(no uniforme, más realista).

### Bloque 2 — executions

Punto crítico: `tracer.executions` está particionada por `started_at`.
Los valores deben caer dentro de las particiones existentes (2026-04 a 2026-09).

```sql
-- fecha aleatoria dentro del rango de particiones
'2026-04-01'::timestamptz + (random() * interval '180 days')
```

Una execution con status `completed` o `failed` debe tener `finished_at`:
```sql
started_at + (random() * interval '4 hours')
```

Una execution `pending` o `running` tiene `finished_at = NULL`.

### Bloque 3 — trazabilidad

Inserta: execution_steps → token_costs → execution_errors → audit_logs

Para execution_steps, cada fila necesita un `agent_id` del mismo tenant.
Patrón:
```sql
SELECT id FROM _seed_agents
WHERE tenant_id = exec.tenant_id
ORDER BY random()
LIMIT 1
```

Para `token_costs`, calcular `estimated_cost` en base a los tokens:
```sql
input_tokens  := (100  + random() * 3900)::int,
output_tokens := (50   + random() * 950)::int,
estimated_cost := round((input_tokens * 0.000003 + output_tokens * 0.000015)::numeric, 4)
```

Para `execution_errors`, insertar solo para executions con status `failed`:
```sql
WHERE status = 'failed'
```

Para `audit_logs`, distribuir `occurred_at` dentro del mismo rango de
particiones (2026-04 a 2026-09).

---

## Distribuciones de estados (realistas)

### `core.tasks.status`
| Estado      | % aprox |
|-------------|---------|
| `pending`   | 15 %    |
| `progress`  | 10 %    |
| `completed` | 60 %    |
| `failed`    | 15 %    |

Patrón:
```sql
CASE
  WHEN r < 0.15 THEN 'pending'
  WHEN r < 0.25 THEN 'progress'
  WHEN r < 0.85 THEN 'completed'
  ELSE 'failed'
END::core.task_status
-- donde r = random()
```

### `tracer.executions.status`
| Estado      | % aprox |
|-------------|---------|
| `pending`   | 10 %    |
| `running`   | 10 %    |
| `completed` | 60 %    |
| `failed`    | 20 %    |

---

## Valores de dominio para datos realistas

### Roles de agentes (`core.agents.role`)
```
orchestrator, researcher, validator, summarizer, executor, coordinator
```

### Modelos base (`core.agents.base_model`)
```
gpt-4o, claude-3-5-sonnet, gemini-1.5-pro, llama-3.1-70b, mistral-large
```

### Herramientas (`core.agents.tools` — TEXT[])
```
web_search, code_interpreter, file_reader, api_caller,
data_analyzer, image_describer, sql_executor
```
Asignar subsets de 2-4 herramientas por agente usando slices de un array fijo.

### Títulos de tasks
```sql
(ARRAY[
  'Analyze market trends',
  'Generate quarterly report',
  'Summarize research papers',
  'Validate dataset integrity',
  'Extract KPIs from logs',
  'Classify support tickets',
  'Draft executive summary',
  'Audit configuration changes',
  'Benchmark model responses',
  'Detect anomalies in metrics'
])[1 + (random() * 9)::int]
|| ' #' || i
```

---

## Consideraciones para CLUSTER + EXPLAIN ANALYZE

Con 2 000 filas en `execution_steps` distribuidas entre ~400 executions:
- cada execution tiene ~5 steps en promedio
- sin CLUSTER, esos 5 steps están dispersos en el heap → múltiples page fetches
- después de `CLUSTER tracer.execution_steps USING execution_steps_execution_id_step_number_idx`,
  los 5 steps de cada execution son una secuencia contigua → un solo range scan

Esto es suficiente volumen para que `EXPLAIN ANALYZE` muestre la diferencia
entre `Seq Scan` y `Index Scan` con una reducción de costo visible. Con 10 000
filas el delta sería más dramático, pero 2 000 alcanza para el entregable.

---

## Nombre del archivo de migración

```
0017-seed.sql
```

Se implementa como una migración más para que el migrator la registre y no se
aplique dos veces. El seed debe poder correrse en una base vacía (después de
`0016-clustering.sql`) o en una que ya tenga el esquema pero sin datos.

