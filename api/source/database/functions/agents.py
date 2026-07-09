import asyncpg

from pydantic import BaseModel
from source.database.pooling import db


class AgentActivityFilters(BaseModel):
  role: str | None = None


async def fetch_activity(filters: AgentActivityFilters) -> list[asyncpg.Record]:
  where = "WHERE a.role = $1" if filters.role else ""
  args = [filters.role] if filters.role else []

  return await db.fetch(f"""
    SELECT
      a.id                                                          AS agent_id,
      a.name                                                        AS agente,
      a.role,
      COUNT(es.id)                                                  AS total_steps,
      round(AVG((es.reasoning->>'tokens_used')::int), 0)           AS tokens_promedio,
      MAX(e.started_at)                                             AS ultima_actividad
    FROM tracer.execution_steps  es
    JOIN core.agents             a  ON a.id = es.agent_id
    JOIN tracer.executions       e  ON e.id = es.execution_id
    {where}
    GROUP BY a.id, a.name, a.role
    ORDER BY total_steps DESC
  """, *args)
