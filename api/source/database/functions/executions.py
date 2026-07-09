import asyncpg

from source.database.pooling import db


async def fetch_top_by_cost(
  limit: int = 20,
  status: str | None = None,
) -> list[asyncpg.Record]:
  where = "AND e.status = $2" if status else ""
  args: list = [limit, status] if status else [limit]

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
