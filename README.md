# Swampert — Plataforma de auditoría de enjambres de agentes IA

Swampert es una plataforma multi-tenant para orquestar y auditar el ciclo de vida completo de swarms de agentes de IA: quién hizo qué, cuánto costó en tokens, qué falló, y quién puede ver qué.

---

## Stack

| Capa | Tecnología |
|---|---|
| API | Python 3.14+, FastAPI, asyncpg, Pydantic, uv |
| Base de datos | PostgreSQL 16 (Docker) |
| Cliente | SvelteKit 2, Svelte 5, TypeScript, Tailwind CSS 4, Bun |

---

## Prerrequisitos (Windows + Scoop)

Instala las herramientas necesarias con [Scoop](https://scoop.sh). Si aún no tienes Scoop:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

Luego instala las dependencias:

```powershell
# Agrega los buckets necesarios
scoop bucket add main
scoop bucket add extras

# Herramientas
scoop install main/python          # Python 3.14+
scoop install main/uv              # Gestor de entornos Python
scoop install main/bun             # Runtime + package manager JS
scoop install main/docker          # Docker CLI
scoop install extras/docker-desktop  # Docker Desktop (UI + daemon)
```

> Después de instalar Docker Desktop, ábrelo al menos una vez para que el daemon quede corriendo antes de continuar.

---

## Instalación

### 1. Clona el repositorio

```powershell
git clone <url-del-repo>
cd swampert
```

### 2. Base de datos

#### 2.1 Configura las variables de entorno

Copia el archivo de ejemplo dentro de `api/`:

```powershell
Copy-Item api\.env.sample api\.env.local
```

Edita `api\.env.local` y establece la contraseña que quieras para `POSTGRES_PASSWORD` y las URLs de conexión:

```env
POSTGRES_PORT=5432
POSTGRES_DB=swampert
POSTGRES_HOST=localhost
POSTGRES_USER=swampert_admin
POSTGRES_PASSWORD=swampert_admin_2026

POSTGRES_APP_URL="postgres://swampert_app:swampert_app_2026@localhost:5432/swampert"
POSTGRES_ADM_URL="postgres://swampert_admin:swampert_admin_2026@localhost:5432/swampert"
```

> Las contraseñas de los roles `swampert_app` y `swampert_backup` se crean automáticamente al correr las migraciones (migración `0015-security.sql`). Solo necesitas definir la contraseña del superusuario `swampert_admin` en `.env.local`.

#### 2.2 Levanta PostgreSQL

```powershell
cd api
docker compose up -d
```

#### 2.3 Corre las migraciones

```powershell
# Desde api/
uv run python -m source.database.migrator
```

Esto aplica todas las migraciones en orden, crea los schemas `core` y `tracer`, los roles de base de datos y siembra datos de ejemplo.

### 3. API

```powershell
# Desde api/
uv run uvicorn source.boot:app --reload
```

La API queda disponible en `http://localhost:8000`. Documentación interactiva en `http://localhost:8000/docs`.

### 4. Cliente

```powershell
# Desde client/
bun install
bun dev
```

El cliente queda disponible en `http://localhost:5173`.

> El cliente usa subdominios para identificar el tenant activo (ej. `http://acme.localhost:5173`). Asegúrate de que tu navegador resuelva subdominios de `localhost` correctamente — en Windows esto funciona de forma nativa en navegadores modernos (Chrome, Edge).

---

## Comandos de desarrollo

### API

```powershell
# Desde api/
uv run uvicorn source.boot:app --reload   # Servidor con hot-reload
uv run ruff check source/                  # Linter
uv run ruff format source/                 # Formatter
uv run python -m source.database.migrator  # Aplica migraciones pendientes
```

### Cliente

```powershell
# Desde client/
bun dev            # Dev server
bun run check      # Type check (svelte-check)
bun run build      # Build de producción
bun run preview    # Previsualiza el build de producción
```

### Base de datos

```powershell
# Desde api/
docker compose up -d      # Inicia PostgreSQL
docker compose down       # Detiene el contenedor (datos persistidos en volumen)
docker compose down -v    # Detiene y elimina el volumen (borra todos los datos)
```

---

## Estructura del proyecto

```
swampert/
├── api/
│   ├── source/
│   │   ├── boot.py                    # Punto de entrada FastAPI
│   │   ├── configs/                   # Configuración (settings, env vars)
│   │   ├── database/
│   │   │   ├── migrations/            # Archivos SQL en orden numérico
│   │   │   ├── functions/             # Queries por dominio (asyncpg)
│   │   │   ├── migrator.py            # Runner de migraciones
│   │   │   └── pooling.py             # Connection pool
│   │   └── presentation/
│   │       ├── controllers/           # Routers de FastAPI por recurso
│   │       └── middleware/            # Tenant middleware (resolución por subdominio)
│   ├── compose.yml                    # PostgreSQL 16 vía Docker
│   ├── .env.sample                    # Plantilla de variables de entorno
│   └── pyproject.toml
└── client/
    └── src/
        ├── common/                    # Utilidades y helpers compartidos
        ├── models/                    # Tipos TypeScript del dominio
        └── shared/                    # Componentes y lógica reutilizable
```

---

## Multi-tenancy

El tenant activo se resuelve por subdominio en cada request. La API lee el subdominio del header `Host` y lo usa para filtrar todos los datos vía Row-Level Security en PostgreSQL. Esto significa:

- `acme.localhost:5173` → datos del tenant `acme`
- `globex.localhost:5173` → datos del tenant `globex`

Los datos de distintos tenants nunca se mezclan, ni a nivel de aplicación ni a nivel de base de datos.
