# API Reference

Base URL: `/api/v1`

- All authenticated requests send `Authorization: Bearer <token>`.
- Request and response bodies are JSON.
- List endpoints accept `?page=&page_size=` and return a `meta` block.
- Errors use the envelope described in [`architecture.md`](architecture.md).

Legend: 🔓 public · 🔒 requires auth

---

## Health

| Method | Path      | Auth | Description               |
| ------ | --------- | ---- | ------------------------- |
| GET    | `/health` | 🔓   | Liveness / readiness probe |

## Auth

| Method | Path              | Auth | Description                                   |
| ------ | ----------------- | ---- | --------------------------------------------- |
| POST   | `/auth/register`  | 🔓   | Create an account, returns user + token       |
| POST   | `/auth/login`     | 🔓   | Exchange email + password for a token         |
| DELETE | `/auth/logout`    | 🔒   | Revoke the current token                       |
| POST   | `/auth/password/forgot` | 🔓 | Send a password-reset token               |
| POST   | `/auth/password/reset`  | 🔓 | Reset password with a valid reset token   |

## Current user

| Method | Path             | Auth | Description                    |
| ------ | ---------------- | ---- | ----------------------------- |
| GET    | `/me`            | 🔒   | Current user profile           |
| PATCH  | `/me`            | 🔒   | Update name, university, course |
| PUT    | `/me/password`   | 🔒   | Change password (current + new) |
| DELETE | `/me`            | 🔒   | Delete account                  |

## Catalog (reference data, read-only)

| Method | Path                          | Auth | Description                         |
| ------ | ----------------------------- | ---- | ----------------------------------- |
| GET    | `/universities`               | 🔓   | List / search universities (`?q=`)  |
| GET    | `/universities/:id`           | 🔓   | University detail                    |
| GET    | `/universities/:id/courses`   | 🔓   | Courses of a university              |
| GET    | `/subjects`                   | 🔓   | Search subjects (`?university_id=&q=`) |
| GET    | `/subjects/:id`               | 🔓   | Subject detail                       |

## Semesters

| Method | Path              | Auth | Description                     |
| ------ | ----------------- | ---- | ------------------------------- |
| GET    | `/semesters`      | 🔒   | The user's semesters            |
| POST   | `/semesters`      | 🔒   | Create a semester               |
| GET    | `/semesters/:id`  | 🔒   | Semester detail                 |
| PATCH  | `/semesters/:id`  | 🔒   | Update (label, dates, `active`) |
| DELETE | `/semesters/:id`  | 🔒   | Delete a semester               |

## Enrollments (the user's classes)

| Method | Path                          | Auth | Description                                         |
| ------ | ----------------------------- | ---- | -------------------------------------------------- |
| GET    | `/enrollments`                | 🔒   | List classes; filter `?semester_id=`                |
| POST   | `/enrollments`                | 🔒   | Add a class (catalog `subject_id` or free-text)     |
| GET    | `/enrollments/:id`            | 🔒   | Class detail (with meetings)                         |
| PATCH  | `/enrollments/:id`            | 🔒   | Update title, professor, color, `absence_limit`     |
| DELETE | `/enrollments/:id`            | 🔒   | Remove a class                                       |

### Meetings (weekly schedule of a class)

| Method | Path                                   | Auth | Description                    |
| ------ | -------------------------------------- | ---- | ------------------------------ |
| GET    | `/enrollments/:id/meetings`            | 🔒   | Class time slots               |
| POST   | `/enrollments/:id/meetings`            | 🔒   | Add a slot (weekday, times, room) |
| PATCH  | `/meetings/:id`                        | 🔒   | Update a slot                  |
| DELETE | `/meetings/:id`                        | 🔒   | Remove a slot                  |

### Aggregated schedule

| Method | Path         | Auth | Description                                        |
| ------ | ------------ | ---- | ------------------------------------------------- |
| GET    | `/schedule`  | 🔒   | Weekly grid for `?semester_id=`, grouped by weekday |

## Tasks (assignments, exams, to-dos)

| Method | Path                    | Auth | Description                                                  |
| ------ | ----------------------- | ---- | ----------------------------------------------------------- |
| GET    | `/tasks`                | 🔒   | Filter `?semester_id=&enrollment_id=&status=&kind=&due_before=`; `sort=due_at` |
| POST   | `/tasks`                | 🔒   | Create a task (optionally tied to an enrollment)             |
| GET    | `/tasks/:id`            | 🔒   | Task detail                                                  |
| PATCH  | `/tasks/:id`            | 🔒   | Update any field                                             |
| PATCH  | `/tasks/:id/status`     | 🔒   | Convenience: move status (todo → doing → done)               |
| DELETE | `/tasks/:id`            | 🔒   | Delete a task                                                |

## Grades

| Method | Path                             | Auth | Description                                          |
| ------ | -------------------------------- | ---- | --------------------------------------------------- |
| GET    | `/enrollments/:id/grades`        | 🔒   | Grade entries for a class                            |
| POST   | `/enrollments/:id/grades`        | 🔒   | Add a grade (label, score, weight, max)             |
| GET    | `/enrollments/:id/grades/summary`| 🔒   | Weighted average + score still needed to pass       |
| PATCH  | `/grades/:id`                    | 🔒   | Update a grade                                       |
| DELETE | `/grades/:id`                    | 🔒   | Delete a grade                                       |

## Absences (attendance)

| Method | Path                                | Auth | Description                                 |
| ------ | ----------------------------------- | ---- | ------------------------------------------ |
| GET    | `/enrollments/:id/absences`         | 🔒   | Recorded absences for a class               |
| POST   | `/enrollments/:id/absences`         | 🔒   | Log an absence (date, count, note)          |
| GET    | `/enrollments/:id/absences/summary` | 🔒   | Used / remaining / limit                    |
| DELETE | `/absences/:id`                     | 🔒   | Remove an absence                           |

---

## Notes on shape

- **Member actions** (`/meetings/:id`, `/grades/:id`, `/absences/:id`) use
  shallow routes: create/list are nested under the parent enrollment, but
  update/delete address the resource directly by id. This keeps URLs short and
  avoids redundant nesting.
- **`/schedule`** and the `*/summary` endpoints return **computed** views, not
  stored rows — they belong to the `Planner` context, not to a CRUD resource.
- **Collaboration** (sharing tasks) and **push notifications / devices** are
  intentionally deferred to phase 2 and are not part of the v1 surface.
