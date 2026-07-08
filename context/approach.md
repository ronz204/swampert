# Swampert — Requerimientos y restricciones técnicas

Este documento reúne, en un solo lugar, **todo lo que el proyecto está obligado a cumplir** a nivel técnico. Es una checklist de referencia: cualquier decisión de diseño o implementación debería poder justificarse contra algo de acá.

## Restricciones generales

- El motor de base de datos debe ser **PostgreSQL exclusivamente**.
- La base de datos debe tener un **mínimo de 10 tablas con 5 o más atributos cada una** (las tablas de catálogo simple no cuentan para ese mínimo).
- Esas tablas deben organizarse en **al menos 2 esquemas lógicos** (`CREATE SCHEMA`), separando módulos funcionales del sistema, con justificación de esa separación.
- Debe usarse **al menos 2 tipos de datos avanzados** de PostgreSQL entre: `UUID` (como PK), `JSONB`, `ARRAY` o `ENUM` — cada uso debe tener sentido real para el dominio, no estar "de relleno".
- Debe demostrarse **normalización completa hasta 3FN**, mostrando el proceso paso a paso (1FN → 2FN → 3FN) para al menos 2 tablas.

## Modelado

- **Modelo Entidad-Relación (E-R)** completo, con cardinalidades y atributos clave.
- **Modelo relacional** derivado del E-R: cada relación con nombre, atributos, PK identificada y FK indicada claramente.

## Seguridad

- Al menos **3 roles diferenciados** en PostgreSQL:
  - Administrador (superuser).
  - Usuario de aplicación (acceso restringido a tablas y funciones específicas).
  - Usuario de respaldo (solo `CONNECT` + `pg_dump`).
  - Scripts de `GRANT`/`REVOKE` documentados para cada uno.
- Al menos **una política de Row-Level Security (RLS)** sobre una tabla sensible, demostrada funcionando con **dos sesiones de usuario distintas**.
- Al menos **un campo sensible cifrado con `pgcrypto`** (`crypt()` con algoritmo `bf`/bcrypt). No se acepta MD5 ni texto plano.

## Rendimiento y consultas

- **Índices**:
  - Mínimo 2 índices no clúster B-Tree en columnas usadas frecuentemente en `WHERE`/`JOIN`/`ORDER BY`.
  - Mínimo 1 índice clúster (tabla reorganizada físicamente con `CLUSTER tabla USING indice`), demostrando con `EXPLAIN` el cambio de `Seq Scan` a `Index Scan`.
- **Consultas optimizadas**: al menos 3 consultas que involucren 3 o más tablas cada una, cada una acompañada de:
  - Código SQL.
  - `EXPLAIN ANALYZE` sin índice.
  - `EXPLAIN ANALYZE` con índice.
  - Porcentaje de reducción de costo observado.
- **Volumen de datos de prueba**: al menos 10 000 filas realistas en un mínimo de 3 tablas principales, generadas por script (PL/pgSQL con `generate_series`/`random`/`md5`, o `COPY`) — el volumen es necesario para que los planes de ejecución muestren diferencias reales entre consultas con y sin índice.

## Bases de datos distribuidas

Debe implementarse **una** de las siguientes tres técnicas sobre Docker, elegida y justificada según el dominio:

- **Federación** (`postgres_fdw`): segundo contenedor PostgreSQL, `CREATE SERVER`, `CREATE USER MAPPING`, 2 o más `CREATE FOREIGN TABLE`, y una consulta con `JOIN` entre tabla local y remota demostrada.
- **Particionamiento (sharding)**: tabla particionada por `PARTITION BY RANGE` o `HASH`, mínimo 3 particiones, con partition pruning visible en `EXPLAIN`.
- **Replicación streaming**: nodo primario + réplica en `docker-compose`, con escritura visible en la réplica en modo solo lectura.

Cualquiera sea la técnica elegida, debe entregarse un `docker-compose.yml` funcional junto con los scripts SQL correspondientes.

## Sistema Dashboard

Debe construirse un sistema tipo dashboard, con **dos pantallas separadas por pestañas** (no una sola vista con dos secciones):

- **Pantalla 1 — Dashboard**: vista visual con tarjetas de KPI y gráficos (dona, barras, línea). Sin tablas de datos crudos ni panel de filtros — su propósito es lectura rápida de indicadores.
- **Pantalla 2 — Consultas**: vista independiente donde las mismas consultas optimizadas se presentan en formato de tabla, junto con un **panel de filtros lateral estilo Periscope/Looker**:
  - Filtros agrupados por categoría.
  - Checkboxes o botones de radio según corresponda.
  - Contador de registros junto a cada opción.
  - Buscador dentro del grupo cuando la lista de opciones sea larga.
  - Chips visuales de filtros activos.
  - Botones de Reiniciar / Aplicar.
  - Al aplicar un filtro, la tabla debe actualizar en vivo tanto los resultados como el conteo de filas visibles.

Cada una de las consultas del dashboard debe cumplir, además, con los mismos requisitos de la sección de rendimiento: involucrar 3+ tablas, estar respaldada por un índice, y mostrar SQL + `EXPLAIN ANALYZE` antes/después con reducción de costo documentada.

## Documentación técnica

Debe entregarse un documento técnico que incluya, como mínimo:

- Resumen ejecutivo.
- Descripción del dominio.
- Desarrollo técnico completo: E-R, modelo relacional, esquemas, seguridad, índices, técnica de base de datos distribuida (con su justificación), y dashboard.
- Conclusiones y recomendaciones.
- Bibliografía en formato APA (7.ª edición).
