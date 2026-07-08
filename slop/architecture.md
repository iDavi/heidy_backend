# Architecture

heidy_api is a Phoenix JSON API. The guiding principle is idiomatic Phoenix:
**thin web layer, rich domain contexts.** Controllers authenticate, validate
shape, delegate to a context, and render. Every business rule lives in a
context module.

```
HTTP ─▶ Router ─▶ Plug pipeline ─▶ Controller ─▶ Context ─▶ Ecto ─▶ Postgres
                   (auth)            (thin)       (logic)      │
                                                 UspSync ──▶ USP (Júpiter, e-Disciplinas)
                                                   (anti-corruption layer, Oban jobs)
```

v1 targets **USP** (Universidade de São Paulo). The heidy account **is** the
USP account: a student logs in with their USP number + Senha Única, heidy
verifies it against USP, and imports their schedule, disciplines, grades and
absences — on top of which the student plans tasks. Schemas are written
university-agnostic (a second university is additive, not a rewrite) but only
USP is integrated in v1.

## What "better architected" means here

- **The USP scrape never touches the domain schemas directly.** It goes through
  an anti-corruption layer that maps USP's messy HTML/DTO shapes into our own
  clean models. Swapping or fixing the scraper never ripples into `Planner`.
- **Provenance is first-class.** Every importable record carries `source`
  (`:manual` | `:usp`) and an `external_ref`. Re-syncs *upsert* by
  `external_ref` instead of duplicating, and a user's manual edits are never
  silently clobbered by a later sync.
- **No credentials at rest.** heidy never stores the USP password — not even
  encrypted. The client device stores an opaque ciphertext it cannot read; the
  server can only decrypt it with the participation of three separately-held
  keys, uses the plaintext in memory, and discards it. See "The credential
  envelope" below.
- **Integration is asynchronous.** A sync returns immediately with a `SyncRun`
  id; the actual login+scrape runs in a supervised worker, so a slow USP never
  blocks a request.

## Bounded contexts

### `Accounts`

heidy identity. There is **no heidy password** — identity is the USP account.

| Schema      | Purpose                                                          |
| ----------- | ---------------------------------------------------------------- |
| `User`      | `usp_username` (unique), name, optional email, optional `course_id`; created automatically on first successful USP login |
| `UserToken` | hashed session/API tokens (the `phx.gen.auth` token model)       |

Consequently there is no register/password-reset surface: `POST /auth/login`
creates the account on first successful verification against USP.

### `Credentials`

Owns the cryptography: issuing, unwrapping, and revoking **credential blobs**.
Stores *keys about* the credential — never the credential.

| Schema          | Purpose                                                              |
| --------------- | -------------------------------------------------------------------- |
| `CredentialKey` | per-user vault key `K_user` (256-bit, itself encrypted at rest under an app-level KMS data key) + `version`; rotating it revokes every blob ever issued to that user |

The USP password, any plaintext key material, and decrypted blobs are **never**
persisted and **never** logged.

### `Catalog`

USP reference data (seeded/synced, read-only through the API). Written
generically so other universities fit later.

| Schema       | Purpose                                                     |
| ------------ | ----------------------------------------------------------- |
| `University` | e.g. USP                                                    |
| `Unit`       | teaching unit / institute (e.g. ICMC, POLI)                 |
| `Course`     | degree program; `belongs_to :unit`                          |
| `Discipline` | canonical discipline (USP code, name, credits); `belongs_to :unit` |

### `Planner`

The student's academic life — the heart. Records are user-scoped and reachable
only through that user's token. Rows may be **manual** or **imported from USP**;
both share the same schemas, distinguished by `source`/`external_ref`.

| Schema       | Purpose                                                                     |
| ------------ | ---------------------------------------------------------------------------- |
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

## The credential envelope (three keys, nothing at rest)

heidy must **replay** the student's Senha Única against USP to import data, so
the credential must be recoverable — but a central database of reversible
student passwords is a honeypot and a liability. The design goal is therefore:

> **The server persists no credential, ever. The client persists only
> ciphertext it cannot read. Decryption requires three separately-held keys
> and happens only in worker memory, per use.**

### The three keys

| Key       | What                                   | Where it lives                          |
| --------- | -------------------------------------- | ---------------------------------------- |
| `K_kms`   | X25519 HPKE keypair                    | KMS/HSM; private key **non-exportable** — decapsulation happens *inside* KMS and is audited |
| `K_user`  | per-user vault key (random 256-bit)    | server DB (encrypted at rest under an app-level KMS data key); **rotation = revocation** |
| `CEK`     | per-blob content key (random 256-bit)  | exists only inside the blob's wrapping; fresh on every login |

### Issuing a blob (at login)

Login is the only moment the password transits:

```
1. Client fetches the login public key:      GET /auth/login-key → {key_id, alg, public_key}
2. Client HPKE-seals the password to it      (AAD: usp_username, encrypted_at)
   and POSTs {usp_username, envelope} to /auth/login.
   TLS protects transport; HPKE additionally hides the plaintext from
   TLS-terminating infrastructure (load balancers, request logs, APM).
3. Server (worker holding KMS access only) decapsulates, verifies the
   credentials against USP live, creates the account on first login,
   then builds the blob:

     CEK     = random 256-bit
     ct_pw   = AES-256-GCM(CEK,    usp_password, aad)
     w1      = AES-256-GCM(K_user, CEK)              # wrap 1: per-user key
     enc,w2  = HPKE_Seal(pk_kms,   w1)               # wrap 2: KMS key
     blob    = base64url(version ‖ key_ids ‖ enc ‖ w2 ‖ ct_pw ‖ nonces ‖ issued_at)
     aad     = user_id ‖ key_version ‖ issued_at

4. Server returns {token, credential_blob} and zeroes every intermediate.
   The client stores the blob in device secure storage (Keychain / Keystore).
```

### Using a blob (at sync)

```
POST /usp/sync {credential_blob, …}
  worker: KMS decap (audited) → w1
          AES-GCM(K_user)      → CEK
          AES-GCM(CEK)         → usp_password   (in worker memory only)
          fresh USP login → scrape → upsert → zero the plaintext
```

**No USP session caching.** Nothing USP-side survives a run: each `SyncRun`
performs exactly one fresh USP login, uses that live session only within the
run's own process memory for its page fetches, and discards it when the run
ends. No session cookie is ever written to the DB, cache, or job queue.
Operationally: syncs are serialized per user (`409` if one is running), and
repeated USP auth failures back off and mark the run `failed` rather than
retrying into an account lockout.

### Breach math

| Compromised                | Attacker gets                                          |
| -------------------------- | ------------------------------------------------------ |
| Device (blob)              | ciphertext only — undecryptable without KMS **and** DB |
| Server DB                  | `K_user` values — useless without blobs **and** KMS    |
| KMS access                 | nothing without blobs **and** `K_user`                 |
| Device + DB                | still blocked: outer layer needs KMS decap             |
| Device + KMS               | still blocked: inner wrap needs `K_user`               |
| All three stores + blob    | one password — the residual, irreducible case          |

Additional properties:

- **Remote kill switch:** `DELETE /me/credential` rotates `K_user`, instantly
  invalidating every blob on every device. Lost phone → one API call.
- **Bounded lifetime:** `issued_at` is bound into the AAD; the server rejects
  blobs older than the configured max age (e.g. 90 days), forcing a re-login,
  which also rotates the CEK. Blobs are single-user by AAD — replaying one
  against another account fails authentication of the ciphertext.
- **Rotation:** `key_id`s in the blob header let `K_kms` rotate without
  breaking outstanding blobs during a grace window.

### Honest limitation

The server sees the plaintext password in worker memory for the seconds it
takes to log into USP — at login and during each sync. That is inherent to
server-side scraping; no key arrangement removes it. What this design
guarantees is **nothing at rest**: a full dump of the database, backups, job
queue, and logs contains zero credentials. We document the tradeoff rather
than hide it.

## Domain model at a glance

```
User ─┬─ (Accounts)     usp_username, tokens — no password stored
      ├─ (Credentials)  CredentialKey (K_user, version) — never the credential
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
- **Secrets in flight** — the login envelope and credential blob are accepted
  only in JSON request bodies over TLS; never in URLs or query strings, never
  logged. Endpoints that carry them are strictly rate-limited.
- **Authorization** — ownership enforced in the context query (`where user_id ==
  current_user.id`); foreign records return `404` (no existence leak).
- **Errors** — one envelope via a `FallbackController`:
  `{"errors": {"detail": "...", "fields": {"title": ["can't be blank"]}}}`.
  Honest status codes: `401` / `403` / `404` / `409` / `422` / `429`.
- **Pagination** — page-based `?page=&page_size=` with a `meta` block; bounded max.
- **Filtering/sorting** — whitelisted query params only.
- **Provenance** — `source` + `external_ref` on importable rows; re-sync upserts,
  never duplicates, never overwrites manual edits.
- **Time** — UTC (`utc_datetime`); `Meeting` uses wall-clock `time` + weekday.
- **IDs** — UUID primary keys on user-facing resources.
