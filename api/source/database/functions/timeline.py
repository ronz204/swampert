import asyncpg

from datetime import datetime, timezone
from pydantic import BaseModel
from source.database.pooling import db


class ExecutionsByMonthFilters(BaseModel):
  swarm: str | None = None
  status: str | None = None
  from_date: str | None = None
  to_date: str | None = None


class ExecutionsByMonthRow(BaseModel):
  mes: datetime
  swarm: str
  completadas: int
  fallidas: int
  en_curso: int
  total: int


class ExecutionsByMonth:
  @staticmethod
  async def run(filters: ExecutionsByMonthFilters) -> list[asyncpg.Record]:
    conditions = []
    args: list = []

    if filters.swarm:
      args.append(f"%{filters.swarm}%")
      conditions.append(f"s.name ILIKE ${len(args)}")
    if filters.status:
      args.append(filters.status)
      conditions.append(f"e.status = ${len(args)}")
    if filters.from_date:
      args.append(datetime.fromisoformat(filters.from_date).replace(tzinfo=timezone.utc))
      conditions.append(f"e.started_at >= ${len(args)}")
    if filters.to_date:
      args.append(datetime.fromisoformat(filters.to_date).replace(tzinfo=timezone.utc))
      conditions.append(f"e.started_at < ${len(args)}")

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

    return await db.fetch(f"""
      SELECT
        date_trunc('month', e.started_at)                     AS mes,
        s.name                                                 AS swarm,
        COUNT(e.id) FILTER (WHERE e.status = 'completed')     AS completadas,
        COUNT(e.id) FILTER (WHERE e.status = 'failed')        AS fallidas,
        COUNT(e.id) FILTER (WHERE e.status = 'running')       AS en_curso,
        COUNT(e.id)                                            AS total
      FROM tracer.executions  e
      JOIN core.tasks         t  ON t.id = e.task_id
      JOIN core.swarms        s  ON s.id = t.swarm_id
      {where}
      GROUP BY date_trunc('month', e.started_at), s.id, s.name
      ORDER BY mes, total DESC
    """, *args)
