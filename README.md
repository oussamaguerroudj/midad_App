# MIDAD — مِداد · Teacher Workspace

Offline-first teacher operating system. Flutter (Riverpod, Drift/SQLite, go_router, Dio) + FastAPI (SQLAlchemy 2, Alembic, PostgreSQL). No AI, no student access, no QR attendance in v1.

Status: **Phase 0 (Foundation) delivered.** See `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, `docs/PHASE_REPORT_0.md`.

## Requirements
Docker + Docker Compose; Python 3.12 (for local backend work); Flutter >= 3.22 (Dart >= 3.4).

## Backend
```bash
cp .env.example .env            # edit secrets; never commit .env
docker compose up --build       # postgres + redis + backend (runs `alembic upgrade head`)
curl localhost:8000/api/v1/health
# tests (local)
cd backend && python -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt && pytest -q
```
Migrations: `alembic upgrade head`, `alembic revision --autogenerate -m "msg"` (review it!), `alembic downgrade -1`.

## Mobile
```bash
bash tools/bootstrap_mobile.sh                      # platform folders, pub get, gen-l10n, build_runner, icons, analyze, test
cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 --dart-define=MIDAD_DEV_SKIP_AUTH=true
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```
`MIDAD_DEV_SKIP_AUTH` exists only until Phase 1 login and must not be used in release builds.

## Environment variables
See `.env.example`. Flutter takes `API_BASE_URL` via `--dart-define`.

## Troubleshooting
* `app_localizations.dart not found` -> run `flutter gen-l10n`.
* `app_database.g.dart not found` -> run `dart run build_runner build --delete-conflicting-outputs`.
* Android emulator reaches the host at `10.0.2.2`.
* Backend refuses to start in production with weak/identical JWT secrets (by design).

Production deployment, backup and hardening are documented in Phase 5.
