# Swampert — KPIs del dashboard

Cuatro indicadores escalares que se muestran en la fila de tarjetas del Dashboard
(pantalla 1). Cada KPI es una agregación derivada de las mismas queries documentadas
en `sqlqueries.md` — no requieren nuevas tablas ni nuevos índices, solo una nueva
función `kpis.py` en `source/database/functions/` que consolide las cuatro en una
sola llamada.

| ID | Nombre visible | Query fuente | Color token | Formato |
|---|---|---|---|---|
| K1 | Ejecuciones (24 h) | Q4 `ExecutionsByMonth` | `--color-current` | entero |
| K2 | Costo total | Q1 `TopByCost` | `--color-ledger` | `$0.00` |
| K3 | Tasa de error | Q2 `SwarmSuccessRate` | `--color-alarm` | `0.0%` |
| K4 | Agentes activos | Q3 `AgentActivity` | `--color-ink` | entero |

---

## K1 — Ejecuciones en las últimas 24 h

**Propósito:** mide la actividad reciente del sistema. Es el primer dato que un
operador necesita: ¿hay trabajo en curso ahora mismo?

**Fuente:** `tracer.executions`, filtrando `started_at >= NOW() - INTERVAL '24h'`.
Q4 (`ExecutionsByMonth`) agrupa por mes; para K1 se usa la misma tabla con un
filtro de ventana diaria, sin agrupar.

**Cálculo:**
```sql
SELECT COUNT(*) AS executions_24h
FROM tracer.executions
WHERE started_at >= NOW() - INTERVAL '24 hours';
```

**Display:**
- Tipografía: `--text-display-xl` / Space Grotesk
- Acento: borde superior de 2 px en `--color-current`
- Sin decimales. Separador de miles con coma cuando supera 999.

---

## K2 — Costo total del período

**Propósito:** agrega el gasto acumulado en tokens de todas las ejecuciones.
Es el KPI económico central — responde "¿cuánto hemos gastado?"

**Fuente:** Q1 (`TopByCost` / `tracer.token_costs`). El endpoint del dashboard
retorna la suma de `estimated_cost` sobre todas las ejecuciones del período, sin
filtro de `LIMIT`.

**Cálculo:**
```sql
SELECT SUM(tc.estimated_cost) AS costo_total
FROM tracer.token_costs tc;
```
Con el rango de fechas del selector global aplicado sobre `e.started_at` vía JOIN
a `tracer.executions`.

**Display:**
- Tipografía: `--text-display-xl` / Space Grotesk
- Acento: borde superior de 2 px en `--color-ledger`
- Formato `$0.00` (dos decimales fijos, prefijo `$`). IBM Plex Mono para el número.

---

## K3 — Tasa de error global

**Propósito:** porcentaje de ejecuciones fallidas sobre el total. Es la señal de
alerta más directa del sistema — si sube, algo en los swarms está fallando.

**Fuente:** Q2 (`SwarmSuccessRate` / `tracer.executions`). Se agregan los conteos
de `fallidas` y `total` de todos los swarms para obtener un único escalar global.

**Cálculo:**
```sql
SELECT
  round(
    SUM(fallidas) * 100.0 / NULLIF(SUM(total_executions), 0),
  1) AS tasa_error
FROM (
  SELECT
    COUNT(e.id) FILTER (WHERE e.status = 'failed') AS fallidas,
    COUNT(e.id)                                     AS total_executions
  FROM tracer.executions e
) sub;
```

**Display:**
- Tipografía: `--text-display-xl` / Space Grotesk
- Acento: borde superior de 2 px en `--color-alarm`
- Formato `0.0%` (un decimal). Si supera el 10 %, el número cambia a `--color-alarm`
  para reforzar la señal. IBM Plex Mono para el número.

---

## K4 — Agentes activos

**Propósito:** cuántos agentes distintos han ejecutado al menos un step en el
período. Indica la amplitud de participación del swarm — un número muy bajo puede
señalar un cuello de botella en un solo agente.

**Fuente:** Q3 (`AgentActivity` / `tracer.execution_steps`). COUNT de los agentes
con actividad, no su lista completa.

**Cálculo:**
```sql
SELECT COUNT(DISTINCT es.agent_id) AS active_agents
FROM tracer.execution_steps es
JOIN tracer.executions e ON e.id = es.execution_id
WHERE e.started_at >= NOW() - INTERVAL '24 hours';
```
La ventana de 24 h mantiene coherencia con K1.

**Display:**
- Tipografía: `--text-display-xl` / Space Grotesk
- Acento: borde superior de 2 px en `--color-border` (neutral — no es un estado
  de alerta ni de costo, sino un conteo operativo)
- Sin decimales.

---

## Implementación: función `kpis.py`

Los cuatro KPIs se calculan en una única función `DashboardKPIs.run()` en
`source/database/functions/kpis.py` que ejecuta las cuatro queries en paralelo con
`asyncio.gather`. El endpoint `GET /dashboard/kpis` (con el `tenant_id` inyectado
por el middleware) retorna el siguiente shape:

```json
{
  "executions_24h": 1204,
  "total_cost":     312.40,
  "error_rate":     3.2,
  "active_agents":  18
}
```

El selector de rango de fechas global del frontend (ver `uidesign.md`) pasa los
parámetros `from_date` / `to_date` como query params; para K1 y K4 la ventana de
24 h se aplica solo cuando no hay rango explícito del usuario.
