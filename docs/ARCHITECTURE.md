# MIDAD architecture (Phase 0)

## Layers
Flutter UI -> Riverpod controllers -> Repositories -> Drift/SQLite (always read first)
                                                  \-> Sync engine -> Dio -> FastAPI -> PostgreSQL
UI never touches the database or network directly. Business rules (grade validation, averages, follow-up rules) live in pure Dart services, not widgets.

## Backend
Feature-first modules under `backend/app/modules/*`; shared kernel in `core/` and `shared/`.
One DB transaction per request (`get_db`). Errors use one envelope `{"error":{"code","message","details"}}` with codes NETWORK/AUTH/VALIDATION/CONFLICT/PERMISSION/FILE/NOT_FOUND/RATE_LIMITED/INTERNAL; no stack traces are returned.

## Multi-tenancy & authorization
* Every teacher-owned table has `teacher_id` (indexed, NOT NULL, FK). A unit test enforces this for all future tables.
* Every query is scoped by the authenticated principal's `teacher_id`; foreign ids return 404 (not 403) so ids cannot be probed.
* Access token = 15 min JWT (HS256, `typ=access`). Refresh token = 30 d JWT (`typ=refresh`, separate secret); only its SHA-256 is stored, rotated on each use, revoked on logout. Passwords: Argon2id.

## Data integrity
* UUID PKs, `created_at/updated_at`, `version` (optimistic lock), `deleted_at` (soft delete) on all synced entities.
* CHECK constraints for statuses/kinds/ranges; unique constraints for natural keys (one attendance record per student per session, one result per student per assessment, one current academic year per teacher).
* `audit_logs` is append-only with `before`/`after` JSON: every grade and attendance change is recorded (who, old, new, when).
* Cross-table rule "score <= assessment.max_score" is enforced in the service layer and a DB trigger (Phase 1).

## Sync protocol (implemented in Phase 1)
Client writes locally in one SQLite transaction: the entity row (syncStatus=pending) + a `sync_queue` row (+ audit row).
`POST /api/v1/sync` request: `{device_id, mutations:[{mutation_id(uuid), entity_type, entity_id, operation, base_version, payload}]}`.
Per mutation the server answers `applied{version}` | `conflict{server_state}` | `rejected{error}`. `sync_records(teacher_id, mutation_id)` is UNIQUE, so a replayed batch returns the stored outcome and never duplicates data (idempotency).
Conflicts: server never overwrites newer data. `base_version != current` -> `conflict`; client marks the row `conflict` and offers "keep mine / keep server". Grades and attendance are never auto-merged.
Retry: exponential backoff (2s, 4s, ... capped 5 min) with jitter, only for network/5xx; 4xx are terminal (`failed`, `last_error` kept for developers, never shown raw).
Pull: `GET /api/v1/sync/changes?cursor=` returns rows changed since the cursor (including soft deletes).

## Offline UX rules
Offline is normal, not an error: subtle banner "You're offline. Changes will sync automatically."; after sync "All changes synchronized." Unsynced rows are never deleted by "clear cache".

## Design system
All colour from `AppColors`; type from `AppTypography`; spacing/radius/shadows/animation/icons centralised. Brand burgundy is sampled from the logo; spec neutrals and semantic colours are retained. Arabic uses Tajawal, Latin uses Inter (font files to be bundled — offline-first).
