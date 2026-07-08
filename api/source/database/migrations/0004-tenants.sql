-- 0004-tenants.sql
--
-- Propósito: crear core.tenants, la tabla raíz del modelo.
-- Todo lo demás en el sistema cuelga de acá — ninguna entidad existe
-- sin pertenecer a un tenant.
--
-- El slug identifica al tenant como subdominio (ej: "acme" → acme.swampert.io).

CREATE TABLE core.tenants (
  id         UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT             NOT NULL,
  slug       TEXT             NOT NULL UNIQUE,
  plan       core.tenant_plan NOT NULL,
  active     BOOLEAN          NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ      NOT NULL DEFAULT now()
);

-- La política aísla cada tenant a ver solo su propia fila.
-- Las tablas hijas usan tenant_id para la misma garantía.
ALTER TABLE core.tenants ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON core.tenants
  USING (id = current_setting('app.tenant_id')::UUID);
