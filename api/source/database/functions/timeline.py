import asyncpg

from source.database.pooling import db


async def fetch_executions_by_month(
  swarm: str | None = None,
  status: str | None = None,
  from_date: str | None = None,
  to_date: str | None = None,
) -> list[asyncpg.Record]:
  conditions = []
  args: list = []

  if swarm:
    args.append(f"%{swarm}%")
    conditions.append(f"s.name ILIKE ${len(args)}")
  if status:
    args.append(status)
    conditions.append(f"e.status = ${len(args)}")
  if from_date:
    args.append(from_date)
    conditions.append(f"e.started_at >= ${len(args)}")
  if to_date:
    args.append(to_date)
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
