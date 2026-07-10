from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from source.database.pooling import db, tenant_id_var

BYPASS_PATHS = {"/docs"}


class TenantMiddleware(BaseHTTPMiddleware):
  async def dispatch(self, request: Request, call_next):
    if request.url.path in BYPASS_PATHS:
      return await call_next(request)

    host = request.headers.get("host", "")
    parts = host.split(".")
    slug = parts[0].split(":")[0]

    if not slug or slug in ("localhost", "127"):
      return JSONResponse({"detail": "tenant no especificado — accedé con subdominio: <slug>.localhost"}, status_code=400)

    row = await db.fetchrow_system("SELECT core.resolve_tenant_id($1) AS id", slug)
    tenant_id = row["id"] if row else None

    if not tenant_id:
      return JSONResponse({"detail": f"tenant '{slug}' no encontrado"}, status_code=404)

    token = tenant_id_var.set(str(tenant_id))
    try:
      response = await call_next(request)
    finally:
      tenant_id_var.reset(token)
    return response
