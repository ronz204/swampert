import asyncpg

from pydantic import BaseModel
from source.database.pooling import db


class SwarmSuccessRateFilters(BaseModel):
  name: str | None = None


async def fetch_success_rate(filters: SwarmSuccessRateFilters) -> list[asyncpg.Record]:
  where = "WHERE s.name ILIKE $1" if filters.name else ""
  args = [f"%{filters.name}%"] if filters.name else []

  return await db.fetch(f"""
    SELECT
      s.id                                                          AS swarm_id,
      s.name                                                        AS swarm,
      COUNT(DISTINCT t.id)                                          AS total_tareas,
      COUNT(e.id) FILTER (WHERE e.status = 'completed')            AS completadas,
      COUNT(e.id) FILTER (WHERE e.status = 'failed')               AS fallidas,
      round(
        COUNT(e.id) FILTER (WHERE e.status = 'completed') * 100.0
        / NULLIF(COUNT(e.id), 0),
      1)                                                            AS tasa_exito
    FROM core.swarms          s
    JOIN core.tasks           t  ON t.swarm_id = s.id
    JOIN tracer.executions    e  ON e.task_id  = t.id
    {where}
    GROUP BY s.id, s.name
    ORDER BY tasa_exito DESC NULLS LAST
  """, *args)
