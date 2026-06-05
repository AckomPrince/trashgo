class AppConfig {
  static const String appName = 'TrashGo';
  static const String version = '1.0.0';

  // ── API ─────────────────────────────────────────────────────
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1', // Android emulator localhost
  );

  // ── Points ──────────────────────────────────────────────────
  static const int minRedemptionPoints = 500;
  static const double pointsToGhsRate = 100; // 100 pts = 1 GHS

  // ── Map ─────────────────────────────────────────────────────
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'YOUR_GOOGLE_MAPS_API_KEY',
  );

  // ── Keys ────────────────────────────────────────────────────
  static const String tokenKey       = 'auth_token';
  static const String refreshKey     = 'refresh_token';
  static const String userKey        = 'cached_user';
  static const String onboardedKey   = 'onboarded';
}
