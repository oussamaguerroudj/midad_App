/// Build-time configuration. Never hardcode URLs: pass `--dart-define=API_BASE_URL=...`.
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000/api/v1');

  /// Dev only: lets the shell open before Phase 1 auth exists. Must be false in release builds.
  static const devSkipAuth = bool.fromEnvironment('MIDAD_DEV_SKIP_AUTH', defaultValue: false);
}
