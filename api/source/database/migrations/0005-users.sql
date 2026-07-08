-- 0005-users.sql
--
-- Propósito: crear core.users, los humanos que operan Swampert dentro de una company.
--
-- El campo password se almacena cifrado con bcrypt vía pgcrypto
-- (crypt(texto, gen_salt('bf'))). Nunca en texto plano ni MD5.

CREATE TABLE core.users (
  id         UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  UUID           NOT NULL REFERENCES core.tenants(id),
  name       TEXT           NOT NULL,
  email      TEXT           NOT NULL UNIQUE,
  password   TEXT           NOT NULL,
  role       core.user_role NOT NULL,
  active  BOOLEAN        NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ    NOT NULL DEFAULT now()
);

CREATE INDEX ON core.users (tenant_id);

ALTER TABLE core.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON core.users
  USING (tenant_id = current_setting('app.tenant_id')::UUID);
