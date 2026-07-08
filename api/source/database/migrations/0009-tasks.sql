-- 0009-tasks.sql
--
-- Propósito: crear core.tasks, el encargo concreto que se le hace a un swarm.
-- Sin una task no puede existir una execution — es el punto de partida del flujo.

CREATE TABLE core.tasks (
  id          UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID               NOT NULL REFERENCES core.tenants(id),
  swarm_id    UUID               NOT NULL REFERENCES core.swarms(id),
  title       TEXT               NOT NULL,
  description TEXT,
  status      core.task_status   NOT NULL,
  priority    core.task_priority NOT NULL,
  created_at  TIMESTAMPTZ        NOT NULL DEFAULT now()
);

CREATE INDEX ON core.tasks (tenant_id, status);
CREATE INDEX ON core.tasks (swarm_id);

ALTER TABLE core.tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON core.tasks
  USING (tenant_id = current_setting('app.tenant_id')::UUID);
