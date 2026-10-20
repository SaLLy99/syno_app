# SYNO

SYNO is a Flutter dating app with a FastAPI backend. It combines profile and preference matching with astrology reports and behavioral scoring. The mobile app is localized in English, Georgian, and Russian.

## Project Layout

- `flutter/`: Flutter client, UI, Riverpod state, API services, and translations.
- `backend/app/`: FastAPI application, authentication, database access, matching, and astrology services.
- `backend/tests/`: Backend unit and integration tests.
- `backend/docker-compose.yml`: Local PostgreSQL and backend services.

The Flutter client calls the backend over HTTP. The backend owns persistence and server-side matching and astrology services; Flutter owns navigation, presentation, and client state. See [Flutter architecture](flutter/architecture.md) for the module map.

## Requirements

- Flutter SDK compatible with Dart `^3.6.0`.
- Python 3.11 (used by the backend Docker image and CI).
- Docker Desktop / Docker Compose for the container-based setup, or PostgreSQL for a local backend.

## Run With Docker

From the repository root:

```bash
cd backend
docker compose up --build
```

This starts PostgreSQL and the API on port `8000`. The Compose file contains development database credentials; do not use them in a deployed environment. Stop the services with `Ctrl+C`, or run `docker compose down` from `backend/`.

## Run Locally

### Backend

Create a virtual environment and install dependencies from `backend/`:

```bash
cd backend
python -m venv .venv
```

Activate it (`.venv\Scripts\Activate.ps1` in PowerShell, or `source .venv/bin/activate` on macOS/Linux), then run:

```bash
pip install -r requirements.txt
```

Create `backend/.env` from `backend/.env.example`, set `DATABASE_URL` to a reachable PostgreSQL database, and replace `SECRET_KEY` with a private random value. Then start the API:

```bash
uvicorn app.main:app --reload
```

The API listens on `http://localhost:8000` by default.

### Flutter

From `flutter/`, create `assets/env/.env` from `assets/env/.env.example`. Set `BACKEND_URL` to the API address reachable from the target device. Android emulators generally use `http://10.0.2.2:8000`; desktop, web, or an iOS simulator can generally use `http://localhost:8000`. A physical device needs the development machine's LAN address.

Then run:

```bash
cd flutter
flutter pub get
flutter run
```

## Verification

Run backend tests (the same test command used in CI):

```bash
cd backend
pytest .
```

Run Flutter static analysis and tests:

```bash
cd flutter
flutter analyze
flutter test
```

## Before Committing

- Review `git status` and the complete diff, including deleted and newly added files.
- Do not commit `.env` files, credentials, local databases, uploads, or generated build/cache output. `.gitignore` does not stop tracking a file that is already in Git; verify tracked environment files before committing.
- Run the backend tests and Flutter analysis/tests above. CI currently runs the backend test suite.
- Confirm database migrations or initialization SQL are included when a schema change requires them.

## Configuration

The backend reads settings from environment variables and `backend/.env`. The Flutter app loads `flutter/assets/env/.env` at startup. The checked-in `.env.example` files contain local-development placeholders only; provide private credentials through local environment files or a deployment secret manager.