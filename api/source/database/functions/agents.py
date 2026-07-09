import asyncpg

from uuid import UUID
from decimal import Decimal
from datetime import datetime
from pydantic import BaseModel
from source.database.pooling import db


class AgentActivityFilters(BaseModel):
  role: str | None = None


class AgentActivityRow(BaseModel):
  agent_id: UUID
  agente: str
  role: str
  total_steps: int
  tokens_promedio: Decimal | None
  ultima_actividad: datetime | None


class AgentActivity:
  @staticmethod
  async def run(filters: AgentActivityFilters) -> list[asyncpg.Record]:
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
