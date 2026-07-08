# heidy_api — API Reference

Complete reference for the heidy v1 API: endpoints, request/response formats,
input constraints, and status codes.

> **Machine-readable contract:** [`docs/openapi.json`](openapi.json) is the
> authoritative OpenAPI 3.1 spec — every request/response body and field
> constraint (types, lengths, patterns, ranges, enums, required/optional) is
> expressed as JSON Schema there. This document is the prose companion.

- **Base URL:** `/api/v1`
- **Content type:** `application/json` for requests and responses (UTF-8).
- **Auth:** `Authorization: Bearer <token>` on 🔒 endpoints.
- **Dates/times:** ISO 8601, UTC (`2026-07-08T14:00:00Z`). `Meeting` times are
  wall-clock `HH:MM`. `date` fields are `YYYY-MM-DD`.
- **IDs:** UUID v4 strings.

---

## 1. Conventions

### 1.1 Authentication

Obtain a token from `POST /auth/register` or `POST /auth/login`, then send it on
every 🔒 request:

```
Authorization: Bearer 8f3c…d21a
```

Missing/invalid/expired token → `401`. Valid token but not the owner of the
resource → `404` (we do not disclose existence of others' records).

### 1.2 The PIN

Vault and sync endpoints require the user's **USP PIN** to unlock the encrypted
USP credential. The PIN is accepted **only** in the JSON request body, over TLS,
and is never logged, never returned, and never placed in a URL or query string.
A wrong PIN → `403` with `"detail": "invalid pin"`. PIN attempts are rate-limited.

### 1.3 Response envelopes

**Single resource:**

```json
{ "data": { "id": "…", "…": "…" } }
```

**Collection (paginated):**

```json
{
  "data": [ { "…": "…" } ],
  "meta": { "page": 1, "page_size": 25, "total": 132 }
}
```

**Error:**

```json
{
  "errors": {
    "detail": "Validation failed",
    "fields": { "email": ["can't be blank"], "score": ["must be >= 0"] }
  }
}
```

`fields` is present only for `422` validation errors; other errors carry just
`detail`.

### 1.4 Status codes

| Code | Meaning                                                        |
| ---- | ------------------------------------------------------------- |
| 200  | OK                                                            |
| 201  | Created (body contains the new resource)                     |
| 204  | No content (successful delete)                               |
| 400  | Malformed request (bad JSON, wrong type)                     |
| 401  | Missing/invalid auth token                                   |
| 403  | Authenticated but forbidden (e.g. wrong PIN)                 |
| 404  | Not found / not owned                                        |
| 409  | Conflict (e.g. duplicate semester label, email taken)        |
| 422  | Validation failed (see `fields`)                             |
| 429  | Rate limited (`Retry-After` header)                          |

### 1.5 Pagination, filtering, sorting

- Pagination: `?page=<int ≥ 1>&page_size=<1..100, default 25>`.
- Filtering & sorting use **whitelisted** params only (documented per endpoint).
  Unknown params are ignored; malformed values → `422`.

### 1.6 Global input rules

- Unknown/extra fields in a body are ignored (not an error).
- Strings are trimmed; empty string ≠ `null` (empty may fail `required`).
- All lengths are in characters. All monetary/score numbers are decimals sent as
  JSON numbers.
- `id` path params must be UUIDs; a non-UUID → `404`.

---

## 2. Data types & enums

| Enum              | Values                                             |
| ----------------- | -------------------------------------------------- |
| `task.kind`       | `assignment` · `exam` · `reading` · `project` · `other` |
| `task.status`     | `todo` · `doing` · `done`                          |
| `task.priority`   | `low` · `normal` · `high`                          |
| `day_of_week`     | `1`=Mon … `7`=Sun (ISO)                            |
| `source`          | `manual` · `usp` (read-only; set by the system)    |
| `sync.source`     | `schedule` · `grades` · `absences` · `disciplines` |
| `sync.status`     | `pending` · `running` · `succeeded` · `failed`     |
| `credential.status` | `unverified` · `verified` · `invalid`            |

---

## 3. Endpoints

Legend: 🔓 public · 🔒 auth · 🔑 requires PIN in body

### 3.1 Health

#### `GET /health` 🔓
Liveness/readiness probe. → `200 {"status":"ok","version":"…"}`.

---

### 3.2 Auth

#### `POST /auth/register` 🔓

| Field      | Type   | Required | Constraints                                        |
| ---------- | ------ | -------- | -------------------------------------------------- |
| `email`    | string | yes      | valid email, ≤ 160 chars, unique (`409` if taken)  |
| `password` | string | yes      | 8–72 chars, at least one letter and one digit      |
| `name`     | string | yes      | 1–80 chars                                         |

**201**
```json
{ "data": { "user": { "id":"…", "email":"a@usp.br", "name":"Ana" },
            "token": "…", "token_expires_at": "2026-08-07T00:00:00Z" } }
```
Errors: `422` (validation), `409` (email taken).

#### `POST /auth/login` 🔓

| Field      | Type   | Required | Constraints |
| ---------- | ------ | -------- | ----------- |
| `email`    | string | yes      | valid email |
| `password` | string | yes      | non-empty   |

**200** → same shape as register. Bad credentials → `401` (`"invalid email or
password"`, deliberately not distinguishing which). Rate-limited.

#### `DELETE /auth/logout` 🔒
Revokes the current token. **204**.

#### `POST /auth/password/forgot` 🔓
Body: `email` (string). Always **202** (does not reveal whether the email
exists). Sends a reset token if it does.

#### `POST /auth/password/reset` 🔓

| Field      | Type   | Required | Constraints                       |
| ---------- | ------ | -------- | --------------------------------- |
| `token`    | string | yes      | valid, unexpired reset token      |
| `password` | string | yes      | 8–72 chars, one letter + one digit |

**200** on success; `422`/`401` otherwise. (Resetting the heidy password does
**not** affect the USP credential/PIN.)

---

### 3.3 Current user

#### `GET /me` 🔒
**200** → the user profile, including `usp_credential` metadata:
```json
{ "data": { "id":"…", "email":"ana@usp.br", "name":"Ana",
            "university": { "id":"…", "acronym":"USP" },
            "usp_credential": { "connected": true, "status":"verified",
                                "usp_username":"1234567", "last_verified_at":"2026-07-08T12:00:00Z" } } }
```

#### `PATCH /me` 🔒

| Field           | Type   | Required | Constraints                    |
| --------------- | ------ | -------- | ------------------------------ |
| `name`          | string | no       | 1–80 chars                     |
| `university_id` | uuid   | no       | must exist in catalog          |
| `course_id`     | uuid   | no       | must exist and belong to the university |

**200** → updated profile.

#### `PUT /me/password` 🔒

| Field              | Type   | Required | Constraints                        |
| ------------------ | ------ | -------- | ---------------------------------- |
| `current_password` | string | yes      | must match (else `403`)            |
| `new_password`     | string | yes      | 8–72 chars, one letter + one digit |

**200** (token stays valid) — or configurable to rotate tokens.

#### `DELETE /me` 🔒
Deletes the account and all owned data (semesters, enrollments, tasks, vault).
Requires `password` in body as confirmation. **204**.

---

### 3.4 USP credential vault 🔑

Stores the reversible, PIN-encrypted USP login. The secret and PIN are never
returned by any endpoint.

#### `POST /me/usp-credential` 🔒🔑
Create or replace the stored USP credential.

| Field          | Type   | Required | Constraints                                            |
| -------------- | ------ | -------- | ------------------------------------------------------ |
| `usp_username` | string | yes      | USP number, 6–12 digits                                |
| `usp_password` | string | yes      | 1–128 chars (USP Senha Única); encrypted at rest, never stored in clear |
| `pin`          | string | yes      | 4–12 digits; encrypts the credential; **not** stored   |
| `verify`       | bool   | no       | default `true` — validate against USP before saving    |

**201**
```json
{ "data": { "connected": true, "status": "verified",
            "usp_username": "1234567", "last_verified_at": "2026-07-08T12:00:00Z" } }
```
Errors: `422` (format), `403` (`verify:true` and USP rejected the credentials),
`502` (USP unreachable).

#### `GET /me/usp-credential` 🔒
Metadata only — **never** the secret or PIN.
```json
{ "data": { "connected": true, "status":"verified",
            "usp_username":"1234567", "last_verified_at":"…" } }
```
Not connected → `200 {"data":{"connected":false}}`.

#### `PUT /me/usp-credential/pin` 🔒🔑
Rotate the PIN (re-wraps the data key; USP ciphertext untouched).

| Field     | Type   | Required | Constraints                 |
| --------- | ------ | -------- | --------------------------- |
| `pin`     | string | yes      | current PIN (else `403`)    |
| `new_pin` | string | yes      | 4–12 digits, ≠ current PIN  |

**200**. Note: a forgotten PIN cannot be recovered — re-`POST` the credential.

#### `POST /me/usp-credential/verify` 🔒🔑
Body: `pin`. Unlocks and tests the credential against USP live. **200** with
updated `status`/`last_verified_at`; `403` on wrong PIN or USP rejection.

#### `DELETE /me/usp-credential` 🔒
Removes the stored credential. **204**.

---

### 3.5 USP sync 🔑

#### `POST /usp/sync` 🔒🔑
Kick off an import. Returns immediately; the login+scrape runs in a supervised
worker (the decrypted credential lives only in that worker's memory).

| Field     | Type      | Required | Constraints                                                       |
| --------- | --------- | -------- | ----------------------------------------------------------------- |
| `pin`     | string    | yes      | unlocks the credential (else `403`)                               |
| `sources` | string[]  | no       | subset of `schedule`,`grades`,`absences`,`disciplines`; default = all |
| `semester_id` | uuid  | no       | target an existing semester; default = current/active            |

**202**
```json
{ "data": { "id":"…", "status":"pending", "sources":["schedule","grades"],
            "created_at":"2026-07-08T12:00:00Z" } }
```
Errors: `403` (bad PIN / no credential), `409` (a sync is already running),
`422` (unknown source).

#### `GET /usp/sync/:id` 🔒
Poll a run.
```json
{ "data": { "id":"…", "status":"succeeded", "sources":["schedule","grades"],
            "stats": { "enrollments": 6, "grades": 14, "absences": 3 },
            "started_at":"…", "finished_at":"…", "error": null } }
```

#### `GET /usp/sync` 🔒
Paginated list of recent runs (newest first). Filter `?status=`.

---

### 3.6 Semesters

#### `GET /semesters` 🔒
Paginated list of the user's semesters. Filter `?active=true`. Sort
`?sort=-start_date` (default).

#### `POST /semesters` 🔒

| Field        | Type   | Required | Constraints                                  |
| ------------ | ------ | -------- | -------------------------------------------- |
| `label`      | string | yes      | 1–20 chars, unique per user (`409` if dup)   |
| `start_date` | date   | yes      | `YYYY-MM-DD`                                 |
| `end_date`   | date   | yes      | ≥ `start_date`                               |
| `active`     | bool   | no       | default `false`; setting `true` unsets others |

**201** → the semester.

#### `GET /semesters/:id` 🔒 · `PATCH /semesters/:id` 🔒 · `DELETE /semesters/:id` 🔒
PATCH accepts any subset of the create fields (same constraints). DELETE cascades
to its enrollments/meetings/grades/absences → **204**.

---

### 3.7 Enrollments (the student's classes)

#### `GET /enrollments` 🔒
Filter `?semester_id=` (recommended), `?source=usp|manual`. Includes `meetings`.

#### `POST /enrollments` 🔒

| Field           | Type   | Required | Constraints                                              |
| --------------- | ------ | -------- | -------------------------------------------------------- |
| `semester_id`   | uuid   | yes      | must be owned by the user                                |
| `title`         | string | cond.    | 1–120 chars; required unless `discipline_id` is given    |
| `discipline_id` | uuid   | no       | catalog discipline; fills `title`/credits if `title` omitted |
| `professor`     | string | no       | ≤ 120 chars                                              |
| `credits`       | int    | no       | 0–40                                                     |
| `color`         | string | no       | hex `#RRGGBB`                                            |
| `absence_limit` | int    | no       | 0–200 (max allowed absences)                            |

**201**. Duplicate (same `discipline_id` in the same semester) → `409`.
`source` is `manual` for API-created rows (USP rows are created by sync).

#### `GET /enrollments/:id` 🔒 · `PATCH /enrollments/:id` 🔒 · `DELETE /enrollments/:id` 🔒
PATCH: subset of writable fields. Editing a USP-imported enrollment sets a
`user_edited` flag so future syncs won't overwrite your changes. DELETE → **204**.

---

### 3.8 Meetings (weekly schedule of a class)

#### `GET /enrollments/:id/meetings` 🔒
List slots for a class.

#### `POST /enrollments/:id/meetings` 🔒

| Field         | Type   | Required | Constraints                                  |
| ------------- | ------ | -------- | -------------------------------------------- |
| `day_of_week` | int    | yes      | 1–7 (Mon–Sun)                                |
| `starts_at`   | time   | yes      | `HH:MM`                                      |
| `ends_at`     | time   | yes      | `HH:MM`, strictly after `starts_at`          |
| `location`    | string | no       | ≤ 120 chars                                  |

**201**. Overlapping the same day/time of another meeting in the same semester →
`409`.

#### `PATCH /meetings/:id` 🔒 · `DELETE /meetings/:id` 🔒
Shallow routes (addressed by meeting id). Same constraints; **204** on delete.

#### `GET /schedule` 🔒
Computed weekly grid. Requires `?semester_id=`.
```json
{ "data": { "1": [ { "enrollment_id":"…", "title":"Cálculo I",
                     "starts_at":"08:00", "ends_at":"10:00", "location":"Sala 5" } ],
            "2": [ … ], "…": [] } }
```

---

### 3.9 Tasks

#### `GET /tasks` 🔒
Filters: `?semester_id=`, `?enrollment_id=`, `?status=`, `?kind=`,
`?due_before=<iso>`, `?due_after=<iso>`. Sort: `?sort=due_at` (default),
`-due_at`, `priority`.

#### `POST /tasks` 🔒

| Field           | Type   | Required | Constraints                                    |
| --------------- | ------ | -------- | ---------------------------------------------- |
| `title`         | string | yes      | 1–160 chars                                    |
| `enrollment_id` | uuid   | no       | must be owned by the user                      |
| `kind`          | enum   | no       | see enums; default `assignment`                |
| `notes`         | string | no       | ≤ 5 000 chars                                  |
| `due_at`        | datetime | no     | ISO 8601; if `enrollment_id` set, warns (not errors) when outside the semester dates |
| `priority`      | enum   | no       | `low`/`normal`/`high`; default `normal`        |
| `status`        | enum   | no       | default `todo`                                 |

**201**.

#### `GET /tasks/:id` 🔒 · `PATCH /tasks/:id` 🔒 · `DELETE /tasks/:id` 🔒
Standard. **204** on delete.

#### `PATCH /tasks/:id/status` 🔒
Body: `status` (enum, required). Convenience transition. **200**.

---

### 3.10 Grades

#### `GET /enrollments/:id/grades` 🔒
List grade entries for a class.

#### `POST /enrollments/:id/grades` 🔒

| Field       | Type    | Required | Constraints                          |
| ----------- | ------- | -------- | ------------------------------------ |
| `label`     | string  | yes      | 1–80 chars (e.g. "P1")               |
| `score`     | decimal | no       | 0 ≤ score ≤ `max_score`; null = ungraded |
| `max_score` | decimal | no       | > 0; default `10`                    |
| `weight`    | decimal | no       | > 0; default `1`                     |

**201**.

#### `PATCH /grades/:id` 🔒 · `DELETE /grades/:id` 🔒
Shallow routes. **204** on delete.

#### `GET /enrollments/:id/grades/summary` 🔒
Computed.
```json
{ "data": { "weighted_average": 6.4, "graded_weight": 0.6, "remaining_weight": 0.4,
            "passing_average": 5.0, "needed_on_remaining": 3.9, "status": "on_track" } }
```

---

### 3.11 Absences (attendance)

#### `GET /enrollments/:id/absences` 🔒
List recorded absences.

#### `POST /enrollments/:id/absences` 🔒

| Field   | Type   | Required | Constraints                                   |
| ------- | ------ | -------- | --------------------------------------------- |
| `date`  | date   | yes      | `YYYY-MM-DD`, within the semester             |
| `count` | int    | no       | 1–10 (some sessions count double); default `1` |
| `note`  | string | no       | ≤ 200 chars                                   |

**201**.

#### `DELETE /absences/:id` 🔒
Shallow route. **204**.

#### `GET /enrollments/:id/absences/summary` 🔒
Computed.
```json
{ "data": { "used": 4, "limit": 15, "remaining": 11, "status": "ok" } }
```

---

### 3.12 Catalog (USP reference data, read-only)

#### `GET /universities` 🔓
Search `?q=` (≤ 80 chars). Paginated.

#### `GET /universities/:id` 🔓 · `GET /universities/:id/units` 🔓 · `GET /units/:id/courses` 🔓
Detail and nested listings.

#### `GET /disciplines` 🔓
Search catalog disciplines. Params: `?unit_id=`, `?q=` (matches code or name).
Paginated.

#### `GET /disciplines/:id` 🔓
Discipline detail.

---

## 4. Endpoint index

| Method · Path | Auth |
| --- | --- |
| GET `/health` | 🔓 |
| POST `/auth/register` · `/auth/login` | 🔓 |
| DELETE `/auth/logout` | 🔒 |
| POST `/auth/password/forgot` · `/auth/password/reset` | 🔓 |
| GET · PATCH · DELETE `/me` · PUT `/me/password` | 🔒 |
| POST · GET · DELETE `/me/usp-credential` · PUT `/me/usp-credential/pin` · POST `/me/usp-credential/verify` | 🔒🔑 |
| POST · GET `/usp/sync` · GET `/usp/sync/:id` | 🔒🔑 |
| GET · POST `/semesters` · GET · PATCH · DELETE `/semesters/:id` | 🔒 |
| GET · POST `/enrollments` · GET · PATCH · DELETE `/enrollments/:id` | 🔒 |
| GET · POST `/enrollments/:id/meetings` · PATCH · DELETE `/meetings/:id` · GET `/schedule` | 🔒 |
| GET · POST `/tasks` · GET · PATCH · DELETE `/tasks/:id` · PATCH `/tasks/:id/status` | 🔒 |
| GET · POST `/enrollments/:id/grades` · PATCH · DELETE `/grades/:id` · GET `/enrollments/:id/grades/summary` | 🔒 |
| GET · POST `/enrollments/:id/absences` · DELETE `/absences/:id` · GET `/enrollments/:id/absences/summary` | 🔒 |
| GET `/universities` · `/universities/:id` · `/universities/:id/units` · `/units/:id/courses` · `/disciplines` · `/disciplines/:id` | 🔓 |
