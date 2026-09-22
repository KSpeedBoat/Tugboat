# Tugboat Development Guide

## Overview

Tugboat is an automated operations platform built with Go 1.26.3 (backend) and Vue Vben Admin (frontend).
It consists of three binary components that work together:

| Component | Binary | Role |
|---|---|---|
| Server | `tugboat-server` | Central management server, REST API + Web UI backend |
| Agent | `tugboat-agent` | Deployed on monitored hosts, executes inspections and recovery |
| CLI | `tugboat` | Admin client for platform management and server configuration |

### Component Communication

```
tugboat (CLI)
  │
  ├── Local mode  →  direct OS process management (start/stop/restart)
  └── Remote mode →  REST API  ──→  tugboat-server
                                         │
                               gRPC  ────┤
                                         │
                                    tugboat-agent  (on monitored hosts)

Web Browser  →  REST API  ──→  tugboat-server
```

- **CLI ↔ Server**: HTTP REST API
- **Server ↔ Agent**: gRPC (protobuf)
- **Browser ↔ Server**: HTTP REST API

---

## Tech Stack

### Backend

| Category | Choice | Notes |
|---|---|---|
| Language | **Go 1.26.3** | Statically compiled, high-concurrency — ideal for long-running ops services |
| Web framework | **Gin** | Serves the HTTP REST API — mature ecosystem, widely used with GORM |
| gRPC | `google.golang.org/grpc` | Bidirectional communication between Server and Agent |
| ORM | **GORM** | Unified database access layer — AutoMigrate, fluent query API |
| Configuration | **Viper** | YAML config, env-var override, hot-reload support |
| CLI framework | **Cobra** | `tugboat` CLI command tree |
| Authentication | **JWT** | Stateless token auth; on logout the token is written to a PostgreSQL blacklist table to invalidate it; natively compatible with Vue Vben Admin's built-in token interceptor |
| DB migrations | **golang-migrate** | All schema changes managed as versioned SQL files (`migrations/NNN_xxx.up.sql` / `.down.sql`); GORM AutoMigrate is **disabled** |

### Databases & Middleware

| Component | Purpose |
|---|---|
| **PostgreSQL** | Primary relational database: agents, inspection results, alert rules, log metadata |
| **pgvector** (PostgreSQL extension) | Vector storage: AI diagnostic embeddings, semantic log search, alert similarity |
| **MinIO** | Object storage: inspection report attachments, archived log files, AI context snapshots |

> **pgvector** runs as a PostgreSQL extension — no separate database instance required.
> Access vector columns via GORM custom types or raw SQL.

### Frontend

| Category | Choice | Notes |
|---|---|---|
| Framework | **Vue 3** | Composition API + `<script setup>` |
| Admin template | **[Vue Vben Admin](https://github.com/vbenjs/vue-vben-admin)** | Enterprise admin framework with built-in routing, auth, layouts, and components |
| State management | **Pinia** | Default state solution in Vue Vben Admin |
| UI component library | **Ant Design Vue** | Default component library in Vue Vben Admin |
| HTTP client | **Axios** | Wrapped inside `src/api/` |
| Build tool | **Vite** | Fast cold start and HMR |

> Frontend lives in the `web/` directory. It is a customization of Vue Vben Admin that follows
> its directory conventions (`src/views/`, `src/router/`, `src/store/`, `src/api/`, etc.).

### Data Flow

```
Browser (Vue Vben Admin)
    │  HTTP REST (JSON)
    ▼
tugboat-server (Go)
    ├── GORM ──→ PostgreSQL (structured data)
    │               └── pgvector (vector columns)
    ├── MinIO SDK ──→ MinIO (object storage)
    └── gRPC Bidirectional Streaming ──→ tugboat-agent (monitored host)
            ├── Server → Agent: push inspection tasks, recovery commands
            └── Agent → Server: report heartbeat, results, logs
```

---

## Repository Layout

```
Tugboat/
├── cmd/                    # Binary entry points
├── internal/               # Private application code
├── pkg/                    # Shared public libraries
├── api/                    # Protocol definitions
├── web/                    # Vue 3 frontend source
├── configs/                # Configuration file templates
├── deployments/            # Deployment manifests
├── scripts/                # Build and maintenance scripts
├── test/                   # Integration and E2E tests
├── docs/                   # Project documentation
└── tools/                  # Developer tooling
```

---

## Directory Reference

### `cmd/`

Entry points for each binary. Each subdirectory contains only a `main.go` that wires
dependencies and starts the application. Business logic must **not** live here.

| Directory | Binary | Description |
|---|---|---|
| `cmd/tugboat-server/` | `tugboat-server` | Server entry point |
| `cmd/tugboat-agent/` | `tugboat-agent` | Agent entry point |
| `cmd/tugboat/` | `tugboat` | CLI entry point |

---

### `internal/`

Application code that is **not** importable by external projects. Divided by component.

#### `internal/server/`

All server-side logic.

| Directory | Description |
|---|---|
| `api/v1/` | HTTP handler functions for REST API v1 routes |
| `api/middleware/` | HTTP middleware: authentication, rate limiting, CORS, logging |
| `service/agent/` | Agent registration, heartbeat tracking, online/offline detection |
| `service/inspect/` | Inspection task creation, dispatch to agents, result ingestion |
| `service/recovery/` | Fault recovery strategy management and execution tracking |
| `service/alert/` | Alert rule evaluation, deduplication, notification dispatch |
| `service/logquery/` | Log search and aggregation across agents |
| `service/ai/` | AI model integration: sending diagnostics context, parsing responses |
| `service/scheduler/` | Cron-style scheduler for automated periodic tasks |
| `service/config/` | Platform configuration management (AI provider, notify channels, etc.) |
| `repository/agent/` | Database access layer for agent records |
| `repository/inspect/` | Database access layer for inspection results |
| `repository/alert/` | Database access layer for alert rules and history |
| `repository/log/` | Database access layer for log entries |
| `grpc/` | gRPC server implementation for receiving agent reports |

#### `internal/agent/`

All agent-side logic. Runs on monitored hosts.

| Directory | Description |
|---|---|
| `inspect/system/` | System-level inspection: CPU, memory, disk, process health |
| `inspect/database/` | Database inspection: MySQL, PostgreSQL, Redis connectivity and metrics |
| `recovery/` | Local fault recovery executors (e.g. restart service, free disk space) |
| `logquery/` | Log file collection and keyword pattern analysis |
| `reporter/` | gRPC client that reports results and metrics back to the server |
| `runner/` | Task runner that receives and dispatches tasks sent by the server |

#### `internal/cli/`

CLI command implementations, split by operation mode.

| Directory | Description |
|---|---|
| `local/platform/` | Platform process management: start, stop, restart server and web service |
| `local/selfcheck/` | Platform health detection: verifies server, web, and database are operational |
| `local/selfrepair/` | Automatic platform repair based on selfcheck findings |
| `remote/config/` | Commands to manage server configuration (AI model, notify channels) |
| `remote/task/` | Commands to manage inspection and recovery task templates |
| `remote/schedule/` | Commands to manage scheduled task rules |
| `remote/alert/` | Commands to manage alert rules |
| `remote/agent/` | Commands to view agent list and status (read-only) |
| `remote/log/` | Commands to query logs from the server |
| `client/` | HTTP client wrapper used by all `remote/` commands to call the server REST API |

---

### `pkg/`

Shared libraries that may be imported by multiple internal packages or, in the future,
by external consumers.

| Directory | Description |
|---|---|
| `models/` | Shared data structures: `Agent`, `Task`, `InspectResult`, `Alert`, `LogEntry`, etc. |
| `proto/` | Go code generated from `.proto` files (do not edit manually) |
| `utils/` | General-purpose utilities: encryption, time formatting, HTTP helpers, etc. |

---

### `api/`

Protocol and API definitions. Source of truth for all interfaces.

| Directory | Description |
|---|---|
| `proto/` | Protobuf `.proto` source files defining the gRPC interface between server and agent |
| `openapi/` | OpenAPI (Swagger) YAML/JSON definitions for the REST API |

> After modifying `.proto` files, regenerate Go code into `pkg/proto/` using the
> script in `tools/`.

---

### `web/`

Vue 3 frontend application.

| Directory | Description |
|---|---|
| `src/views/Dashboard/` | Overview dashboard: agent count, recent alerts, inspection summary |
| `src/views/Agents/` | Agent list and individual agent detail |
| `src/views/Inspect/` | Inspection task management and result browsing |
| `src/views/Recovery/` | Fault recovery history and manual trigger |
| `src/views/Alert/` | Alert rule configuration and alert history |
| `src/views/Log/` | Log query interface |
| `src/views/Settings/` | Platform settings: AI model, notification channels, scheduler |
| `src/components/` | Reusable UI components |
| `src/api/` | Frontend API call wrappers (mirrors the server REST API) |
| `src/store/` | Global state management using Pinia |
| `public/` | Static assets served as-is (favicon, fonts, etc.) |

---

### `configs/`

Configuration file templates for each component. Copy and rename to use:

| File | Description |
|---|---|
| `server.yaml.example` | Server configuration template (DB, gRPC port, JWT secret, AI provider, etc.) |
| `agent.yaml.example` | Agent configuration template (server address, inspection intervals, etc.) |

---

### `deployments/`

Deployment-related files. Not used at runtime.

| Directory | Description |
|---|---|
| `docker/` | `Dockerfile` for each binary and a `docker-compose.yml` for local development |
| `systemd/` | systemd unit files for running server and agent as Linux services |
| `kubernetes/` | Kubernetes manifests for containerized deployment (optional) |

---

### `scripts/`

Shell scripts for common development and operational tasks.

| Script | Description |
|---|---|
| `build.sh` | Build all three binaries |
| `release.sh` | Tag a release and build distribution artifacts |
| `migrate.sh` | Run database schema migrations |

---

### `test/`

Integration and end-to-end tests that require a running environment.
Unit tests live alongside their source files (e.g. `foo_test.go` next to `foo.go`).

---

### `tools/`

Developer tooling and code generation helpers.

- Proto code generation scripts (`generate_proto.sh`)
- Mock generation for unit testing
- Any other build-time utilities

---

## Development Conventions

### Commit Messages

Follow the [Angular commit convention](https://github.com/zsp108/dev_scripts/blob/develop/docs/git-commit-guide.md).
Write commit messages in English.

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

Common types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `ci`, `perf`, `style`

### Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Stable release branch |
| `devloop` | Main development branch |
| `feat/<name>` | Feature branches, merged into `devloop` |
| `fix/<name>` | Bug fix branches |

### Module Path

```
github.com/KSpeedBoat/Tugboat
```

### Adding a New Feature

1. Create a feature branch from `devloop`: `git checkout -b feat/<name>`
2. Add models to `pkg/models/` if new data structures are needed
3. Add repository methods in `internal/server/repository/<domain>/`
4. Implement business logic in `internal/server/service/<domain>/`
5. Expose via HTTP handler in `internal/server/api/v1/`
6. If the feature involves the agent, update proto in `api/proto/`, regenerate `pkg/proto/`
7. Add corresponding CLI command in `internal/cli/remote/<domain>/`
8. Add corresponding Web UI page/component in `web/src/views/`
9. Write unit tests alongside source files
10. Commit following the convention and open a PR to `devloop`
