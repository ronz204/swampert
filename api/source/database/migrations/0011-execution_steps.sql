-- 0011-execution_steps.sql
--
-- Propósito: crear tracer.execution_steps, la acción puntual de un agent
-- dentro de una execution. Es la unidad mínima de trazabilidad.
--
-- execution_id no usa FK formal: tracer.executions está particionada y
-- PostgreSQL exige que la clave de partición (started_at) integre el UNIQUE
-- referenciado. Omitir la FK es la decisión estándar en tablas particionadas
-- de alto volumen — la integridad se garantiza en la capa de aplicación.

CREATE TABLE tracer.execution_steps (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID        NOT NULL REFERENCES core.tenants(id),
  execution_id UUID        NOT NULL,
  agent_id     UUID        NOT NULL REFERENCES core.agents(id),
  step_number  INTEGER     NOT NULL,
  reasoning    JSONB       NOT NULL DEFAULT '{}',
  tools_used   TEXT[]      NOT NULL DEFAULT '{}',
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ON tracer.execution_steps (tenant_id);
CREATE INDEX ON tracer.execution_steps (execution_id, step_number);
CREATE INDEX ON tracer.execution_steps USING GIN (reasoning);

ALTER TABLE tracer.execution_steps ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tracer.execution_steps
  USING (tenant_id = current_setting('app.tenant_id')::UUID);
