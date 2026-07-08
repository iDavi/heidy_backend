# Architecture

heidy_api is a Phoenix JSON API. The guiding principle is idiomatic Phoenix:
**thin web layer, rich domain contexts.** Controllers authenticate, validate
shape, delegate to a context, and render. Every business rule lives in a
context module.

```
HTTP  ─▶  Router ─▶ Plug pipeline ─▶ Controller ─▶ Context ─▶ Ecto ─▶ Postgres
                     (auth, etc.)      (thin)       (logic)
```

## Bounded contexts

We keep the number of contexts small and let them grow, rather than
over-partitioning up front.

### `Accounts`

Identity and authentication.

| Schema      | Purpose                                                       |
| ----------- | ------------------------------------------------------------ |
| `User`      | email, hashed password, display name, `confirmed_at`, optional `university_id` / `course_id` |
| `UserToken` | hashed session / API tokens (register, login, password reset, email confirmation) — the `phx.gen.auth` model |

Auth is token-based. A client logs in and receives a `Bearer` token that is
sent on every subsequent request. Tokens are stored hashed; only the raw token
lives on the client.

### `Catalog`

Shared, read-mostly **reference data** for universities. It is deliberately
decoupled: a user can attach their enrollment to a catalog `Subject`, or just
type a free-text title. The catalog makes autocomplete and sharing nicer but is
never required.

| Schema       | Purpose                                             |
| ------------ | --------------------------------------------------- |
| `University` | name, acronym, city                                 |
| `Course`     | a degree program; `belongs_to :university`          |
| `Subject`    | a canonical discipline; code, name, credits; `belongs_to :university` |

Catalog data is seeded/administered, not user-writable through the public API
(read-only endpoints only).

### `Planner`

The heart of heidy — everything that belongs to *one* student's semester. All
`Planner` records are scoped to the owning user and are only ever reachable
through that user's token.

| Schema       | Purpose                                                                 |
| ------------ | ----------------------------------------------------------------------- |
| `Semester`   | `belongs_to :user`; label (e.g. "2026.1"), `start_date`, `end_date`, `active` |
| `Enrollment` | a class the user is taking; `belongs_to :user, :semester`; optional `subject_id`; title, professor, color, credits, `absence_limit` |
| `Meeting`    | a recurring weekly time slot; `belongs_to :enrollment`; `day_of_week`, `starts_at`, `ends_at`, `location` |
| `Task`       | `belongs_to :user`; optional `enrollment_id`; title, notes, `kind` (assignment/exam/reading/other), `due_at`, `status` (todo/doing/done), `priority` |
| `Grade`      | `belongs_to :enrollment`; label, `score`, `weight`, `max_score`         |
| `Absence`    | `belongs_to :enrollment`; `date`, `count` (some sessions count double), note |

Derived data that the domain computes (not stored):

- **Weekly schedule** — `Meeting`s for a semester, grouped by weekday.
- **Grade summary** — weighted average so far, and the score still needed on
  remaining weight to pass.
- **Attendance summary** — absences used, remaining, and limit.

### Collaboration (phase 2)

Shared tasks / study groups via a `TaskShare` join (`task_id`, `user_id`,
`role`). Scoped out of v1 to avoid overengineering; the `Task` schema already
carries a clean owner boundary, so this slots in without a rewrite.

## Domain model at a glance

```
User ─┬─< Semester ─< Enrollment ─┬─< Meeting
      │                           ├─< Grade
      ├─< Task >───────(optional)─┘   (Task also links a User directly)
      │                           └─< Absence
      └─ university_id / course_id ─▶ Catalog

University ─< Course
University ─< Subject ◀─(optional)─ Enrollment
```

## Cross-cutting conventions

**Versioning.** All routes live under `/api/v1`. A new incompatible shape means
`/api/v2`, never a silent break.

**Authentication.** `Authorization: Bearer <token>`. Public endpoints (register,
login, catalog reads, health) use the `:api` pipeline; everything else adds an
`:authenticated` plug that loads `current_user` or returns `401`.

**Authorization.** Ownership is enforced in the context query, not just the
controller — every `Planner` fetch is scoped `where user_id == current_user.id`.
Accessing someone else's record returns `404` (we don't leak existence).

**Errors.** A single consistent envelope, rendered by a `FallbackController`:

```json
{ "errors": { "detail": "Human message", "fields": { "email": ["can't be blank"] } } }
```

Status codes are used honestly: `200/201/204`, `401` (unauthenticated),
`403` (authenticated but forbidden), `404`, `409` (conflict, e.g. duplicate
enrollment), `422` (validation — Ecto changeset errors under `fields`).

**Pagination.** List endpoints are page-based: `?page=1&page_size=25` with a
`meta` block (`page`, `page_size`, `total`). Bounded default and max page size.

**Filtering & sorting.** Explicit whitelisted query params only
(e.g. `?semester_id=…&status=todo&sort=due_at`). No arbitrary query injection.

**Timestamps & time.** UTC everywhere (`utc_datetime`). `Meeting` times are
wall-clock `time` + `day_of_week`; the client renders them against the user's
week.

**IDs.** UUID primary keys on user-facing resources (non-enumerable, safe to
expose).

**Validation.** Ecto changesets are the single source of truth; controllers
never hand-roll validation.

**Rate limiting & CORS.** A rate-limit plug on auth endpoints and CORS
configured for the mobile/web clients. Health check at `/api/v1/health` for
uptime probes.
