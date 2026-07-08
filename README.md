# heidy_api

The backend API for **heidy** — a student academic organizer. heidy helps
students keep their whole semester in one place: their classes and weekly
schedule, assignments and exams, grades, and attendance.

v1 targets **USP** (Universidade de São Paulo). The heidy account **is** the
USP account: login verifies against USP live, and heidy imports the student's
schedule, disciplines, grades and absences, on top of which they plan their own
tasks. **No credentials are stored server-side, ever** — the client holds an
opaque, three-key-wrapped credential blob it cannot read, used in worker memory
per sync and discarded. Schemas are written university-agnostic, so a second
university is additive rather than a rewrite.

Built with **Elixir** and **Phoenix** as a JSON API.

## Stack

- **Elixir / Phoenix** — JSON API (no HTML, no LiveView)
- **Ecto / PostgreSQL** — persistence
- **Phoenix contexts** — domain boundaries
- Token-based auth (`Bearer` tokens), versioned under `/api/v1`
- **HPKE + KMS envelope crypto** for the USP credential (nothing at rest)

## Design

The API design lives in [`docs/`](docs/):

- [`docs/architecture.md`](docs/architecture.md) — bounded contexts, domain
  model, the three-key credential envelope (no credentials at rest), and
  cross-cutting conventions.
- [`docs/api.md`](docs/api.md) — the full endpoint reference: request/response
  formats, per-field input constraints, and status codes.
- [`docs/openapi.json`](docs/openapi.json) — the authoritative machine-readable
  **OpenAPI 3.1** contract (JSON Schema for every input/output and constraint).

## Project layout

Standard Phoenix umbrella-free layout, with the domain in `lib/heidy` and the
web layer in `lib/heidy_web`:

```
lib/
  heidy/                  # domain — contexts own the business logic
    accounts/             # users, auth tokens — no passwords stored
    credentials/          # credential blob issue/unwrap/revoke; per-user vault key
    catalog/              # universities, units, courses, disciplines (reference data)
    planner/              # semesters, enrollments, meetings, tasks, grades, absences
    usp_sync/             # USP integration: Usp.Client behaviour, mappers, SyncRun, Oban worker
  heidy_web/              # web layer — thin controllers, JSON views, plugs
    controllers/
    plugs/
    router.ex
```

Controllers stay thin: they authenticate, delegate to a context function, and
render. All business rules live in the contexts.

## Status

Design phase. See issue #1.
