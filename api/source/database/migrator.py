import asyncio
import asyncpg

from pathlib import Path
from source.configs.migrator import settings

MIGRATIONS = Path(__file__).parent / "migrations"

BOOTSTRAP_SQL = """
CREATE SCHEMA IF NOT EXISTS meta;
CREATE TABLE IF NOT EXISTS meta.migrations (
  filename   TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
"""


async def bootstrap(conn: asyncpg.Connection) -> None:
  await conn.execute(BOOTSTRAP_SQL)


async def get_applied(conn: asyncpg.Connection) -> set[str]:
  rows = await conn.fetch("SELECT filename FROM meta.migrations")
  return {row["filename"] for row in rows}


def get_pending(applied: set[str]) -> list[Path]:
  files = sorted(MIGRATIONS.glob("*.sql"))
  return [f for f in files if f.name not in applied]


async def apply(conn: asyncpg.Connection, path: Path) -> None:
  sql = path.read_text(encoding="utf-8")
  async with conn.transaction():
    await conn.execute(sql)
    await conn.execute("INSERT INTO meta.migrations (filename) VALUES ($1)", path.name)
  print(f"  aplicada: {path.name}")


async def run() -> None:
  conn = await asyncpg.connect(settings.postgres_adm_url)
  try:
    await bootstrap(conn)
    applied = await get_applied(conn)
    pending = get_pending(applied)

    if not pending:
      print("sin cambios.")
      return

    for path in pending:
      await apply(conn, path)
  finally:
    await conn.close()


if __name__ == "__main__":
  asyncio.run(run())
