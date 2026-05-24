# smartsteps

A new Flutter project.

## Backend API configuration

The app loads lessons from the ASP.NET backend. It does not use a bundled
hard-coded lesson for the main flow. Run with the backend base URL:

```bash
flutter run --dart-define=SMARTSTEPS_API_BASE_URL=http://10.0.2.2:5078
```

Use `http://localhost:5078` for desktop/web targets running on the same
machine. The app calls `GET /api/situations`, `GET /api/situations/{id}`, and
uses `POST /api/media/signed-url` for backend-managed private media URLs when a
situation step has media.

## Media URL flow

Do not pass Supabase keys to the Flutter app. Store step media paths in the
backend as bucket object paths, for example `videos/lesson1-intro.mp4`. The app
asks the backend for a signed media URL by `stepId`; if the backend is not
configured, no signed URL is returned, or the database media path is invalid,
the app shows the media error so the backend environment or database URL can be
fixed.

The current app does not send a Supabase bearer token to
`POST /api/media/signed-url`. For development, set
`SupabaseStorage:RequireAuthenticatedUser` to `false` on the backend, or wire a
real login token into the request before keeping that backend option enabled.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
