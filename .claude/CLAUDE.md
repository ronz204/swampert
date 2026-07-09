# Swampert — CLAUDE.md

## Qué es este proyecto

Swampert es una **plataforma multi-tenant de orquestación y auditoría de enjambres de agentes de IA**. No ejecuta agentes reales ni llama a modelos de lenguaje: modela y audita todo el ciclo de vida de una tarea resuelta por un swarm — quién hizo qué, cuánto costó en tokens, qué salió mal, y quién puede ver qué.

Referencia obligatoria antes de cualquier tarea no trivial: `context/overview.md` (qué es), `context/problems.md` (por qué existe), `context/modeling.md` (modelo de dominio DDD), `context/database.md` (esquema PostgreSQL), `context/concepts.md` (conceptos técnicos clave), `context/approach.md` (requerimientos y restricciones técnicas del proyecto: esquemas, seguridad, índices, rendimiento, bases distribuidas, dashboard y documentación), `context/sqlqueries.md` (las 3 consultas optimizadas del dashboard: SQL, índices demostrados y procedimiento EXPLAIN ANALYZE), `context/seedings.md` (plan de seed de datos: volúmenes objetivo, estrategia de FKs, distribuciones de estados y consideraciones para CLUSTER).

---

## Lenguaje ubicuo — úsalo siempre, sin excepciones

| Término en código | Significado |
|---|---|
| `Tenant` | El cliente. Raíz de todo: nada existe sin pertenecer a un tenant. Se identifica por `slug` (subdominio). |
| `User` | Humano que opera Swampert dentro de un tenant. |
| `Agent` | Unidad de IA con rol y herramientas. Puede integrar varios swarms. |
| `Swarm` | Grupo de agents que colaboran para resolver tasks. |
| `Task` | El encargo concreto que se le hace a un swarm. |
| `Execution` | Un intento de resolver una task (puede haber reintentos). |
| `ExecutionStep` | Acción puntual de un agent dentro de una execution. Unidad mínima de trazabilidad. |
| `TokenCost` | Gasto en tokens (y dinero) de una execution o step. |
| `ExecutionError` | Fallo ocurrido durante una execution o step. |
| `AuditLog` | Registro inmutable de una acción de un User sobre la configuración. |

Si en algún archivo, variable o función se usa un sinónimo distinto, es una señal de alerta — corregir hacia este glosario.

---

## Stack técnico

```
swampert/
├── api/          # Backend — Python 3.14+, asyncpg (SQL crudo), Pydantic, uv
│   ├── source/   # Código fuente
│   ├── compose.yml  # PostgreSQL 16 vía Docker
│   └── pyproject.toml
└── client/       # Frontend — SvelteKit 2 + Svelte 5, TypeScript, Vite, Bun
    └── src/
```

**No hay ORM.** El acceso a base de datos es SQL crudo con `asyncpg`, a propósito. No introducir SQLAlchemy, Tortoise ni ningún ORM. La trazabilidad entre la query documentada en `context/database.md` y el código que corre es un objetivo explícito del proyecto.

---

## Modelo de dominio — reglas que el código debe respetar

### Agregados y sus invariantes

**Tenant** — raíz de todo el árbol. Ninguna entidad cruza de un tenant a otro, jamás.

**Swarm** — necesita al menos un Agent para poder recibir Tasks. Un Swarm sin agents no puede ejecutar nada.

**Task** — pertenece a un único Swarm, y ese Swarm debe ser del mismo Tenant.

**Execution** — el agregado más rico. Contiene ExecutionSteps, TokenCosts y ExecutionErrors. Reglas críticas:
- El status solo avanza en una dirección válida: `pending → running → completed | failed`. Nunca regresa.
- No se pueden agregar steps, costs ni errors a una execution con status `completed` o `failed`.
- El costo total de una execution es la suma de sus steps — nunca un número calculado aparte.

**AuditLog** — append-only. Una vez creado, nunca se modifica ni se borra. No tiene transiciones de estado.

### DDD estratégico, no táctico

Se usa el lenguaje y los agregados de DDD para razonar sobre el dominio, pero **no** hay clases de entidad con comportamiento, ni Repository pattern, ni domain events en código. Las invariantes de los agregados se implementan como validaciones en funciones simples, no como métodos de clase. No adelantar esta migración salvo que aparezca una regla de negocio genuinamente compleja que lo justifique.

---

## Base de datos — convenciones que no se negocian

- **Clave primaria**: siempre `UUID`, generado en inserción con `gen_random_uuid()`. Nunca enteros autoincrementales.
- **Aislamiento**: toda tabla cuyo contenido pertenece a un tenant lleva columna `tenant_id` (FK → `core.tenants.id`) explícita, incluso si podría inferirse por JOIN.
- **Timestamps**: toda tabla tiene `created_at TIMESTAMPTZ`. Las que cambian de estado también tienen `updated_at`.
- **ENUMs**: cualquier conjunto cerrado de valores se modela como `ENUM` de PostgreSQL, en el mismo schema que la tabla que lo usa.
- **RLS**: toda tabla con `tenant_id` lleva política de Row-Level Security. El aislamiento multi-tenant es una garantía de la base de datos, no de la aplicación.

### Tablas (en orden de estabilidad)

`core.tenants` → `core.users` → `core.agents` → `core.swarms` → `core.swarm_agents` (puente M:N) → `core.tasks` → `tracer.executions` → `tracer.execution_steps` → `tracer.token_costs` → `tracer.execution_errors` → `tracer.audit_logs`

### Particionamiento

`tracer.executions` (por `started_at`) y `tracer.audit_logs` (por `occurred_at`) se particionan por rango mensual. Son las únicas tablas de crecimiento ilimitado.

### Tipos avanzados — por qué, no solo dónde

- `JSONB` en `agents.config`, `execution_steps.reasoning`, `audit_logs.details`: datos semi-estructurados que varían por instancia.
- `TEXT[]` en `agents.tools`, `execution_steps.tools_used`: listas cortas y homogéneas.
- Estos usos **no son violaciones de 1FN**: son decisiones de diseño deliberadas, comunes en PostgreSQL moderno, documentadas y justificadas.

---

## Comandos de desarrollo

```bash
# Base de datos (desde api/)
docker compose up -d                          # Levanta PostgreSQL 16
uv run python -m source.database.migrator     # Corre las migraciones

# API (desde api/)
uv run source/boot.py         # Punto de entrada (en desarrollo)
uv run ruff check source/     # Linter
uv run ruff format source/    # Formatter

# Cliente (desde client/)
bun dev                       # Dev server (Vite)
bun run check                 # Type check (svelte-check)
bun run build                 # Build de producción
```

---

## Convenciones de código

- Nombres de tablas, columnas, tipos SQL y entidades de código: **inglés**.
- Prosa en documentación y comentarios: **español**.
- Sin comentarios que expliquen qué hace el código — solo el porqué cuando no es obvio.
- Sin abstracciones especulativas. Si algo no lo pide una feature concreta hoy, no se construye.
- Sin ORM, sin mocking de base de datos en tests. Los tests que tocan datos deben usar una base real.
- Validación solo en los bordes del sistema (input del usuario, respuestas de APIs externas). No validar lo que el propio código garantiza.

---

## Lo que Swampert NO hace (alcance acotado a propósito)

- No ejecuta agentes de IA reales.
- No llama a modelos de lenguaje.
- No gestiona credenciales de proveedores de IA.
- No implementa colas de trabajo ni planificadores de tareas.

Cualquier sugerencia que cruce estas fronteras está fuera de alcance del proyecto.
