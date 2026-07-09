# Swampert — Consultas optimizadas (R-10 / R-13)

Las cinco consultas de este documento satisfacen simultáneamente R-10 (mínimo 3
consultas con tratamiento completo de rendimiento) y R-13 (mínimo 5 consultas
tipo reporte con visualización). Cada una involucra 3 o más tablas, está
respaldada por un índice, y debe acompañarse de `EXPLAIN ANALYZE` antes/después
con reducción de costo documentada.

Son también las mismas consultas que alimentan el dashboard (pantalla 1) y la
vista de consultas con filtros (pantalla 2).

| # | Nombre | Índice demostrado | Chart |
|---|---|---|---|
| Q1 | Top ejecuciones por costo | `token_costs(execution_id)` CLUSTER | Bar |
| Q2 | Tasa de éxito por swarm | `tasks(tenant_id, status)` CLUSTER | Donut |
| Q3 | Actividad de agentes | `execution_steps(execution_id, step_number)` CLUSTER | Bar |
| Q4 | Timeline de ejecuciones por mes | `executions(tenant_id, started_at)` B-Tree | Line |
| Q5 | Tareas con mayor incidencia de errores | `execution_errors(severity)` B-Tree | Bar |

---

## Q1 — Top ejecuciones por costo total

**Propósito:** agregar el gasto en tokens de cada ejecución y ordenar
descendentemente. Alimenta el KPI de costo total y el bar chart de las
ejecuciones más caras.

**Tablas:** `tracer.token_costs` · `tracer.executions` · `core.tasks`

**Índice demostrado:** `token_costs_execution_id_idx` (CLUSTER)
→ todas las filas de costo de una misma ejecución son un bloque físico contiguo,
lo que convierte la agregación por `execution_id` de múltiples heap-fetches
dispersos en un único range scan.

```sql
SELECT
  t.title                                         AS tarea,
  e.status,
  e.started_at,
  SUM(tc.input_tokens + tc.output_tokens)         AS total_tokens,
  SUM(tc.estimated_cost)                          AS costo_total
FROM tracer.token_costs   tc
JOIN tracer.executions    e  ON e.id  = tc.execution_id
JOIN core.tasks           t  ON t.id  = e.task_id
GROUP BY e.id, e.status, e.started_at, t.title
ORDER BY costo_total DESC
LIMIT 20;
```

**Filtros disponibles en pantalla 2:** estado de la ejecución, rango de fechas,
título de la tarea.

---

## Q2 — Tasa de éxito por swarm

**Propósito:** contar ejecuciones completadas vs fallidas agrupadas por swarm
y calcular el porcentaje de éxito. Alimenta el donut chart de rendimiento
y el KPI de tasa global de éxito.

**Tablas:** `core.swarms` · `core.tasks` · `tracer.executions`

**Índice demostrado:** `tasks_tenant_id_status_idx` (CLUSTER) +
`executions_task_id_idx`
→ el cluster agrupa las tareas del mismo tenant en disco; combinado con el
índice sobre `task_id` en executions, el JOIN y el GROUP BY escanean páginas
contiguas en lugar de saltar el heap aleatoriamente.

```sql
SELECT
  s.name                                                      AS swarm,
  COUNT(DISTINCT t.id)                                        AS total_tareas,
  COUNT(e.id) FILTER (WHERE e.status = 'completed')          AS completadas,
  COUNT(e.id) FILTER (WHERE e.status = 'failed')             AS fallidas,
  round(
    COUNT(e.id) FILTER (WHERE e.status = 'completed') * 100.0
    / NULLIF(COUNT(e.id), 0),
  1)                                                          AS tasa_exito
FROM core.swarms          s
JOIN core.tasks           t  ON t.swarm_id = s.id
JOIN tracer.executions    e  ON e.task_id  = t.id
GROUP BY s.id, s.name
ORDER BY tasa_exito DESC NULLS LAST;
```

**Filtros disponibles en pantalla 2:** nombre del swarm, estado de la
ejecución.

---

## Q3 — Actividad de agentes por ejecución

**Propósito:** contar steps ejecutados por cada agente, el promedio de tokens
utilizados por step y la fecha de última actividad. Alimenta el bar chart
de agentes más activos.

**Tablas:** `tracer.execution_steps` · `core.agents` · `tracer.executions`

**Índice demostrado:** `execution_steps_execution_id_step_number_idx` (CLUSTER)
→ después del CLUSTER, los 5 steps de cada ejecución son una secuencia física
contigua en disco. El JOIN con executions por `execution_id` se convierte en un
range scan compacto en lugar de heap-fetches dispersos.

```sql
SELECT
  a.name                                                       AS agente,
  a.role,
  COUNT(es.id)                                                 AS total_steps,
  round(AVG((es.reasoning->>'tokens_used')::int), 0)          AS tokens_promedio,
  MAX(e.started_at)                                            AS ultima_actividad
FROM tracer.execution_steps  es
JOIN core.agents             a  ON a.id = es.agent_id
JOIN tracer.executions       e  ON e.id = es.execution_id
GROUP BY a.id, a.name, a.role
ORDER BY total_steps DESC;
```

**Filtros disponibles en pantalla 2:** rol del agente, modelo base.

---

---

## Q4 — Timeline de ejecuciones por mes

**Propósito:** contar ejecuciones agrupadas por mes y swarm, desglosadas por
estado. Alimenta el line chart de tendencia de carga de trabajo en el tiempo.

**Tablas:** `tracer.executions` · `core.tasks` · `core.swarms`

**Índice demostrado:** `executions_tenant_id_started_at_idx` (B-Tree)
→ el índice compuesto sobre `(tenant_id, started_at)` permite que el planner
haga un index range scan al filtrar por rango de fechas, evitando un Seq Scan
completo sobre todas las particiones.

```sql
SELECT
  date_trunc('month', e.started_at)                      AS mes,
  s.name                                                  AS swarm,
  COUNT(e.id) FILTER (WHERE e.status = 'completed')      AS completadas,
  COUNT(e.id) FILTER (WHERE e.status = 'failed')         AS fallidas,
  COUNT(e.id) FILTER (WHERE e.status = 'running')        AS en_curso,
  COUNT(e.id)                                             AS total
FROM tracer.executions  e
JOIN core.tasks         t  ON t.id = e.task_id
JOIN core.swarms        s  ON s.id = t.swarm_id
GROUP BY date_trunc('month', e.started_at), s.id, s.name
ORDER BY mes, total DESC;
```

**Filtros disponibles en pantalla 2:** rango de fechas, nombre del swarm,
estado de la ejecución.

---

## Q5 — Tareas con mayor incidencia de errores

**Propósito:** identificar las tareas que concentran más errores, agrupadas por
severidad y tipo. Alimenta el bar chart de confiabilidad del sistema.

**Tablas:** `tracer.execution_errors` · `tracer.executions` · `core.tasks`

**Índice demostrado:** `execution_errors_severity_idx` (B-Tree)
→ el filtro `WHERE severity IN ('high', 'critical')` usa el índice B-Tree sobre
`severity`, evitando escanear los errores de baja prioridad. Sin el índice el
planner lee la tabla entera; con él descarta las particiones de baja severidad.

```sql
SELECT
  t.title                             AS tarea,
  ee.severity,
  ee.error_type,
  COUNT(ee.id)                        AS total_errores,
  COUNT(DISTINCT ee.execution_id)     AS execuciones_afectadas
FROM tracer.execution_errors   ee
JOIN tracer.executions         e   ON e.id = ee.execution_id
JOIN core.tasks                t   ON t.id = e.task_id
WHERE ee.severity IN ('high', 'critical')
GROUP BY t.title, ee.severity, ee.error_type
ORDER BY total_errores DESC
LIMIT 15;
```

**Filtros disponibles en pantalla 2:** severidad, tipo de error, título de la
tarea.

---

## Procedimiento para capturar EXPLAIN ANALYZE (R-09 + R-10)

Para documentar la reducción de costo antes/después del CLUSTER, el flujo es:

```sql
-- 1. Capturar plan SIN cluster (simular heap desordenado)
SET enable_indexscan = off;
EXPLAIN ANALYZE <query>;
RESET enable_indexscan;

-- 2. Aplicar CLUSTER con datos ya cargados (después de 0017-seeders.sql)
CLUSTER core.tasks                USING tasks_tenant_id_status_idx;
CLUSTER tracer.execution_steps    USING execution_steps_execution_id_step_number_idx;
CLUSTER tracer.token_costs        USING token_costs_execution_id_idx;
ANALYZE core.tasks;
ANALYZE tracer.execution_steps;
ANALYZE tracer.token_costs;

-- 3. Capturar plan CON cluster
EXPLAIN ANALYZE <query>;
```

La reducción de costo se calcula como:
`((costo_sin - costo_con) / costo_sin) * 100`
