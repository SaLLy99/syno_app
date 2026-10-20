# Flutter Architecture

The Flutter app is the client for the FastAPI service. It owns UI composition, navigation, localization, and client-side state. User, match, and astrology data are represented in the domain layer and loaded or updated through data repositories and API services.

## Modules

- `lib/presentation/screens/`: Application screens and navigation destinations.
- `lib/presentation/widgets/`: Reusable UI components.
- `lib/presentation/providers/`: Riverpod providers for authentication, registration, matching, recommendations, themes, and other app state.
- `lib/domain/entities/`: Client-side domain models, including users, matches, locations, preferences, and astrology data.
- `lib/data/repositories/`: Data coordination for app features.
- `lib/data/services/`: HTTP clients and focused services, including astrology API and natal chart functionality.

The backend entry point is `backend/app/main.py`. Backend API routes, persistence, matching, and astrology interpretation are implemented there and under `backend/app/`; the Flutter client should use the API contracts rather than duplicate server-owned behavior.

## Request and State Flow

1. A screen reads or updates feature state through a Riverpod provider.
2. The provider coordinates the relevant repository or service.
3. API services use the configured backend URL and send HTTP requests to FastAPI.
4. Response data is mapped into domain entities and exposed to the UI state.

Authentication state also drives GoRouter redirects. Localization resources live in `assets/lang/` and are loaded with `easy_localization` for English, Georgian, and Russian.

## Configuration

At startup, `lib/main.dart` loads `assets/env/.env` and provides `BACKEND_URL`. Create this ignored local file from `assets/env/.env.example`; use an address reachable from the chosen emulator or device. Do not put production credentials in the Flutter asset bundle.

## Validation

From `flutter/`, run:

```bash
flutter analyze
flutter test
```

For backend setup and tests, see the root [README](../README.md).
