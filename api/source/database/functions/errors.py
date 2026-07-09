import asyncpg

from source.database.pooling import db


async def fetch_top_by_errors(
  severity: list[str] | None = None,
  error_type: str | None = None,
  task: str | None = None,
  limit: int = 15,
) -> list[asyncpg.Record]:
  conditions = []
  args: list = []

  if severity:
    args.append(severity)
    conditions.append(f"ee.severity = ANY(${len(args)})")
  if error_type:
    args.append(f"%{error_type}%")
    conditions.append(f"ee.error_type ILIKE ${len(args)}")
  if task:
    args.append(f"%{task}%")
    conditions.append(f"t.title ILIKE ${len(args)}")

  where = ("WHERE " + " AND ".join(conditions)) if conditions else "WHERE ee.severity IN ('high', 'critical')"
  args.append(limit)

  return await db.fetch(f"""
    SELECT
      t.title                             AS tarea,
      ee.severity,
      ee.error_type,
      COUNT(ee.id)                        AS total_errores,
      COUNT(DISTINCT ee.execution_id)     AS execuciones_afectadas
    FROM tracer.execution_errors   ee
    JOIN tracer.executions         e   ON e.id = ee.execution_id
    JOIN core.tasks                t   ON t.id = e.task_id
    {where}
    GROUP BY t.title, ee.severity, ee.error_type
    ORDER BY total_errores DESC
    LIMIT ${len(args)}
  """, *args)
