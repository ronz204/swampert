-- 0003-enums.sql
--
-- Propósito: crear todos los tipos ENUM del dominio, co-localizados
-- en el schema de la tabla que los usa.
--
-- Los ENUMs viven en el schema porque son parte del contrato de datos
-- de ese contexto — no en public, para no mezclar tipos de dominios distintos.

-- schema core
CREATE TYPE core.tenant_plan   AS ENUM ('basic', 'pro', 'enterprise');
CREATE TYPE core.user_role     AS ENUM ('admin', 'member', 'viewer');
CREATE TYPE core.swarm_status  AS ENUM ('active', 'paused', 'archived');
CREATE TYPE core.task_status   AS ENUM ('pending', 'progress', 'completed', 'failed');
CREATE TYPE core.task_priority AS ENUM ('low', 'medium', 'high');

-- schema tracer
CREATE TYPE tracer.execution_status AS ENUM ('pending', 'running', 'completed', 'failed');
CREATE TYPE tracer.error_severity   AS ENUM ('low', 'medium', 'high', 'critical');
