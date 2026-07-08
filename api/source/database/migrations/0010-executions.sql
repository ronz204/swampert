-- 0010-executions.sql
--
-- Propósito: crear tracer.executions, cada intento de resolver una task.
--
-- Particionada por RANGE sobre started_at (una partición por mes).
-- Consecuencia de diseño: la PK debe incluir la clave de partición →
-- PRIMARY KEY (id, started_at). Las tablas hijas (execution_steps, etc.)
-- no pueden usar FK formal contra esta tabla por esa razón — ver sus migraciones.

CREATE TABLE tracer.executions (
  id             UUID                    NOT NULL DEFAULT gen_random_uuid(),
  tenant_id      UUID                    NOT NULL REFERENCES core.tenants(id),
  task_id        UUID                    NOT NULL REFERENCES core.tasks(id),
  attempt_number INTEGER                 NOT NULL DEFAULT 1,
  status         tracer.execution_status NOT NULL DEFAULT 'pending',
  started_at     TIMESTAMPTZ             NOT NULL DEFAULT now(),
  finished_at    TIMESTAMPTZ,

  PRIMARY KEY (id, started_at)
) PARTITION BY RANGE (started_at);

-- Particiones mensuales que cubren el período de desarrollo y seed
CREATE TABLE tracer.executions_2026_04 PARTITION OF tracer.executions
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE tracer.executions_2026_05 PARTITION OF tracer.executions
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE tracer.executions_2026_06 PARTITION OF tracer.executions
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE tracer.executions_2026_07 PARTITION OF tracer.executions
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE tracer.executions_2026_08 PARTITION OF tracer.executions
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE tracer.executions_2026_09 PARTITION OF tracer.executions
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE tracer.executions_default PARTITION OF tracer.executions DEFAULT;

-- Los índices sobre el padre se propagan automáticamente a todas las particiones
CREATE INDEX ON tracer.executions (tenant_id, started_at);
CREATE INDEX ON tracer.executions (task_id);
CREATE INDEX ON tracer.executions (status);

ALTER TABLE tracer.executions ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tracer.executions
  USING (tenant_id = current_setting('app.tenant_id')::UUID);
