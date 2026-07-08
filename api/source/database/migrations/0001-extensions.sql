-- 0001-extensions.sql
--
-- Propósito: habilitar las extensiones de PostgreSQL que necesita Swampert,
-- y nada más. Ninguna tabla ni esquema del dominio se crea acá.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
