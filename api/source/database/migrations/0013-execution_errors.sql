-- 0013-execution_errors.sql
--
-- Propósito: crear tracer.execution_errors, los fallos ocurridos durante
-- una execution o un step puntual.
--
-- execution_id sin FK formal por la misma razón que execution_steps.
-- step_id es nullable: nulo cuando el error es a nivel de execution completa.

CREATE TABLE tracer.execution_errors (
  id           UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID                  NOT NULL REFERENCES core.tenants(id),
  execution_id UUID                  NOT NULL,
  step_id      UUID                  REFERENCES tracer.execution_steps(id),
  error_type   TEXT                  NOT NULL,
  message      TEXT                  NOT NULL,
  severity     tracer.error_severity NOT NULL,
  occurred_at  TIMESTAMPTZ           NOT NULL DEFAULT now()
);

CREATE INDEX ON tracer.execution_errors (tenant_id);
CREATE INDEX ON tracer.execution_errors (execution_id);
CREATE INDEX ON tracer.execution_errors (severity);

ALTER TABLE tracer.execution_errors ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tracer.execution_errors
  USING (tenant_id = current_setting('app.tenant_id')::UUID);
