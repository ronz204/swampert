# API Contracts — Swampert

## Transporte y multi-tenancy

La API corre en `http://localhost:8000` en desarrollo. El tenant se identifica **exclusivamente por subdominio**: toda request debe llegar con un Host que tenga un slug como prefijo.

```
http://<slug>.localhost:8000/<endpoint>
```

Si el slug falta o el tenant no existe, la API responde antes de llegar al endpoint:

| Condición | Status | Body |
|---|---|---|
| Host sin subdominio (`localhost`) | `400` | `{"detail": "tenant no especificado — accedé con subdominio: <slug>.localhost"}` |
| Slug no encontrado en la DB | `404` | `{"detail": "tenant '<slug>' no encontrado"}` |

Todas las queries corren bajo RLS con el `tenant_id` resuelto — nunca se filtran datos manualmente en código.

---

## Endpoints

### GET `/dashboard/kpis`

Los cuatro indicadores escalares del Dashboard. Todas las métricas reflejan el
mismo rango de tiempo para garantizar coherencia visual entre las tarjetas KPI.
Cuando no se envía rango, el sistema usa las últimas 24 horas como ventana.

**Query params**

| Param | Tipo | Default | Descripción |
|---|---|---|---|
| `from_date` | `string` | `NOW() - 24h` | Límite inferior inclusivo — formato `YYYY-MM-DD` |
| `to_date` | `string` | `NOW()` | Límite superior exclusivo — formato `YYYY-MM-DD` |

**Respuesta** `200 application/json` — objeto único:

| Campo | Tipo | Notas |
|---|---|---|
| `executions_count` | `integer` | Ejecuciones iniciadas en el rango |
| `total_cost` | `number` | Suma de `estimated_cost` en USD, con precisión decimal |
| `error_rate` | `number \| null` | Porcentaje de ejecuciones fallidas (1 decimal) · `null` si no hay ejecuciones |
| `active_agents` | `integer` | Agentes distintos con al menos un step en el rango |

---

### GET `/agents/activity`

Actividad agregada por agente: pasos ejecutados, tokens promedio y última actividad.

**Query params**

| Param | Tipo | Default | Descripción |
|---|---|---|---|
| `role` | `string` | — | Filtra exacto por rol del agente |

**Respuesta** `200 application/json` — array de:

| Campo | Tipo | Notas |
|---|---|---|
| `agent_id` | `uuid` | |
| `agente` | `string` | nombre del agente |
| `role` | `string` | |
| `total_steps` | `integer` | |
| `tokens_promedio` | `number \| null` | `null` si no hay steps con tokens registrados |
| `ultima_actividad` | `datetime \| null` | ISO 8601 con timezone |

---

### GET `/executions/cost`

Top de executions ordenadas por costo total de tokens descendente.

**Query params**

| Param | Tipo | Default | Descripción |
|---|---|---|---|
| `limit` | `integer` | `20` | Máximo de filas retornadas |
| `status` | `string` | — | Filtra por status exacto: `pending` · `running` · `completed` · `failed` |
| `from_date` | `string` | — | Límite inferior inclusivo de `started_at` — formato `YYYY-MM-DD` |
| `to_date` | `string` | — | Límite superior exclusivo de `started_at` — formato `YYYY-MM-DD` |

**Respuesta** `200 application/json` — array de:

| Campo | Tipo | Notas |
|---|---|---|
| `tarea` | `string` | título de la task |
| `execution_id` | `uuid` | |
| `status` | `string` | `pending` · `running` · `completed` · `failed` |
| `started_at` | `datetime` | ISO 8601 con timezone |
| `total_tokens` | `integer` | suma de input + output tokens |
| `costo_total` | `number` | decimal con precisión monetaria |

---

### GET `/executions/timeline`

Executions agrupadas por mes y swarm. Útil para gráficos de línea.

**Query params**

| Param | Tipo | Default | Descripción |
|---|---|---|---|
| `swarm` | `string` | — | Búsqueda parcial case-insensitive por nombre de swarm |
| `status` | `string` | — | Filtra por status exacto: `pending` · `running` · `completed` · `failed` |
| `from_date` | `string` | — | Límite inferior de `started_at` — formato `YYYY-MM-DD` |
| `to_date` | `string` | — | Límite superior exclusivo de `started_at` — formato `YYYY-MM-DD` |

**Respuesta** `200 application/json` — array de:

| Campo | Tipo | Notas |
|---|---|---|
| `mes` | `datetime` | primer día del mes, ISO 8601 |
| `swarm` | `string` | nombre del swarm |
| `completadas` | `integer` | |
| `fallidas` | `integer` | |
| `en_curso` | `integer` | status `running` |
| `total` | `integer` | suma de todos los status |

---

### GET `/swarms/success-rate`

Tasa de éxito por swarm: completadas vs fallidas sobre el total de executions.

**Query params**

| Param | Tipo | Default | Descripción |
|---|---|---|---|
| `name` | `string` | — | Búsqueda parcial case-insensitive por nombre de swarm |

**Respuesta** `200 application/json` — array de:

| Campo | Tipo | Notas |
|---|---|---|
| `swarm_id` | `uuid` | |
| `swarm` | `string` | nombre del swarm |
| `total_tareas` | `integer` | tasks distintas asignadas |
| `completadas` | `integer` | executions con status `completed` |
| `fallidas` | `integer` | executions con status `failed` |
| `tasa_exito` | `number \| null` | porcentaje con 1 decimal · `null` si no hay executions |

Ordenado por `tasa_exito DESC NULLS LAST`.

---

### GET `/swarms/cost`

Costo total agregado por swarm. Alimenta el bar chart "Costo por swarm" del
Dashboard (pantalla 1) — ver `uidesign.md`.

**Query params**

| Param | Tipo | Default | Descripción |
|---|---|---|---|
| `from_date` | `string` | — | Límite inferior inclusivo de `started_at` — formato `YYYY-MM-DD` |
| `to_date` | `string` | — | Límite superior exclusivo de `started_at` — formato `YYYY-MM-DD` |

**Respuesta** `200 application/json` — array de:

| Campo | Tipo | Notas |
|---|---|---|
| `swarm_id` | `uuid` | |
| `swarm` | `string` | nombre del swarm |
| `costo_total` | `number` | suma de `estimated_cost` en USD de las ejecuciones del swarm en el rango |

Ordenado por `costo_total DESC`.

---

### GET `/errors/top`

Top de errores agrupados por tarea, severidad y tipo. Por defecto muestra solo `high` y `critical`.

**Query params**

| Param | Tipo | Default | Descripción |
|---|---|---|---|
| `severity` | `string[]` | — | Multi-valor: `low` · `medium` · `high` · `critical`. Sin este param aplica default `high` + `critical` |
| `error_type` | `string` | — | Búsqueda parcial case-insensitive por tipo de error |
| `task` | `string` | — | Búsqueda parcial case-insensitive por título de task |
| `limit` | `integer` | `15` | Máximo de filas retornadas |

> `severity` acepta múltiples valores: `?severity=critical&severity=high`

**Respuesta** `200 application/json` — array de:

| Campo | Tipo | Notas |
|---|---|---|
| `tarea` | `string` | título de la task |
| `severity` | `string` | `low` · `medium` · `high` · `critical` |
| `error_type` | `string` | |
| `total_errores` | `integer` | ocurrencias del error |
| `execuciones_afectadas` | `integer` | executions distintas con ese error |

Ordenado por `total_errores DESC`.
