# heidy_api

The backend API for **heidy** — a student academic organizer. heidy helps
students keep their whole semester in one place: their classes and weekly
schedule, assignments and exams, grades, and attendance.

Built with **Elixir** and **Phoenix** as a JSON API.

## Stack

- **Elixir / Phoenix** — JSON API (no HTML, no LiveView)
- **Ecto / PostgreSQL** — persistence
- **Phoenix contexts** — domain boundaries
- Token-based auth (`Bearer` tokens), versioned under `/api/v1`

## Design

The API design lives in [`docs/`](docs/):

- [`docs/architecture.md`](docs/architecture.md) — bounded contexts, domain
  model, and cross-cutting conventions.
- [`docs/api.md`](docs/api.md) — the full endpoint reference.

## Project layout

Standard Phoenix umbrella-free layout, with the domain in `lib/heidy` and the
web layer in `lib/heidy_web`:

```
lib/
  heidy/                  # domain — contexts own the business logic
    accounts/             # users, auth tokens
    catalog/              # universities, courses, subjects (reference data)
    planner/              # semesters, enrollments, meetings, tasks, grades, absences
  heidy_web/              # web layer — thin controllers, JSON views, plugs
    controllers/
    plugs/
    router.ex
```

Controllers stay thin: they authenticate, delegate to a context function, and
render. All business rules live in the contexts.

## Status

Design phase. See issue #1.
