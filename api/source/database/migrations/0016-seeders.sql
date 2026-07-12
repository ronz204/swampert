-- 0017-seeders.sql
--
-- Propósito: poblar la base con datos realistas para demostración de rendimiento (R-11).
--
-- Distribución objetivo:
--   · core.tenants              →     5
--   · core.users                →    20  (4 por tenant)
--   · core.agents               →    30  (6 por tenant)
--   · core.swarms               →    20  (4 por tenant)
--   · core.swarm_agents         →   ~60  (~3 por swarm)
--   · core.tasks                →   500  (25 por swarm)
--   · tracer.executions         →  5000  (10 por task)        ← tabla principal R-11
--   · tracer.execution_steps    → 25000  (5 por execution)    ← tabla principal R-11
--   · tracer.token_costs        → ~7500  (1-2 por execution)  ← tabla principal R-11
--   · tracer.execution_errors   →  ~800  (solo executions fallidas)
--   · tracer.audit_logs         →  ~100  (5 por usuario)
--
-- Estrategia de FKs: tablas temporales de sesión como puente entre bloques DO.
-- El seed corre como superuser → RLS no aplica.

-- ── tablas temporales para resolver FKs entre bloques ────────────────────────
CREATE TEMP TABLE _seed_tenants (id UUID);
CREATE TEMP TABLE _seed_users   (id UUID, tenant_id UUID);
CREATE TEMP TABLE _seed_agents  (id UUID, tenant_id UUID);
CREATE TEMP TABLE _seed_swarms  (id UUID, tenant_id UUID);
CREATE TEMP TABLE _seed_tasks   (id UUID, tenant_id UUID);
CREATE TEMP TABLE _seed_execs   (id UUID, tenant_id UUID, started_at TIMESTAMPTZ, status TEXT);
CREATE TEMP TABLE _seed_steps   (id UUID);

-- ── BLOQUE 1 — catálogo base ──────────────────────────────────────────────────
DO $block1$
BEGIN

  -- tenants (5)
  WITH ins AS (
    INSERT INTO core.tenants (name, slug, plan, active)
    SELECT
      'Tenant ' || i,
      'tenant-' || i,
      (ARRAY['basic','pro','enterprise']::core.tenant_plan[])[1 + (random() * 2)::int],
      true
    FROM generate_series(1, 5) i
    ON CONFLICT (slug) DO NOTHING
    RETURNING id
  )
  INSERT INTO _seed_tenants (id)
  SELECT id FROM ins;

  -- users: 4 por tenant = 20
  -- la contraseña se almacena con bcrypt via pgcrypto (requisito de seguridad)
  WITH ins AS (
    INSERT INTO core.users (tenant_id, name, email, password, role, active)
    SELECT
      t.id,
      'User ' || u,
      'user' || u || '@tenant-' || t.rn || '.io',
      crypt('seed1234', gen_salt('bf')),
      (ARRAY['admin','member','viewer']::core.user_role[])[1 + (random() * 2)::int],
      true
    FROM (SELECT id, row_number() OVER (ORDER BY id) AS rn FROM _seed_tenants) t
    CROSS JOIN generate_series(1, 4) u
    RETURNING id, tenant_id
  )
  INSERT INTO _seed_users (id, tenant_id)
  SELECT id, tenant_id FROM ins;

  -- agents: 6 por tenant = 30
  -- un agente por cada rol del dominio, asignado al mismo tenant
  WITH ins AS (
    INSERT INTO core.agents (tenant_id, name, role, base_model, tools, config, active)
    SELECT
      t.id,
      rl || '-' || substr(md5(t.id::text || rl), 1, 6),
      rl,
      (ARRAY['gpt-4o','claude-3-5-sonnet','gemini-1.5-pro','llama-3.1-70b','mistral-large'])
        [1 + (random() * 4)::int],
      (CASE (random() * 4)::int
        WHEN 0 THEN ARRAY['web_search','code_interpreter']
        WHEN 1 THEN ARRAY['file_reader','api_caller','data_analyzer']
        WHEN 2 THEN ARRAY['web_search','api_caller']
        WHEN 3 THEN ARRAY['code_interpreter','data_analyzer']
        ELSE        ARRAY['web_search','file_reader','image_describer']
      END),
      jsonb_build_object(
        'temperature', round((0.3 + random() * 0.7)::numeric, 2),
        'max_tokens',  (1024 + (random() * 3072)::int)
      ),
      true
    FROM _seed_tenants t
    CROSS JOIN unnest(ARRAY[
      'orchestrator','researcher','validator','summarizer','executor','coordinator'
    ]) AS rl
    RETURNING id, tenant_id
  )
  INSERT INTO _seed_agents (id, tenant_id)
  SELECT id, tenant_id FROM ins;

  -- swarms: 4 por tenant = 20
  WITH ins AS (
    INSERT INTO core.swarms (tenant_id, name, description, status)
    SELECT
      t.id,
      nm,
      'Swarm de ' || ds,
      (CASE
        WHEN rs < 0.70 THEN 'active'
        WHEN rs < 0.85 THEN 'paused'
        ELSE                'archived'
      END)::core.swarm_status
    FROM _seed_tenants t
    CROSS JOIN (VALUES
      ('Analytics', 'análisis de datos'),
      ('Reporting', 'generación de reportes'),
      ('Research',  'investigación de dominio'),
      ('Ops',       'operaciones y monitoreo')
    ) AS s(nm, ds)
    CROSS JOIN LATERAL (SELECT random() AS rs) rnd
    RETURNING id, tenant_id
  )
  INSERT INTO _seed_swarms (id, tenant_id)
  SELECT id, tenant_id FROM ins;

  -- swarm_agents: garantizar ≥ 1 agent por swarm, luego agregar más aleatoriamente
  INSERT INTO core.swarm_agents (swarm_id, agent_id)
  SELECT DISTINCT ON (sw.id) sw.id, ag.id
  FROM _seed_swarms sw
  JOIN _seed_agents ag ON ag.tenant_id = sw.tenant_id
  ORDER BY sw.id, random()
  ON CONFLICT DO NOTHING;

  INSERT INTO core.swarm_agents (swarm_id, agent_id)
  SELECT sw.id, ag.id
  FROM _seed_swarms sw
  JOIN _seed_agents ag ON ag.tenant_id = sw.tenant_id
  WHERE random() < 0.4
  ON CONFLICT DO NOTHING;

  -- tasks: 25 por swarm = 500
  WITH ins AS (
    INSERT INTO core.tasks (tenant_id, swarm_id, title, description, status, priority)
    SELECT
      sw.tenant_id,
      sw.id,
      ttl || ' #' || row_number() OVER (ORDER BY sw.id, ttl),
      'Tarea autogenerada: ' || lower(ttl),
      (CASE
        WHEN r < 0.10 THEN 'pending'
        WHEN r < 0.18 THEN 'progress'
        WHEN r < 0.82 THEN 'completed'
        ELSE               'failed'
      END)::core.task_status,
      (ARRAY['low','medium','high']::core.task_priority[])[1 + (random() * 2)::int]
    FROM _seed_swarms sw
    CROSS JOIN unnest(ARRAY[
      'Analyze market trends',      'Generate quarterly report',
      'Summarize research papers',  'Validate dataset integrity',
      'Extract KPIs from logs',     'Classify support tickets',
      'Draft executive summary',    'Audit configuration changes',
      'Benchmark model responses',  'Detect anomalies in metrics',
      'Profile system bottlenecks', 'Evaluate agent performance',
      'Cluster feedback topics',    'Rank document relevance',
      'Map dependency graph',       'Simulate load scenarios',
      'Score sentiment in reviews', 'Identify duplicate entries',
      'Normalize pricing data',     'Generate test fixtures',
      'Monitor token budgets',      'Archive stale executions',
      'Compare model outputs',      'Flag policy violations',
      'Rebuild search index'
    ]) AS ttl
    CROSS JOIN LATERAL (SELECT random() AS r) rnd
    RETURNING id, tenant_id
  )
  INSERT INTO _seed_tasks (id, tenant_id)
  SELECT id, tenant_id FROM ins;

END $block1$;

-- ── BLOQUE 2 — executions (10 por task = 5 000) ──────────────────────────────
-- Tabla particionada por started_at: los valores deben caer en 2026-04 a 2026-09
--
-- IMPORTANTE: no usar CROSS JOIN LATERAL (SELECT random()) sin FROM.
-- Sin referencia a columnas externas el planner lo trata como subquery constante
-- y evalúa random() una sola vez → todos los rows quedan con el mismo started_at.
-- Solución: CTE con FROM explícito garantiza evaluación por fila.
DO $block2$
BEGIN

  WITH expanded AS (
    SELECT
      tk.tenant_id,
      tk.id                                                              AS task_id,
      e                                                                  AS attempt,
      random()                                                           AS r,
      '2026-04-01'::timestamptz + (random() * interval '180 days')      AS ts
    FROM _seed_tasks tk
    CROSS JOIN generate_series(1, 10) e
  ),
  ins AS (
    INSERT INTO tracer.executions
      (tenant_id, task_id, attempt_number, status, started_at, finished_at)
    SELECT
      expanded.tenant_id,
      expanded.task_id,
      expanded.attempt,
      (CASE
        WHEN expanded.r < 0.05 THEN 'pending'
        WHEN expanded.r < 0.12 THEN 'running'
        WHEN expanded.r < 0.80 THEN 'completed'
        ELSE                        'failed'
      END)::tracer.execution_status,
      expanded.ts,
      CASE
        WHEN expanded.r >= 0.12
        THEN expanded.ts + ((0.1 + random() * 3.9) * interval '1 hour')
        ELSE NULL
      END
    FROM expanded
    RETURNING id, tenant_id, started_at, status::text AS status
  )
  INSERT INTO _seed_execs (id, tenant_id, started_at, status)
  SELECT id, tenant_id, started_at, status FROM ins;

END $block2$;

-- ── BLOQUE 3 — trazabilidad ───────────────────────────────────────────────────
DO $block3$
BEGIN

  -- execution_steps: 5 por execution = ~2 000 filas (tabla principal R-11)
  WITH ins AS (
    INSERT INTO tracer.execution_steps
      (tenant_id, execution_id, agent_id, step_number, reasoning, tools_used, occurred_at)
    SELECT
      ex.tenant_id,
      ex.id,
      (SELECT ag.id FROM _seed_agents ag
       WHERE ag.tenant_id = ex.tenant_id
       ORDER BY random() LIMIT 1),
      sn,
      jsonb_build_object(
        'thought',     'Procesando paso ' || sn,
        'confidence',  round((0.5 + random() * 0.5)::numeric, 2),
        'tokens_used', (50 + random() * 450)::int
      ),
      (CASE (random() * 3)::int
        WHEN 0 THEN ARRAY['web_search']
        WHEN 1 THEN ARRAY['code_interpreter','data_analyzer']
        WHEN 2 THEN ARRAY['api_caller']
        ELSE        ARRAY['file_reader','web_search']
      END),
      ex.started_at + (sn * (random() * interval '15 minutes'))
    FROM _seed_execs ex
    CROSS JOIN generate_series(1, 5) sn
    RETURNING id
  )
  INSERT INTO _seed_steps (id) SELECT id FROM ins;

  -- token_costs: 1 garantizado por execution + 50 % de chance de un segundo = ~600
  INSERT INTO tracer.token_costs
    (tenant_id, execution_id, step_id, input_tokens, output_tokens, estimated_cost, recorded_at)
  SELECT
    ex.tenant_id,
    ex.id,
    NULL,
    inp,
    out_,
    round((inp * 0.000003 + out_ * 0.000015)::numeric, 4),
    ex.started_at + (random() * interval '4 hours')
  FROM _seed_execs ex
  CROSS JOIN generate_series(1, 2) c
  CROSS JOIN LATERAL (
    SELECT
      (200 + random() * 3800)::int AS inp,
      (50  + random() * 950)::int  AS out_
  ) tokens
  WHERE c = 1 OR random() < 0.5;

  -- execution_errors: solo para executions fallidas (~20 % = ~80 filas)
  INSERT INTO tracer.execution_errors
    (tenant_id, execution_id, step_id, error_type, message, severity, occurred_at)
  SELECT
    ex.tenant_id,
    ex.id,
    NULL,
    (ARRAY['TimeoutError','ValidationError','APIError','RuntimeError','OOMError'])
      [1 + (random() * 4)::int],
    'Execution aborted: ' || substr(md5(ex.id::text), 1, 16),
    (ARRAY['low','medium','high','critical']::tracer.error_severity[])
      [1 + (random() * 3)::int],
    ex.started_at + (random() * interval '2 hours')
  FROM _seed_execs ex
  WHERE ex.status = 'failed';

  -- audit_logs: 5 acciones por usuario = ~100 filas
  -- tabla particionada: occurred_at debe caer en 2026-04 a 2026-09
  INSERT INTO tracer.audit_logs
    (tenant_id, user_id, action, entity_type, entity_id, details, occurred_at)
  SELECT
    u.tenant_id,
    u.id,
    (ARRAY['created','updated','deleted','activated','deactivated'])
      [1 + (random() * 4)::int],
    (ARRAY['swarm','task','agent','user'])
      [1 + (random() * 3)::int],
    gen_random_uuid(),
    jsonb_build_object(
      'ip',      '10.0.' || (random() * 255)::int || '.' || (random() * 255)::int,
      'browser', 'Mozilla/5.0'
    ),
    '2026-04-01'::timestamptz + (random() * interval '180 days')
  FROM _seed_users u
  CROSS JOIN generate_series(1, 5) a;

END $block3$;
