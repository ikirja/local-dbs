# Plan: Local DBs for Testing via Docker Compose

## 1. Goal

Turn this empty directory into a Docker Compose project that runs local databases for testing, each reachable from other apps on the host via `localhost:<port>`.

First (and initially only) database: **MongoDB** on MongoDB's default port **27017**, so apps can connect with `mongodb://localhost:27017`.

The project must be structured so adding more databases later (Postgres, Redis, MySQL, etc.) is a small, mechanical change.

## 2. Current state

- `/Users/kirillmakeev/Development/local-dbs` is empty.
- Not a git repository yet (git init required for change tracking).

## 3. Design decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Use `compose.yaml` (new-style filename) at project root | Modern Docker Compose default; `docker compose` picks it up automatically |
| D2 | Pin MongoDB image to `mongo:8.0` via `.env` (`MONGO_VERSION`) | 8.0 is the current stable major (latest 8.0.x = 8.0.32); pinning avoids surprise upgrades; `.env` makes it configurable |
| D3 | Publish port as `127.0.0.1:27017:27017` | Apps on the host reach Mongo at `localhost:27017`; binding to loopback only keeps the DB off the LAN |
| D4 | Use a named volume `mongo-data` mounted at `/data/db` | Data survives `docker compose down`; reset is explicit via `docker compose down -v` |
| D5 | Add a healthcheck (`mongosh` ping) | Apps and the user can wait for readiness; `docker compose ps` shows `healthy` |
| D6 | No auth by default (no root user env vars) | Simplest setup for local testing; `MONGO_INITDB_ROOT_USERNAME/PASSWORD` can be added later if auth is needed |
| D7 | Gitignore `.env`; commit `.env.example` | `.env` may later hold credentials; `.env.example` documents the variables |
| D8 | Add a small `Makefile` for common commands | Shorter, memorable workflow (`make up`, `make logs`) |
| D9 | Set explicit project name `local-dbs` and container name `local-dbs-mongo` | Stable names; predictable `docker compose` project even if the folder is renamed |
| D10 | `restart: unless-stopped` | DBs come back up automatically after Docker daemon restart (e.g., laptop reboot) |

## 4. Files to create

```
local-dbs/
├── compose.yaml        # MongoDB service + volume definitions
├── .env.example        # Documented configuration template (committed)
├── .env                # Actual config, created by copying .env.example (gitignored)
├── .gitignore          # Ignore .env, .DS_Store, TEMP.md/TEMP_*.md
├── Makefile            # make up / down / logs / mongo / ps / reset
└── README.md           # Usage, connection strings, how to add another DB
```

### 4.1 `compose.yaml` (exact content)

```yaml
name: local-dbs

services:
  mongo:
    image: mongo:${MONGO_VERSION:-8.0}
    container_name: local-dbs-mongo
    ports:
      - "127.0.0.1:${MONGO_PORT:-27017}:27017"
    volumes:
      - mongo-data:/data/db
    healthcheck:
      test: ["CMD", "mongosh", "--quiet", "--eval", "db.adminCommand('ping').ok"]
      interval: 5s
      timeout: 5s
      retries: 12
      start_period: 10s
    restart: unless-stopped

volumes:
  mongo-data:
```

Notes:
- `${MONGO_VERSION:-8.0}` and `${MONGO_PORT:-27017}` come from `.env` when present, defaults otherwise.
- Healthcheck exits 0 when `db.adminCommand('ping')` returns ok — correct "ready" signal for Mongo.
- `name:` top-level key sets the compose project name; supported by Docker Compose v2.

### 4.2 `.env.example`

```
# MongoDB
MONGO_VERSION=8.0
MONGO_PORT=27017
```

### 4.3 `.gitignore`

```
.env
.DS_Store
TEMP.md
TEMP_*.md
```

### 4.4 `Makefile`

```make
.PHONY: up down restart ps logs mongo mongo-sh reset

up:            ## Start all databases
	docker compose up -d

down:          ## Stop all databases (keep data)
	docker compose down

restart:       ## Restart all databases
	docker compose restart

ps:            ## Show status
	docker compose ps

logs:          ## Follow all logs
	docker compose logs -f

mongo:         ## Open mongosh shell
	docker compose exec mongo mongosh

reset:         ## Stop and delete ALL data volumes (destructive)
	docker compose down -v
```

### 4.5 `README.md`

Sections:
1. **What this is** — Docker Compose project running local test databases on `localhost:<port>`.
2. **Prerequisites** — Docker Desktop / Docker Engine with Compose v2 (`docker compose version`).
3. **Quick start** — `cp .env.example .env && make up`; wait for `healthy` in `make ps`.
4. **Connection strings** — table with one row: MongoDB → `mongodb://localhost:27017`.
5. **Common commands** — the `make` targets above.
6. **Reset data** — `make reset` (destructive).
7. **Adding another database** — step-by-step template (see section 8).
8. **Troubleshooting** — port already in use (`lsof -i :27017`), healthcheck never turns green, stale volume after image upgrade.

## 5. Networking: how apps reach the DBs

- **Apps on the host (most common):** connect to `localhost:27017` / `127.0.0.1:27017`. The `127.0.0.1:` port binding makes the port available only on the host's loopback interface.
- **Apps in another container** (future need): either join the same user-defined network (connect at `mongo:27017`) or use `host.docker.internal:27017` from a container on the default bridge network.
- **LAN access** (not the default): change the binding to `0.0.0.0:${MONGO_PORT:-27017}:27017`. Documented in README as optional.

## 6. Implementation steps (ordered)

1. `git init` the repo (currently not a git repo).
2. Create `compose.yaml` with the exact content from 4.1.
3. Create `.env.example` and `.env` (copy of `.env.example`).
4. Create `.gitignore` (include `.env`, `.DS_Store`, `TEMP.md`, `TEMP_*.md`).
5. Create `Makefile` (content from 4.4).
6. Create `README.md` (sections from 4.5).
7. Validate: `docker compose config` → must render without errors and show the resolved port/version.
8. Start and verify:
   - `make up`
   - `make ps` → container must reach `healthy`
   - `mongosh --eval "db.runCommand({ ping: 1 })"` (or `nc -z localhost 27017`) succeeds
9. Persistence check: insert a doc, `make restart`, confirm the doc is still there.

## 7. Definition of done

- `docker compose config` validates cleanly.
- `docker compose up -d` starts `local-dbs-mongo`, which reports `healthy`.
- `mongodb://localhost:27017` is connectable from the host (verified with `mongosh` ping).
- Data survives container restarts (named volume).
- README documents usage, connection string, and the procedure for adding the next DB.

## 8. Extensibility — adding the next database (reference for later)

For each new DB, a mechanical change:
1. Add a service block to `compose.yaml`: `image`, `ports` (`127.0.0.1:<hostPort>:<containerPort>`), a named volume, and a healthcheck.
2. Add version/port variables to `.env.example` and `.env`.
3. Add a Makefile convenience target if useful.
4. Add a row to the README connection-string table.

Example for a future Postgres addition (not part of this plan's implementation):

```yaml
  postgres:
    image: postgres:${POSTGRES_VERSION:-17}
    container_name: local-dbs-postgres
    ports:
      - "127.0.0.1:${POSTGRES_PORT:-5432}:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 12
    restart: unless-stopped
```

## 9. Out of scope

- Authentication/security hardening (local-only test DBs; auth can be layered on later).
- Replica sets / sharding / clustering.
- Apps running inside Docker (host `localhost:` access is the stated requirement).