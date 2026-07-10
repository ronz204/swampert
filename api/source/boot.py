from contextlib import asynccontextmanager

from fastapi import FastAPI

from source.database.pooling import db
from source.presentation.middleware.tenant_middleware import TenantMiddleware
from source.presentation.controllers import agents_controller, executions_controller, swarms_controller, errors_controller


@asynccontextmanager
async def lifespan(app: FastAPI):
  await db.setup()
  yield
  await db.teardown()


app = FastAPI(title="Swampert API", lifespan=lifespan)

app.add_middleware(TenantMiddleware)

app.include_router(agents_controller.router,     prefix="/agents",     tags=["agents"])
app.include_router(executions_controller.router, prefix="/executions", tags=["executions"])
app.include_router(swarms_controller.router,     prefix="/swarms",     tags=["swarms"])
app.include_router(errors_controller.router,     prefix="/errors",     tags=["errors"])
