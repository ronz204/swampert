-- 0012-token_costs.sql
--
-- Propósito: crear tracer.token_costs, el gasto en tokens de una execution
-- o de un step puntual dentro de ella.
--
-- execution_id sin FK formal por la misma razón que execution_steps.
-- step_id es nullable: nulo cuando el costo se registra a nivel de execution
-- completa, no de un step puntual.

CREATE TABLE tracer.token_costs (
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      UUID          NOT NULL REFERENCES core.tenants(id),
  execution_id   UUID          NOT NULL,
  step_id        UUID          REFERENCES tracer.execution_steps(id),
  input_tokens   INTEGER       NOT NULL,
  output_tokens  INTEGER       NOT NULL,
  estimated_cost NUMERIC(10,4) NOT NULL,
  recorded_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX ON tracer.token_costs (tenant_id);
CREATE INDEX ON tracer.token_costs (execution_id);

ALTER TABLE tracer.token_costs ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tracer.token_costs
  USING (tenant_id = current_setting('app.tenant_id')::UUID);
