# Swampert — Requerimientos y restricciones técnicas

Este documento reúne, en un solo lugar, **todo lo que el proyecto está obligado a cumplir** a nivel técnico, según el enunciado oficial (ISW-522, Proyecto I). Es una checklist de referencia: cualquier decisión de diseño o implementación debería poder justificarse contra algo de acá.

> **Nota de esta revisión:** esta versión reconcilia el `approach.md` anterior contra el PDF oficial del profesor. Donde había una diferencia entre lo que decía el harness y lo que pide realmente el enunciado, se documenta la discrepancia y se explica cuál número es el correcto y por qué. Ver la sección final "Aclaraciones sobre ambigüedades del enunciado original" para el detalle.

## Restricciones generales

- El motor de base de datos debe ser **PostgreSQL exclusivamente**.
- La base de datos debe tener un **mínimo de 10 tablas con 5 o más atributos cada una** (las tablas de catálogo simple no cuentan para ese mínimo). *(La descripción general del enunciado y R-02 piden 10 explícitamente; una fila de la rúbrica dice "8+", pero se toma 10 como número real porque es el requisito detallado, no el resumen de rúbrica — ver aclaraciones al final.)*
- Esas tablas deben organizarse en **al menos 2 esquemas lógicos** (`CREATE SCHEMA`), separando módulos funcionales del sistema, con justificación de esa separación.
- Debe usarse **al menos 2 tipos de datos avanzados** de PostgreSQL entre: `UUID` (como PK), `JSONB`, `ARRAY` o `ENUM` — cada uso debe tener sentido real para el dominio, no estar "de relleno".
- Debe demostrarse **normalización completa hasta 3FN**, mostrando el proceso paso a paso (1FN → 2FN → 3FN) para al menos 2 tablas.

## Modelado

- **Modelo Entidad-Relación (E-R)** completo, con cardinalidades y atributos clave. Se entrega como imagen o PDF (va en `01_Modelos/`).
- **Modelo relacional** derivado del E-R: cada relación con nombre, atributos, **PK subrayada** y **FK indicada con flecha** (notación explícita que pide el enunciado, no solo "PK/FK identificadas"). Mínimo 10 tablas con 5+ atributos.

## Seguridad

- Al menos **3 roles diferenciados** en PostgreSQL:
  - Administrador (superuser).
  - Usuario de aplicación (acceso restringido a tablas y funciones específicas).
  - Usuario de respaldo (solo `CONNECT` + `pg_dump`).
  - Scripts de `GRANT`/`REVOKE` documentados para cada uno.
- Al menos **una política de Row-Level Security (RLS)** sobre una tabla sensible, demostrada funcionando con **dos sesiones de usuario distintas**.
- Al menos **un campo sensible cifrado con `pgcrypto`** (`crypt()` con algoritmo `bf`/bcrypt). No se acepta MD5 ni texto plano.

## Rendimiento y consultas

### Índices

- **Mínimo 2 índices no clúster B-Tree** en columnas usadas frecuentemente en `WHERE`/`JOIN`/`ORDER BY`.
- **Mínimo 3 índices clúster**: reorganizar físicamente 3 tablas distintas con `CLUSTER tabla USING nombre_indice`, demostrando con `EXPLAIN` el cambio de `Seq Scan` a `Index Scan` con menor costo tras el `CLUSTER`, para cada una. *(El enunciado (R-09b) pide explícitamente 3, no 1 — una tabla solo puede tener un índice clúster activo a la vez, así que esto implica clusterizar 3 tablas diferentes del modelo.)*
- **Mínimo 1 índice GIN**, sobre una columna `JSONB` o `ARRAY` donde tenga sentido buscar dentro del contenido (ej. `reasoning`, `config`, `details`, o `tools`/`tools_used`). *(No estaba explícito como ítem propio en la versión anterior de este documento, pero la rúbrica lo puntúa como categoría separada, y R-13(b) lo lista como tipo de índice válido.)*

### Consultas optimizadas — cuántas son realmente

El enunciado menciona números distintos en dos lugares, y **no son conjuntos separados**:

- R-10 (sección general de rendimiento) pide "al menos 3 consultas" con el tratamiento completo de rendimiento.
- R-13 (dashboard) pide "al menos 5 consultas tipo reporte" con ese mismo tratamiento, más visualización.

Como el conjunto de R-13 (5) ya cumple de sobra el mínimo de R-10 (3), **el número real a construir es 5 consultas optimizadas**, no 3 y luego 5 más. Cada una de esas 5 debe tener:

- Código SQL.
- `EXPLAIN ANALYZE` **sin** índice.
- `EXPLAIN ANALYZE` **con** índice.
- Porcentaje de reducción de costo observado.
- Involucrar **3 o más tablas**.
- Estar respaldada por un índice (B-Tree, GIN o el resultado de un `CLUSTER`, según corresponda).
- Representarse mediante **al menos un gráfico** (barras, línea, dona, área) en la Pantalla 1 (Dashboard).
- Estar disponible también en **formato de tabla con panel de filtros** en la Pantalla 2 (Consultas).

### Volumen de datos de prueba

- Al menos **10 000 filas realistas** en un mínimo de **3 tablas principales**, generadas por script (PL/pgSQL con `generate_series`/`random`/`md5`, o `COPY`) — el volumen es necesario para que los planes de ejecución muestren diferencias reales entre consultas con y sin índice.

## Bases de datos distribuidas

Debe implementarse **una** de las siguientes tres técnicas sobre Docker, elegida y justificada según el dominio:

- **Federación** (`postgres_fdw`): segundo contenedor PostgreSQL, `CREATE SERVER`, `CREATE USER MAPPING`, 2 o más `CREATE FOREIGN TABLE`, y una consulta con `JOIN` entre tabla local y remota demostrada.
- **Particionamiento (sharding)**: tabla particionada por `PARTITION BY RANGE` o `HASH`, mínimo 3 particiones, con partition pruning visible en `EXPLAIN`.
- **Replicación streaming**: nodo primario + réplica en `docker-compose`, con escritura visible en la réplica en modo solo lectura.

Cualquiera sea la técnica elegida, debe entregarse un `docker-compose.yml` funcional junto con los scripts SQL correspondientes.

**Nota sobre una posible superposición con `database.md`:** el particionamiento por rango de fecha de `tracer.executions` y `tracer.audit_logs` ya documentado en `database.md` es, en principio, la misma técnica que la Opción B de este requisito (particionamiento/sharding). Si esa partición tiene 3 o más particiones reales y se demuestra partition pruning en `EXPLAIN`, **podría satisfacer directamente R-12** sin necesidad de implementar una técnica distribuida completamente separada. Esto todavía no está decidido — hay que declarar explícitamente cuál de las tres opciones se usa para este requisito, y si es la Opción B, dejar claro que es la misma partición ya diseñada por motivos de rendimiento, cumpliendo doble propósito.

## Sistema Dashboard

Debe construirse un sistema tipo dashboard, con **dos pantallas separadas por pestañas** (no una sola vista con dos secciones). Al cambiar de pestaña debe cambiar el layout completo (navegación secundaria y componentes); no deben coexistir ambos diseños en una misma vista.

- **Pantalla 1 — Dashboard**: vista visual con tarjetas de KPI y gráficos (dona, barras, línea). Sin tablas de datos crudos ni panel de filtros — su propósito es lectura rápida de indicadores.
- **Pantalla 2 — Consultas**: vista independiente donde las mismas **5 consultas optimizadas** (ver sección anterior) se presentan en formato de tabla, junto con un **panel de filtros lateral estilo Periscope/Looker**:
  - Filtros agrupados por categoría (ej. Servicio, Estado, Rango de Fecha).
  - Checkboxes o botones de radio según corresponda.
  - Contador de registros junto a cada opción.
  - Buscador dentro del grupo cuando la lista de opciones sea larga.
  - Chips visuales de filtros activos.
  - Botones de Reiniciar / Aplicar.
  - Al aplicar un filtro, la tabla debe actualizar en vivo tanto los resultados como el conteo de filas visibles.

## Documentación técnica

Debe entregarse un documento técnico que incluya, como mínimo:

- Portada.
- Tabla de contenidos.
- Resumen ejecutivo.
- Descripción del dominio.
- Desarrollo técnico completo: E-R, modelo relacional, esquemas, seguridad, índices, técnica de base de datos distribuida (con su justificación), y dashboard.
- Conclusiones y recomendaciones.
- Bibliografía en formato APA (7.ª edición).

## Estructura de entrega

Todo el material se entrega en un único `.zip` o `.rar` (si supera 25 MB, se acepta un enlace de Google Drive con acceso habilitado para el profesor), con esta estructura de carpetas obligatoria:

| Carpeta / Archivo | Contenido |
|---|---|
| `01_Modelos/` | E-R (imagen o PDF) + Modelo relacional (imagen o PDF) |
| `02_Scripts/01_ddl.sql` | `CREATE SCHEMA`, `CREATE TABLE`, constraints, tipos, índices |
| `02_Scripts/02_seguridad.sql` | Roles, `GRANT`/`REVOKE`, RLS, pgcrypto |
| `02_Scripts/03_datos_prueba.sql` | Inserción de 10 000+ filas por tabla principal |
| `02_Scripts/04_consultas_optimizadas.sql` | Las 5 consultas con `EXPLAIN ANALYZE` antes/después de índices |
| `02_Scripts/05_distribuida.sql` | Script de la técnica distribuida elegida + `docker-compose.yml` |
| `02_Scripts/06_dashboard/` | Archivo(s) del sistema dashboard |
| `03_Documentacion/` | Documento técnico (.docx o .pdf) + README de instalación |

**Correspondencia con el plan de migraciones de Swampert:** el `ddl.sql` consolidado que se va a ensamblar al final a partir de todos los archivos de migración numerados (`0000-extensions.sql`, `0001-migrations.sql`, etc.) es exactamente lo que va en `02_Scripts/01_ddl.sql`. De la misma forma, la migración de seguridad planificada (roles, GRANTs y RLS juntos al final) corresponde a `02_Scripts/02_seguridad.sql`.

El README debe permitir que el profesor ejecute los scripts en orden desde cero y obtenga la BD completamente funcional en **menos de 10 minutos**, y debe **declarar explícitamente el uso de herramientas de IA** (requisito de integridad académica del enunciado — el uso de IA está permitido siempre que el grupo pueda explicar todo el código en la revisión oral).

## Aspectos administrativos importantes (no técnicos, pero críticos)

Estos puntos no afectan el diseño de la base de datos, pero son condiciones del enunciado que conviene tener presentes:

- **El proyecto es grupal, de 2 o 3 personas, sin excepción**, según el enunciado oficial. Esto es una discrepancia real con el desarrollo en solitario documentado hasta ahora — vale la pena confirmarlo con el profesor.
- **Revisión oral** el mismo día de la entrega, 20 minutos por grupo, con demostración en vivo del sistema completo (el profesor puede pedir cualquier consulta, inserción, actualización o cambio de permisos en vivo).
- **Fechas**: el PDF del enunciado tiene tres fechas distintas para la entrega final (portada: 15 de julio; sección de entrega: 14 de julio 11:59 p.m.; cronograma/Hito 7: 02 de julio de 2026). Conviene confirmar con el profesor cuál rige antes de planificar el resto del cronograma contra una fecha equivocada.

## Aclaraciones sobre ambigüedades del enunciado original

- **Mínimo de tablas (10 vs 8+)**: la descripción general y R-02 piden 10 tablas con 5+ atributos; una fila de la rúbrica ("Estructura DDL") dice "8+ tablas". Se prioriza 10 porque es el número que aparece en los requisitos detallados (R-01/R-02), mientras que la rúbrica es un resumen de puntaje y probablemente arrastra una imprecisión de redacción.
- **Índices clúster (1 vs 3)**: R-09(b) dice explícitamente "mínimo 3 índice clúster"; una fila de rúbrica lo menciona en singular ("índice clúster con CLUSTER demostrado"). Se toma 3 como el número real porque es el requisito con puntaje explícito (R-09, 14 pts) y detalla el mecanismo exacto de verificación (`EXPLAIN` antes/después del `CLUSTER`).
- **Consultas optimizadas (3 vs 5)**: no son dos entregables distintos — ver la sección "Rendimiento y consultas" arriba. El número real es 5, y ese conjunto cubre ambos requisitos porque 5 ≥ 3.
- **Índice GIN**: aparece mencionado en la rúbrica y en R-13(b), pero no estaba como ítem explícito en las secciones de requisitos anteriores de este documento. Se agrega como requisito propio para no perder puntos por omisión.