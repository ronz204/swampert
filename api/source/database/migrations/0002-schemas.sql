-- 0002-schemas.sql
--
-- Propósito: crear los dos esquemas lógicos del dominio.
--
-- core   → entidades de configuración: companies, users, agents, swarms, tasks.
-- tracer → registro de ejecuciones: executions, steps, costs, errors, audit.
--
-- La separación refleja el ritmo de cambio: core cambia con la configuración,
-- tracer crece indefinidamente con cada ejecución y nunca se modifica.

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS tracer;
