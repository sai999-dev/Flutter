// lib/config/api_config.dart
class ApiConfig {
  // Development
  static const String devBaseUrl = "http://127.0.0.1:5000";

  // Staging (optional)
  static const String stagingBaseUrl = "https://staging.leadmarketplacepro.com";

  // Production (optional)
  static const String prodBaseUrl = "https://api.leadmarketplacepro.com";

  // Choose which environment to use
  static const String activeBaseUrl = devBaseUrl;
}

