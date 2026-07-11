from fastapi import APIRouter

from source.database.functions.kpis import DashboardKPIs, DashboardKPIsFilters, DashboardKPIsResult

router = APIRouter()


@router.get("/kpis", response_model=DashboardKPIsResult)
async def get_kpis(from_date: str | None = None, to_date: str | None = None):
  return await DashboardKPIs.run(DashboardKPIsFilters(from_date=from_date, to_date=to_date))
