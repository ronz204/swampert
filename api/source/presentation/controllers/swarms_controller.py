from fastapi import APIRouter

from source.database.functions.swarms import (
  SwarmSuccessRate, SwarmSuccessRateFilters, SwarmSuccessRateRow,
  SwarmCost, SwarmCostFilters, SwarmCostRow,
)

router = APIRouter()


@router.get("/success-rate", response_model=list[SwarmSuccessRateRow])
async def get_success_rate(name: str | None = None):
  rows = await SwarmSuccessRate.run(SwarmSuccessRateFilters(name=name))
  return [dict(r) for r in rows]


@router.get("/cost", response_model=list[SwarmCostRow])
async def get_swarm_cost(from_date: str | None = None, to_date: str | None = None):
  rows = await SwarmCost.run(SwarmCostFilters(from_date=from_date, to_date=to_date))
  return [dict(r) for r in rows]
