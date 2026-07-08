# Architecture

heidy_api is a Phoenix JSON API. The guiding principle is idiomatic Phoenix:
**thin web layer, rich domain contexts.** Controllers authenticate, validate
shape, delegate to a context, and render. Every business rule lives in a
context module.

```
HTTP ─▶ Router ─▶ Plug pipeline ─▶ Controller ─▶ Context ─▶ Ecto ─▶ Postgres
                   (auth, pin)       (thin)       (logic)      │
                                                 UspSync ──▶ USP (Júpiter, e-Disciplinas)
                                                   (anti-corruption layer, Oban jobs)
```

v1 targets **USP** (Universidade de São Paulo): a student connects their USP
account, heidy imports their schedule, disciplines, grades and absences, and
the student also plans tasks on top. The schemas are written university-agnostic
(so a second university is additive, not a rewrite) but only USP is seeded and
integrated in v1.

## What "better architected" means here

heidy is designed from clean domain boundaries rather than around a scraper.
Concretely:

- **The USP scrape never touches the domain schemas directly.** It goes through
  an anti-corruption layer that maps USP's messy HTML/DTO shapes into our own
  clean models. Swapping or fixing the scraper never ripples into `Planner`.
- **Provenance is first-class.** Every importable record carries `source`
  (`:manual` | `:usp`) and an `external_ref`. Re-syncs *upsert* by
  `external_ref` instead of duplicating, and a user's manual edits are never
  silently clobbered by a later sync.
- **Secrets are modeled explicitly.** The heidy login secret and the USP login
  secret are *different kinds of secret* with different cryptography, in
  different contexts (`Accounts` vs `Vault`). See below.
- **Integration is asynchronous.** A sync returns immediately with a `SyncRun`
  id; the actual login+scrape runs in a supervised worker, so a slow USP never
  blocks a request.

## Bounded contexts

### `Accounts`

heidy identity. Login to *heidy itself*.

| Schema      | Purpose                                                        |
| ----------- | ------------------------------------------------------------- |
| `User`      | email, **one-way** password hash (Argon2id), name, `confirmed_at` |
| `UserToken` | hashed session / API tokens (`phx.gen.auth` model)            |

The heidy password is a normal, irreversible hash — we never need it back.

### `Vault`

The USP credential. This is the crux of v1 and the reason a naïve design fails:
to import from USP, heidy must **replay** the student's USP password against
USP's login — so it cannot be a one-way hash. It must be **reversibly
encrypted**, and it must be encrypted such that a database leak alone does not
expose it.

| Schema          | Purpose                                                       |
| --------------- | ------------------------------------------------------------- |
| `UspCredential` | USP username + **encrypted** USP password, plus KDF/crypto metadata (salt, nonces, wrapped key, KDF params, key-check value), `last_verified_at`, `status` |

The plaintext USP password, the user's PIN, and any derived key are **never**
persisted and **never** logged. See the next section for the scheme.

### `Catalog`

USP reference data (seeded/synced, read-only through the API). Written
generically so other universities fit later.

| Schema       | Purpose                                                 |
| ------------ | ------------------------------------------------------- |
| `University` | e.g. USP                                                |
| `Unit`       | teaching unit / institute (e.g. ICMC, POLI); `belongs_to :university` |
| `Course`     | degree program; `belongs_to :unit`                      |
| `Discipline` | canonical discipline (USP code, name, credits); `belongs_to :unit` |

### `Planner`

The student's academic life — the heart. Records are user-scoped and reachable
only through that user's token. Rows may be **manual** or **imported from USP**;
both share the same schemas, distinguished by `source`/`external_ref`.

| Schema       | Purpose                                                                     |
| ------------ | --------------------------------------------------------------------------- |
| `Semester`   | `belongs_to :user`; label (e.g. "2026.1"), dates, `active`                   |
| `Enrollment` | a class the student takes; `belongs_to :user, :semester`; optional `discipline_id`; title, professor, credits, `absence_limit`, `source`, `external_ref` |
| `Meeting`    | recurring weekly slot; `belongs_to :enrollment`; `day_of_week`, `starts_at`, `ends_at`, `location` |
| `Task`       | `belongs_to :user`; optional `enrollment_id`; title, notes, `kind`, `due_at`, `status`, `priority` (always `:manual`) |
| `Grade`      | `belongs_to :enrollment`; label, `score`, `weight`, `max_score`, `source`   |
| `Absence`    | `belongs_to :enrollment`; `date`, `count`, note, `source`                   |

Computed (not stored): weekly **schedule** grid, **grade summary** (weighted
average + score still needed to pass), **attendance summary** (used / remaining
/ limit).

### `UspSync`

The integration boundary. Everything that knows USP exists lives here.

| Piece            | Purpose                                                                 |
| ---------------- | ----------------------------------------------------------------------- |
| `Usp.Client`     | a **behaviour**: `login/2`, `fetch_schedule/1`, `fetch_grades/1`, … . Real HTTP impl for Júpiter / e-Disciplinas; a mock impl for tests |
| Anti-corruption mappers | translate USP DTOs → `Planner` changesets                        |
| `SyncRun`        | one sync attempt: `status` (pending/running/succeeded/failed), `sources`, counts, error, timing |
| Oban worker      | runs login + scrape + upsert off the request path                       |

## The USP credential vault (PIN-based envelope encryption)

Two secrets, two treatments:

| Secret                | Purpose                     | Storage                              |
| --------------------- | --------------------------- | ------------------------------------ |
| heidy password        | log in to heidy             | **one-way** hash (Argon2id) — irreversible |
| USP Senha Única       | replay against USP to import| **reversible**, encrypted under a PIN-derived key |

### Scheme

The USP password is protected with **envelope encryption**, unlocked by a
user-chosen **PIN** that the server never stores.

```
KEK = Argon2id(pin ‖ server_pepper, salt)          # key-encryption key, derived on demand
DEK = random 256-bit                               # per-credential data key
usp_ct   = AES-256-GCM(DEK, usp_password)          # stored
wrap_ct  = AES-256-GCM(KEK, DEK)                   # stored
```

Stored columns: `usp_username`, `usp_ct` + nonce, `wrap_ct` + nonce, `salt`,
`kdf_params`, and a key-check value. **Not stored:** the PIN, the KEK, or the
DEK in the clear.

- **Unlock (to sync / verify):** the client sends the PIN over TLS; the server
  derives the KEK in memory, unwraps the DEK, decrypts the USP password, uses
  it, and zeroes it. The plaintext lives only in worker-process memory for the
  duration of a sync — never in the DB, the job queue, or logs.
- **`server_pepper`** is held outside the database (env / KMS). A PIN is
  low-entropy, so the pepper is what makes a database-only leak non-brute-forceable.
  Combined with Argon2id cost and PIN rate-limiting, this is the defense in depth.
- **Change PIN** is cheap: unwrap the DEK with the old KEK, re-wrap with the new
  one. The USP ciphertext is untouched.
- **Forgotten PIN is unrecoverable by design** — there is no reset that yields
  the old secret; the user simply re-enters their USP password under a new PIN.

### Honest limitation

Because the PIN passes through the server at unlock time, this is *not*
end-to-end zero-knowledge — a fully compromised server could capture a PIN in
transit. True zero-knowledge would require decrypting on the client, but then
the client would have to perform the USP scrape, defeating a server-side
integration. We deliberately choose server-side decryption plus defense in depth
(pepper outside the DB, Argon2id, strict PIN rate-limiting, ephemeral in-memory
use, no secret logging), and we document the tradeoff rather than hide it.

## Domain model at a glance

```
User ─┬─ (Accounts)  password hash, tokens
      ├─ (Vault)     UspCredential  ── encrypted USP password
      ├─< Semester ─< Enrollment ─┬─< Meeting
      │                           ├─< Grade
      │                           └─< Absence
      └─< Task >──────(optional)──┘

University ─< Unit ─< Course
                └──< Discipline ◀─(optional)─ Enrollment

UspSync: SyncRun ─▶ Usp.Client ─▶ USP ; mappers ─▶ upsert Planner by external_ref
```

## Cross-cutting conventions

- **Versioning** — everything under `/api/v1`.
- **Auth** — `Authorization: Bearer <token>`; unauthenticated → `401`.
- **PIN** — only ever accepted in the request body of vault/sync endpoints over
  TLS, never in a URL or query string, never logged.
- **Authorization** — ownership enforced in the context query (`where user_id ==
  current_user.id`); foreign records return `404` (no existence leak).
- **Errors** — one envelope via a `FallbackController`:
  `{"errors": {"detail": "...", "fields": {"email": ["can't be blank"]}}}`.
  Honest status codes: `401` / `403` / `404` / `409` / `422`.
- **Pagination** — page-based `?page=&page_size=` with a `meta` block; bounded max.
- **Filtering/sorting** — whitelisted query params only.
- **Provenance** — `source` + `external_ref` on importable rows; re-sync upserts,
  never duplicates, never overwrites manual edits.
- **Time** — UTC (`utc_datetime`); `Meeting` uses wall-clock `time` + weekday.
- **IDs** — UUID primary keys on user-facing resources.
- **Rate limiting** — stricter limits on `/auth/*` and on PIN-bearing endpoints.
