import asyncpg

from uuid import UUID
from datetime import datetime, timezone
from pydantic import BaseModel
from source.database.pooling import db


class TopByCostFilters(BaseModel):
  limit: int = 20
  status: str | None = None
  from_date: str | None = None
  to_date: str | None = None


class TopByCostRow(BaseModel):
  tarea: str
  execution_id: UUID
  status: str
  started_at: datetime
  total_tokens: int
  costo_total: float


class TopByCost:
  @staticmethod
  async def run(filters: TopByCostFilters) -> list[asyncpg.Record]:
    conditions = []
    args: list = []

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
    args.append(filters.limit)

    return await db.fetch(f"""
      SELECT
        t.title                                       AS tarea,
        e.id                                          AS execution_id,
        e.status,
        e.started_at,
        SUM(tc.input_tokens + tc.output_tokens)       AS total_tokens,
        SUM(tc.estimated_cost)                        AS costo_total
      FROM tracer.token_costs   tc
      JOIN tracer.executions    e  ON e.id  = tc.execution_id
      JOIN core.tasks           t  ON t.id  = e.task_id
      {where}
      GROUP BY e.id, e.status, e.started_at, t.title
      ORDER BY costo_total DESC
      LIMIT ${len(args)}
    """, *args)
