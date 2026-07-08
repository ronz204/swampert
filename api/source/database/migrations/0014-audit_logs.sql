-- 0014-audit_logs.sql
--
-- Propósito: crear tracer.audit_logs, el registro inmutable de acciones
-- de usuarios sobre la configuración del sistema.
--
-- Tabla append-only: nunca se modifica ni se borra un registro existente.
-- Particionada por RANGE sobre occurred_at (una partición por mes),
-- con la misma implicación en PK que tracer.executions.

CREATE TABLE tracer.audit_logs (
  id          UUID        NOT NULL DEFAULT gen_random_uuid(),
  tenant_id   UUID        NOT NULL REFERENCES core.tenants(id),
  user_id     UUID        NOT NULL REFERENCES core.users(id),
  action      TEXT        NOT NULL,
  entity_type TEXT        NOT NULL,
  entity_id   UUID        NOT NULL,
  details     JSONB       NOT NULL DEFAULT '{}',
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

CREATE TABLE tracer.audit_logs_2026_04 PARTITION OF tracer.audit_logs
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE tracer.audit_logs_2026_05 PARTITION OF tracer.audit_logs
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE tracer.audit_logs_2026_06 PARTITION OF tracer.audit_logs
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE tracer.audit_logs_2026_07 PARTITION OF tracer.audit_logs
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE tracer.audit_logs_2026_08 PARTITION OF tracer.audit_logs
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE tracer.audit_logs_2026_09 PARTITION OF tracer.audit_logs
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE tracer.audit_logs_default PARTITION OF tracer.audit_logs DEFAULT;

CREATE INDEX ON tracer.audit_logs (tenant_id, occurred_at);

ALTER TABLE tracer.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tracer.audit_logs
  USING (tenant_id = current_setting('app.tenant_id')::UUID);
