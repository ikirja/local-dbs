# local-dbs

## What this is

A Docker Compose project that runs local test databases on your machine, each
reachable from host apps via `localhost:<port>`.

The project is structured so adding more databases (Postgres, Redis, ...) is a
mechanical change — see [Adding another database](#adding-another-database).

## Prerequisites

- Docker Desktop (or Docker Engine) with Compose v2 — check with
  `docker compose version`.
- The Docker daemon must be running (`docker info`).
- `make` (comes with macOS Xcode Command Line Tools and most Linux distros).
- On Windows, use WSL or call `docker compose ...` directly — the Makefile
  targets are shell-based.

## Quick start

```sh
cp .env.example .env
make up
```

`make up` starts the containers and waits until all healthchecks pass
(`docker compose up -d --wait`). `make ps` shows the status of every service.

## Connection strings

| Database | Connection string                |
|----------|----------------------------------|
| MongoDB  | `mongodb://localhost:27017`      |

The port binding is loopback-only (`127.0.0.1:<port>`), so the databases are
reachable from this machine but not exposed to the LAN. To expose a database to
the LAN (not the default), change the `ports` binding in `compose.yaml` from
`127.0.0.1:${MONGO_PORT:-27017}:27017` to `0.0.0.0:${MONGO_PORT:-27017}:27017`.

## Common commands

| Command         | What it does                                   |
|-----------------|------------------------------------------------|
| `make up`       | Start all databases, wait until healthy        |
| `make down`     | Stop all databases (keep data)                 |
| `make restart`  | Restart all databases                          |
| `make ps`       | Show container status (health column)          |
| `make logs`     | Follow all logs                                |
| `make mongo`    | Open a `mongosh` shell in the MongoDB container |
| `make reset`    | Stop and delete ALL data (destructive)         |

## Reset data

`make reset` runs `docker compose down -v`, which stops the containers and
deletes the named volumes — i.e. all database data. It is destructive and
cannot be undone.

## Adding another database

For each new database, the change is mechanical:

1. Add a service block to `compose.yaml`: `image`, loopback `ports`, a named
   volume, and a healthcheck. Template:

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

2. Add the version/port variables to `.env.example` (and `.env`):

   ```sh
   POSTGRES_VERSION=17
   POSTGRES_PORT=5432
   ```

3. Add a Makefile convenience target if useful (e.g. `psql:` opening a shell).
4. Add a row to the [connection strings table](#connection-strings).

## Troubleshooting

- **Port already in use** — `lsof -i :27017` shows what is holding the port;
  stop it or change `MONGO_PORT` in `.env`.
- **Healthcheck never turns green** — `docker compose logs mongo` shows the
  MongoDB logs; check the container status with `make ps`.
- **Stale data after an image upgrade** — Mongo's data dir may be
  incompatible with a new major version; `make reset` clears it.
- **`MongoDB cannot start: Linux kernel versions 6.19 and newer ...`** — recent
  MongoDB builds (e.g. `8.0.32`, `8.3`) refuse to start on Docker Desktop VMs
  whose kernel is 6.19+ (see <https://jira.mongodb.org/browse/SERVER-121912>).
  Pin a compatible image in `.env`, e.g. `MONGO_VERSION=8.2`, until the fix is
  released.