import asyncio

from pydantic import BaseModel
from source.database.pooling import db
from datetime import datetime, timezone, timedelta


class DashboardKPIsFilters(BaseModel):
  from_date: str | None = None
  to_date: str | None = None


class DashboardKPIsResult(BaseModel):
  executions_count: int
  total_cost: float
  error_rate: float | None
  active_agents: int


class DashboardKPIs:
  @staticmethod
  async def run(filters: DashboardKPIsFilters) -> DashboardKPIsResult:
    now = datetime.now(timezone.utc)
    start = datetime.fromisoformat(filters.from_date).replace(tzinfo=timezone.utc) if filters.from_date else now - timedelta(hours=24)
    end = datetime.fromisoformat(filters.to_date).replace(tzinfo=timezone.utc) if filters.to_date else now

    q_count, q_cost, q_error_rate, q_agents = await asyncio.gather(
      db.fetchrow("""
        SELECT COUNT(*) AS executions_count
        FROM tracer.executions
        WHERE started_at >= $1 AND started_at < $2
      """, start, end),
      db.fetchrow("""
        SELECT COALESCE(SUM(tc.estimated_cost), 0) AS total_cost
        FROM tracer.token_costs    tc
        JOIN tracer.executions     e  ON e.id = tc.execution_id
        WHERE e.started_at >= $1 AND e.started_at < $2
      """, start, end),
      db.fetchrow("""
        SELECT round(
          COUNT(id) FILTER (WHERE status = 'failed') * 100.0
          / NULLIF(COUNT(id), 0),
        1) AS error_rate
        FROM tracer.executions
        WHERE started_at >= $1 AND started_at < $2
      """, start, end),
      db.fetchrow("""
        SELECT COUNT(DISTINCT es.agent_id) AS active_agents
        FROM tracer.execution_steps  es
        JOIN tracer.executions       e  ON e.id = es.execution_id
        WHERE e.started_at >= $1 AND e.started_at < $2
      """, start, end),
    )

    return DashboardKPIsResult(
      executions_count=q_count["executions_count"],
      total_cost=q_cost["total_cost"],
      error_rate=q_error_rate["error_rate"],
      active_agents=q_agents["active_agents"],
    )
