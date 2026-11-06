# HealthCore

## Supabase configuration

The Flutter app reads Supabase configuration from compile-time Dart defines.
The publishable key is intentionally not stored in tracked Dart source.

Run the app from a terminal with:

```shell
flutter run \
  --dart-define=SUPABASE_URL=https://googertfgiyanznyazbo.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-key
```

In VS Code, use the `HealthCore` launch profile in
[.vscode/launch.json](.vscode/launch.json). That local file is ignored so
each developer can supply their own key.

Use only a Supabase publishable/anon key in the client. Never use a
service-role key in Flutter or commit credentials to the repository.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
