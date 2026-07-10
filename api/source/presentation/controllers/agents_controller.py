from fastapi import APIRouter

from source.database.functions.agents import AgentActivity, AgentActivityFilters, AgentActivityRow

router = APIRouter()


@router.get("/activity", response_model=list[AgentActivityRow])
async def get_activity(role: str | None = None):
  rows = await AgentActivity.run(AgentActivityFilters(role=role))
  return [dict(r) for r in rows]
