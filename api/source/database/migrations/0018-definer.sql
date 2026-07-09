-- 0018-resolve-tenant.sql
--
-- Propósito: función SECURITY DEFINER que permite a swampert_app resolver
-- un tenant_id a partir de su slug sin pasar por RLS.
--
-- El problema: core.tenants tiene RLS que requiere app.tenant_id seteado,
-- pero necesitamos leer tenants para obtener ese mismo valor (circular).
-- La solución: esta función corre con los privilegios del owner (admin),
-- bypasseando RLS, y swampert_app solo puede llamarla, no leer la tabla.

CREATE OR REPLACE FUNCTION core.resolve_tenant_id(p_slug TEXT)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = core, tracer, public
AS $$
  SELECT id FROM core.tenants WHERE slug = p_slug AND active = TRUE;
$$;

GRANT EXECUTE ON FUNCTION core.resolve_tenant_id(TEXT) TO swampert_app;
