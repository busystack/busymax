# BusyMax

BusyMax is a Linux desktop calendar and task manager built with Flutter.
It supports `Google Calendar`, `Google Tasks`, `Microsoft Calendar`, and `Microsoft To Do`.

## Prerequisites

- Flutter: https://docs.flutter.dev/install
- `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET`, see [Google Setup](docs/google_setup.md)
- `MICROSOFT_OAUTH_CLIENT_ID`, see [Microsoft Setup](docs/microsoft_setup.md)

## Run locally

```bash
flutter run -d linux \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=<google-client-id> \
  --dart-define=GOOGLE_OAUTH_CLIENT_SECRET=<google-secret-if-needed> \
  --dart-define=MICROSOFT_OAUTH_CLIENT_ID=<microsoft-client-id>
```
