import asyncpg

from uuid import UUID
from datetime import datetime, timezone
from pydantic import BaseModel
from source.database.pooling import db


class SwarmSuccessRateFilters(BaseModel):
  name: str | None = None


class SwarmSuccessRateRow(BaseModel):
  swarm_id: UUID
  swarm: str
  total_tareas: int
  completadas: int
  fallidas: int
  tasa_exito: float | None


class SwarmSuccessRate:
  @staticmethod
  async def run(filters: SwarmSuccessRateFilters) -> list[asyncpg.Record]:
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


class SwarmCostFilters(BaseModel):
  from_date: str | None = None
  to_date: str | None = None


class SwarmCostRow(BaseModel):
  swarm_id: UUID
  swarm: str
  costo_total: float


class SwarmCost:
  @staticmethod
  async def run(filters: SwarmCostFilters) -> list[asyncpg.Record]:
    conditions = []
    args: list = []

    if filters.from_date:
      args.append(datetime.fromisoformat(filters.from_date).replace(tzinfo=timezone.utc))
      conditions.append(f"e.started_at >= ${len(args)}")
    if filters.to_date:
      args.append(datetime.fromisoformat(filters.to_date).replace(tzinfo=timezone.utc))
      conditions.append(f"e.started_at < ${len(args)}")

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

    return await db.fetch(f"""
      SELECT
        s.id                     AS swarm_id,
        s.name                   AS swarm,
        SUM(tc.estimated_cost)   AS costo_total
      FROM tracer.token_costs   tc
      JOIN tracer.executions    e  ON e.id  = tc.execution_id
      JOIN core.tasks           t  ON t.id  = e.task_id
      JOIN core.swarms          s  ON s.id  = t.swarm_id
      {where}
      GROUP BY s.id, s.name
      ORDER BY costo_total DESC
    """, *args)
