-- 0007-swarms.sql
--
-- Propósito: crear core.swarms, los grupos de agents que resuelven tasks.
-- Un swarm sin agents no puede recibir tasks — invariante del dominio.

CREATE TABLE core.swarms (
  id          UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID              NOT NULL REFERENCES core.tenants(id),
  name        TEXT              NOT NULL,
  description TEXT,
  status      core.swarm_status NOT NULL,
  created_at  TIMESTAMPTZ       NOT NULL DEFAULT now()
);

CREATE INDEX ON core.swarms (tenant_id, status);

ALTER TABLE core.swarms ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON core.swarms
  USING (tenant_id = current_setting('app.tenant_id')::UUID);
