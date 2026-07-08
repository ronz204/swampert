-- 0006-agents.sql
--
-- Propósito: crear core.agents, las unidades de IA con rol y herramientas.
-- Un agent puede integrar varios swarms al mismo tiempo.

CREATE TABLE core.agents (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  UUID        NOT NULL REFERENCES core.tenants(id),
  name       TEXT        NOT NULL,
  role       TEXT        NOT NULL,
  base_model TEXT        NOT NULL,
  tools      TEXT[]      NOT NULL DEFAULT '{}',
  config     JSONB       NOT NULL DEFAULT '{}',
  active     BOOLEAN     NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ON core.agents (tenant_id);
CREATE INDEX ON core.agents USING GIN (config);

ALTER TABLE core.agents ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON core.agents
  USING (tenant_id = current_setting('app.tenant_id')::UUID);
