-- 0015-security.sql
--
-- Propósito: crear los tres roles de PostgreSQL y asignar sus privilegios.
--
-- swampert_admin  → superuser, corre migraciones y administra el sistema.
-- swampert_app    → DML completo sobre core y tracer. Rol de la aplicación.
-- swampert_backup → solo SELECT para pg_dump. Sin acceso de escritura.
--
-- Los DO-blocks evitan error si el rol ya existe (idempotente por si se
-- ejecuta fuera del migrator, que ya previene re-ejecuciones por sí solo).

-- Revoca acceso público por defecto a los schemas de dominio
REVOKE ALL ON SCHEMA core, tracer FROM PUBLIC;

-- ==========================================
-- Roles
-- ==========================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'swampert_admin') THEN
    CREATE ROLE swampert_admin WITH LOGIN PASSWORD 'swampert_admin_2026' SUPERUSER;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'swampert_app') THEN
    CREATE ROLE swampert_app WITH LOGIN PASSWORD 'swampert_app_2026';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'swampert_backup') THEN
    CREATE ROLE swampert_backup WITH LOGIN PASSWORD 'swampert_backup_2026';
  END IF;
END $$;

-- ==========================================
-- swampert_app
-- ==========================================

GRANT CONNECT ON DATABASE swampert TO swampert_app;
GRANT USAGE ON SCHEMA core, tracer TO swampert_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core   TO swampert_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA tracer TO swampert_app;

-- Aplica a tablas que se creen en el futuro dentro de estos schemas
ALTER DEFAULT PRIVILEGES IN SCHEMA core   GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO swampert_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA tracer GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO swampert_app;

-- ==========================================
-- swampert_backup
-- ==========================================

GRANT CONNECT ON DATABASE swampert TO swampert_backup;
GRANT USAGE ON SCHEMA core, tracer TO swampert_backup;

GRANT SELECT ON ALL TABLES IN SCHEMA core   TO swampert_backup;
GRANT SELECT ON ALL TABLES IN SCHEMA tracer TO swampert_backup;

ALTER DEFAULT PRIVILEGES IN SCHEMA core   GRANT SELECT ON TABLES TO swampert_backup;
ALTER DEFAULT PRIVILEGES IN SCHEMA tracer GRANT SELECT ON TABLES TO swampert_backup;
