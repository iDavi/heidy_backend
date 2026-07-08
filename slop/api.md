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

### 1.1 Authentication & identity

The heidy account **is** the USP account. There is no separate heidy password,
no registration, and no password-reset flow: `POST /auth/login` verifies the
USP number + Senha Única against USP live and creates the account on first
success.

Login returns two artifacts:

| Artifact          | Purpose                       | Client storage                          |
| ----------------- | ----------------------------- | ---------------------------------------- |
| `token`           | Bearer token for API requests | normal app storage                       |
| `credential_blob` | opaque ciphertext of the USP credential, decryptable only server-side with three keys | device secure storage (Keychain / Keystore) |

Send the token on every 🔒 request:

```
Authorization: Bearer 8f3c…d21a
```

Missing/invalid/expired token → `401`. Valid token but not the owner of the
resource → `404` (we do not disclose existence of others' records).

### 1.2 The credential envelope and blob

**heidy stores no credentials, ever.** The flow:

1. `GET /auth/login-key` → the server's current HPKE public key.
2. The client **HPKE-seals the password client-side** and sends the resulting
   envelope to `POST /auth/login`. TLS protects transport; the envelope
   additionally hides the plaintext from TLS-terminating infrastructure.
3. The server verifies against USP, returns a `credential_blob`, and discards
   all plaintext. The blob is wrapped under three keys (per-blob CEK →
   per-user `K_user` in the DB → KMS-held HPKE key); no single store — device,
   database, or KMS — can decrypt it alone.
4. Sync endpoints (📦) take the blob in the request body; the worker decrypts
   in memory, performs one fresh USP login, and zeroes the plaintext. USP
   sessions are never cached across runs.
5. `DELETE /me/credential` rotates `K_user` — a remote kill switch that
   invalidates every blob on every device.

Envelopes and blobs are accepted **only** in JSON request bodies over TLS —
never in URLs or query strings — and are never logged or returned by any read
endpoint. Blobs expire (server-configured max age, e.g. 90 days); an expired or
revoked blob → `403` with `"detail": "credential_blob expired or revoked"`,
and the client re-logs-in to obtain a fresh one.

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
    "fields": { "title": ["can't be blank"], "score": ["must be >= 0"] }
  }
}
```

`fields` is present only for `422` validation errors; other errors carry just
`detail`.

### 1.4 Status codes

| Code | Meaning                                                          |
| ---- | ---------------------------------------------------------------- |
| 200  | OK                                                               |
| 201  | Created (body contains the new resource)                        |
| 202  | Accepted (async work started)                                    |
| 204  | No content (successful delete)                                   |
| 400  | Malformed request (bad JSON, wrong type)                        |
| 401  | Missing/invalid auth token, or USP rejected the credentials     |
| 403  | Authenticated but forbidden (expired/revoked credential blob)   |
| 404  | Not found / not owned                                           |
| 409  | Conflict (duplicate, overlap, sync already running)             |
| 422  | Validation failed (see `fields`)                                |
| 429  | Rate limited (`Retry-After` header)                             |
| 502  | USP unreachable                                                 |

### 1.5 Pagination, filtering, sorting

- Pagination: `?page=<int ≥ 1>&page_size=<1..100, default 25>`.
- Filtering & sorting use **whitelisted** params only (documented per endpoint).
  Unknown params are ignored; malformed values → `422`.

### 1.6 Global input rules

- Unknown/extra fields in a body are ignored (not an error).
- Strings are trimmed; empty string ≠ `null` (empty may fail `required`).
- `id` path params must be UUIDs; a non-UUID → `404`.
- Binary values (envelope parts, blobs) are base64/base64url strings.

---

## 2. Data types & enums

| Enum              | Values                                                  |
| ----------------- | ------------------------------------------------------- |
| `task.kind`       | `assignment` · `exam` · `reading` · `project` · `other` |
| `task.status`     | `todo` · `doing` · `done`                               |
| `task.priority`   | `low` · `normal` · `high`                               |
| `day_of_week`     | `1`=Mon … `7`=Sun (ISO)                                 |
| `source`          | `manual` · `usp` (read-only; set by the system)         |
| `sync.source`     | `schedule` · `grades` · `absences` · `disciplines`      |
| `sync.status`     | `pending` · `running` · `succeeded` · `failed`          |

---

## 3. Endpoints

Legend: 🔓 public · 🔒 auth · 📦 requires `credential_blob` in body

### 3.1 Health

#### `GET /health` 🔓
Liveness/readiness probe. → `200 {"status":"ok","version":"…"}`.

---

### 3.2 Auth

#### `GET /auth/login-key` 🔓
The server's current HPKE public key for sealing the login envelope.
Cacheable; rotates via `key_id`.

**200**
```json
{ "data": { "key_id": "k1", "alg": "HPKE-X25519-HKDF-SHA256+CHACHA20POLY1305",
            "public_key": "base64…" } }
```

#### `POST /auth/login` 🔓
Verify USP credentials live and start a session. **Creates the account on the
first successful login.** Strictly rate-limited.

| Field          | Type   | Required | Constraints                                       |
| -------------- | ------ | -------- | -------------------------------------------------- |
| `usp_username` | string | yes      | USP number, 6–12 digits                            |
| `envelope`     | object | yes      | HPKE envelope of the Senha Única (see below)       |

`envelope`:

| Field          | Type   | Required | Constraints                                        |
| -------------- | ------ | -------- | --------------------------------------------------- |
| `key_id`       | string | yes      | a currently valid key id from `/auth/login-key`     |
| `enc`          | string | yes      | base64 KEM encapsulation, ≤ 128 chars               |
| `ciphertext`   | string | yes      | base64 sealed password, ≤ 512 chars                 |
| `encrypted_at` | string | yes      | ISO 8601; server rejects envelopes older than 5 min |

**200**
```json
{ "data": {
    "user":  { "id":"…", "usp_username":"1234567", "name":"Ana" },
    "token": "…", "token_expires_at": "2026-08-07T00:00:00Z",
    "credential_blob": {
      "blob": "base64url…", "key_version": 3,
      "issued_at": "2026-07-08T12:00:00Z", "expires_at": "2026-10-06T12:00:00Z"
    } } }
```

The client must store `credential_blob.blob` in device secure storage; it is
required for sync and cannot be re-fetched (only re-issued by logging in again).

Errors: `401` (USP rejected the credentials), `422` (format, unknown/expired
`key_id`, stale `encrypted_at`), `429`, `502` (USP unreachable).

#### `DELETE /auth/logout` 🔒
Revokes the current token (the credential blob on the device is unaffected —
revoke blobs with `DELETE /me/credential`). **204**.

---

### 3.3 Current user

#### `GET /me` 🔒
**200**
```json
{ "data": { "id":"…", "usp_username":"1234567", "name":"Ana",
            "email": "ana@usp.br",
            "course": { "id":"…", "name":"BCC" },
            "credential": { "key_version": 3, "last_login_at":"2026-07-08T12:00:00Z" } } }
```

#### `PATCH /me` 🔒

| Field       | Type   | Required | Constraints                          |
| ----------- | ------ | -------- | ------------------------------------ |
| `name`      | string | no       | 1–80 chars                           |
| `email`     | string | no       | valid email, ≤ 160 chars, or `null`  |
| `course_id` | uuid   | no       | must exist in the catalog            |

**200** → updated profile. At least one field required.

#### `DELETE /me/credential` 🔒
**Remote kill switch.** Rotates the per-user vault key (`K_user`), instantly
invalidating **every** credential blob issued to any of the user's devices.
Use after a lost/stolen device. Subsequent syncs fail with `403` until the
user logs in again. **204**.

#### `DELETE /me` 🔒
Deletes the account and all owned data (semesters, enrollments, tasks,
credential key). Rate-limited. **204**.

---

### 3.4 USP sync 📦

#### `POST /usp/sync` 🔒📦
Kick off an import. Returns immediately; the login+scrape runs in a supervised
worker. The worker decrypts the blob in memory (KMS decap → `K_user` unwrap →
CEK), performs **one fresh USP login** — sessions are never cached across
runs — scrapes, upserts, and zeroes the plaintext.

| Field             | Type     | Required | Constraints                                                        |
| ----------------- | -------- | -------- | ------------------------------------------------------------------ |
| `credential_blob` | string   | yes      | base64url, ≤ 4096 chars; must be valid, unexpired, unrevoked, and issued to this user |
| `sources`         | string[] | no       | unique subset of `schedule`,`grades`,`absences`,`disciplines`; default = all |
| `semester_id`     | uuid     | no       | target an existing semester; default = current/active              |

**202**
```json
{ "data": { "id":"…", "status":"pending", "sources":["schedule","grades"],
            "created_at":"2026-07-08T12:00:00Z" } }
```

Errors: `403` (blob expired/revoked/foreign → re-login), `409` (a sync is
already running for this user — syncs are serialized per user), `422`
(unknown source), `502` (USP unreachable). Repeated USP auth failures mark the
run `failed` and back off rather than retrying into an account lockout.

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

### 3.5 Semesters

#### `GET /semesters` 🔒
Paginated list of the user's semesters. Filter `?active=true`. Sort
`?sort=-start_date` (default).

#### `POST /semesters` 🔒

| Field        | Type   | Required | Constraints                                   |
| ------------ | ------ | -------- | ---------------------------------------------- |
| `label`      | string | yes      | 1–20 chars, unique per user (`409` if dup)     |
| `start_date` | date   | yes      | `YYYY-MM-DD`                                   |
| `end_date`   | date   | yes      | ≥ `start_date`                                 |
| `active`     | bool   | no       | default `false`; setting `true` unsets others  |

**201** → the semester.

#### `GET /semesters/:id` 🔒 · `PATCH /semesters/:id` 🔒 · `DELETE /semesters/:id` 🔒
PATCH accepts any subset of the create fields (same constraints). DELETE cascades
to its enrollments/meetings/grades/absences → **204**.

---

### 3.6 Enrollments (the student's classes)

#### `GET /enrollments` 🔒
Filter `?semester_id=` (recommended), `?source=usp|manual`. Includes `meetings`.

#### `POST /enrollments` 🔒

| Field           | Type   | Required | Constraints                                              |
| --------------- | ------ | -------- | --------------------------------------------------------- |
| `semester_id`   | uuid   | yes      | must be owned by the user                                 |
| `title`         | string | cond.    | 1–120 chars; required unless `discipline_id` is given     |
| `discipline_id` | uuid   | no       | catalog discipline; fills `title`/credits if `title` omitted |
| `professor`     | string | no       | ≤ 120 chars                                               |
| `credits`       | int    | no       | 0–40                                                      |
| `color`         | string | no       | hex `#RRGGBB`                                             |
| `absence_limit` | int    | no       | 0–200 (max allowed absences)                              |

**201**. Duplicate (same `discipline_id` in the same semester) → `409`.
`source` is `manual` for API-created rows (USP rows are created by sync).

#### `GET /enrollments/:id` 🔒 · `PATCH /enrollments/:id` 🔒 · `DELETE /enrollments/:id` 🔒
PATCH: subset of writable fields. Editing a USP-imported enrollment sets a
`user_edited` flag so future syncs won't overwrite your changes. DELETE → **204**.

---

### 3.7 Meetings (weekly schedule of a class)

#### `GET /enrollments/:id/meetings` 🔒
List slots for a class.

#### `POST /enrollments/:id/meetings` 🔒

| Field         | Type   | Required | Constraints                             |
| ------------- | ------ | -------- | ---------------------------------------- |
| `day_of_week` | int    | yes      | 1–7 (Mon–Sun)                            |
| `starts_at`   | time   | yes      | `HH:MM`                                  |
| `ends_at`     | time   | yes      | `HH:MM`, strictly after `starts_at`      |
| `location`    | string | no       | ≤ 120 chars                              |

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

### 3.8 Tasks

#### `GET /tasks` 🔒
Filters: `?semester_id=`, `?enrollment_id=`, `?status=`, `?kind=`,
`?due_before=<iso>`, `?due_after=<iso>`. Sort: `?sort=due_at` (default),
`-due_at`, `priority`.

#### `POST /tasks` 🔒

| Field           | Type     | Required | Constraints                                    |
| --------------- | -------- | -------- | ----------------------------------------------- |
| `title`         | string   | yes      | 1–160 chars                                     |
| `enrollment_id` | uuid     | no       | must be owned by the user                       |
| `kind`          | enum     | no       | see enums; default `assignment`                 |
| `notes`         | string   | no       | ≤ 5 000 chars                                   |
| `due_at`        | datetime | no       | ISO 8601                                        |
| `priority`      | enum     | no       | `low`/`normal`/`high`; default `normal`         |
| `status`        | enum     | no       | default `todo`                                  |

**201**.

#### `GET /tasks/:id` 🔒 · `PATCH /tasks/:id` 🔒 · `DELETE /tasks/:id` 🔒
Standard. **204** on delete.

#### `PATCH /tasks/:id/status` 🔒
Body: `status` (enum, required). Convenience transition. **200**.

---

### 3.9 Grades

#### `GET /enrollments/:id/grades` 🔒
List grade entries for a class.

#### `POST /enrollments/:id/grades` 🔒

| Field       | Type    | Required | Constraints                              |
| ----------- | ------- | -------- | ----------------------------------------- |
| `label`     | string  | yes      | 1–80 chars (e.g. "P1")                    |
| `score`     | decimal | no       | 0 ≤ score ≤ `max_score`; null = ungraded  |
| `max_score` | decimal | no       | > 0; default `10`                         |
| `weight`    | decimal | no       | > 0; default `1`                          |

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

### 3.10 Absences (attendance)

#### `GET /enrollments/:id/absences` 🔒
List recorded absences.

#### `POST /enrollments/:id/absences` 🔒

| Field   | Type   | Required | Constraints                                     |
| ------- | ------ | -------- | ------------------------------------------------ |
| `date`  | date   | yes      | `YYYY-MM-DD`, within the semester                |
| `count` | int    | no       | 1–10 (some sessions count double); default `1`   |
| `note`  | string | no       | ≤ 200 chars                                      |

**201**.

#### `DELETE /absences/:id` 🔒
Shallow route. **204**.

#### `GET /enrollments/:id/absences/summary` 🔒
Computed.
```json
{ "data": { "used": 4, "limit": 15, "remaining": 11, "status": "ok" } }
```

---

### 3.11 Catalog (USP reference data, read-only)

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
| GET `/auth/login-key` · POST `/auth/login` | 🔓 |
| DELETE `/auth/logout` | 🔒 |
| GET · PATCH · DELETE `/me` · DELETE `/me/credential` | 🔒 |
| POST `/usp/sync` 📦 · GET `/usp/sync` · GET `/usp/sync/:id` | 🔒 |
| GET · POST `/semesters` · GET · PATCH · DELETE `/semesters/:id` | 🔒 |
| GET · POST `/enrollments` · GET · PATCH · DELETE `/enrollments/:id` | 🔒 |
| GET · POST `/enrollments/:id/meetings` · PATCH · DELETE `/meetings/:id` · GET `/schedule` | 🔒 |
| GET · POST `/tasks` · GET · PATCH · DELETE `/tasks/:id` · PATCH `/tasks/:id/status` | 🔒 |
| GET · POST `/enrollments/:id/grades` · PATCH · DELETE `/grades/:id` · GET `/enrollments/:id/grades/summary` | 🔒 |
| GET · POST `/enrollments/:id/absences` · DELETE `/absences/:id` · GET `/enrollments/:id/absences/summary` | 🔒 |
| GET `/universities` · `/universities/:id` · `/universities/:id/units` · `/units/:id/courses` · `/disciplines` · `/disciplines/:id` | 🔓 |
