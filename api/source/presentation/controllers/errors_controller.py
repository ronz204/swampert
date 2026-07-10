from fastapi import APIRouter, Query

from source.database.functions.errors import TopByErrors, TopByErrorsFilters, TopByErrorsRow

router = APIRouter()


@router.get("/top", response_model=list[TopByErrorsRow])
async def get_top_by_errors(
  severity: list[str] | None = Query(default=None),
  error_type: str | None = None,
  task: str | None = None,
  limit: int = 15,
):
  rows = await TopByErrors.run(TopByErrorsFilters(
    severity=severity,
    error_type=error_type,
    task=task,
    limit=limit,
  ))
  return [dict(r) for r in rows]
