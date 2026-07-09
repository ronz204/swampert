import asyncpg

from contextvars import ContextVar
from source.configs.database import settings

tenant_id_var: ContextVar[str | None] = ContextVar("tenant_id", default=None)


class Pooling:
  def __init__(self) -> None:
    self.pool: asyncpg.Pool | None = None

  async def setup(self) -> None:
    self.pool = await asyncpg.create_pool(settings.postgres_app_url, min_size=2, max_size=10)

  async def teardown(self) -> None:
    if self.pool:
      await self.pool.close()
      self.pool = None

  async def run(self, method: str, query: str, *args):
    if self.pool is None:
      raise RuntimeError("El pool no está inicializado — llamá a setup() primero")

    tenant_id = tenant_id_var.get()
    if tenant_id is None:
      raise RuntimeError("No hay tenant en contexto — todas las queries requieren un tenant activo")

    async with self.pool.acquire() as conn:
      async with conn.transaction():
        await conn.execute("SELECT set_config('app.tenant_id', $1, true)", tenant_id)
        return await getattr(conn, method)(query, *args)

  async def fetch(self, query: str, *args) -> list[asyncpg.Record]:
    return await self.run("fetch", query, *args)

  async def fetchrow(self, query: str, *args) -> asyncpg.Record | None:
    return await self.run("fetchrow", query, *args)

  async def execute(self, query: str, *args) -> str:
    return await self.run("execute", query, *args)


db = Pooling()
