import asyncpg

from uuid import UUID
from datetime import datetime
from pydantic import BaseModel
from source.database.pooling import db


class TopByCostFilters(BaseModel):
  limit: int = 20
  status: str | None = None


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
    where = "AND e.status = $2" if filters.status else ""
    args = [filters.limit, filters.status] if filters.status else [filters.limit]

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
      LIMIT $1
    """, *args)
