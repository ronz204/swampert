from fastapi import APIRouter

from source.database.functions.swarms import SwarmSuccessRate, SwarmSuccessRateFilters, SwarmSuccessRateRow

router = APIRouter()


@router.get("/success-rate", response_model=list[SwarmSuccessRateRow])
async def get_success_rate(name: str | None = None):
  rows = await SwarmSuccessRate.run(SwarmSuccessRateFilters(name=name))
  return [dict(r) for r in rows]
