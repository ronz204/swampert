-- 0008-swarm_agents.sql
--
-- Propósito: crear core.swarm_agents, la tabla puente que resuelve la relación
-- N:M entre swarms y agents.
--
-- No lleva tenant_id ni RLS propio: el aislamiento se hereda a través de
-- swarm_id → core.swarms.tenant_id y agent_id → core.agents.tenant_id.

CREATE TABLE core.swarm_agents (
  swarm_id UUID        NOT NULL REFERENCES core.swarms(id),
  agent_id UUID        NOT NULL REFERENCES core.agents(id),
  added_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (swarm_id, agent_id)
);
