import asyncpg

from source.configs.database import settings


class Pooling:
  def __init__(self) -> None:
    self.pool: asyncpg.Pool | None = None

  async def setup(self) -> None:
    self.pool = await asyncpg.create_pool(settings.postgres_app_url, min_size=2, max_size=10)

  async def teardown(self) -> None:
    if self.pool:
      await self.pool.close()
      self.pool = None

  async def fetch(self, query: str, *args) -> list[asyncpg.Record]:
    return await self.pool.fetch(query, *args)

  async def fetchrow(self, query: str, *args) -> asyncpg.Record | None:
    return await self.pool.fetchrow(query, *args)

  async def execute(self, query: str, *args) -> str:
    return await self.pool.execute(query, *args)

  def acquire(self):
    return self.pool.acquire()


db = Pooling()
