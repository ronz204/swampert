from fastapi import APIRouter

from source.database.functions.executions import TopByCost, TopByCostFilters, TopByCostRow
from source.database.functions.timeline import ExecutionsByMonth, ExecutionsByMonthFilters, ExecutionsByMonthRow

router = APIRouter()


@router.get("/cost", response_model=list[TopByCostRow])
async def get_top_by_cost(
  limit: int = 20,
  status: str | None = None,
  from_date: str | None = None,
  to_date: str | None = None,
):
  rows = await TopByCost.run(TopByCostFilters(
    limit=limit,
    status=status,
    from_date=from_date,
    to_date=to_date,
  ))
  return [dict(r) for r in rows]


@router.get("/timeline", response_model=list[ExecutionsByMonthRow])
async def get_timeline(
  swarm: str | None = None,
  status: str | None = None,
  from_date: str | None = None,
  to_date: str | None = None,
):
  rows = await ExecutionsByMonth.run(ExecutionsByMonthFilters(
    swarm=swarm,
    status=status,
    from_date=from_date,
    to_date=to_date,
  ))
  return [dict(r) for r in rows]
