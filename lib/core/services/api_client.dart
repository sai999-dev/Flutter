import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';

/// Centralized API client with JWT token management
/// Uses secure storage for JWT tokens (production-grade security)
class ApiClient {
  // Backend API Middleware Layer (Separate Repository)
  // Connects to unified backend that exposes /api/mobile/* endpoints
  // Supports multiple ports for development flexibility
  static const List<String> baseUrls = [
    'http://127.0.0.1:3002',
    'http://localhost:3002',
    'http://127.0.0.1:3001',
    'http://localhost:3001',
    'http://127.0.0.1:3000',
    'http://localhost:3000',
  ];

  /// Get base URLs list (for use in services that need multipart requests)
  static List<String> get baseUrlsList => baseUrls;

  static String? _activeBaseUrl;
  static String? _jwtToken;
  static DateTime? _urlDiscoveryTime;
  static const Duration _urlCacheDuration = Duration(minutes: 5);

  /// Initialize API client and load saved token from secure storage
  static Future<void> initialize() async {
    // Load JWT token from secure storage (encrypted)
    _jwtToken = await SecureStorageService.getToken();
    
    // Load base URL from regular preferences (not sensitive)
    final prefs = await SharedPreferences.getInstance();
    _activeBaseUrl = prefs.getString('active_base_url');
    
    // Load URL discovery timestamp
    final timestamp = prefs.getInt('active_base_url_timestamp');
    if (timestamp != null) {
      _urlDiscoveryTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      // Check if cache is still valid
      final cacheAge = DateTime.now().difference(_urlDiscoveryTime!);
      if (cacheAge >= _urlCacheDuration) {
        // Cache expired, clear it
        _activeBaseUrl = null;
        _urlDiscoveryTime = null;
        await prefs.remove('active_base_url');
        await prefs.remove('active_base_url_timestamp');
      }
    }
  }

  /// Save JWT token to secure storage (encrypted)
  static Future<void> saveToken(String token) async {
    _jwtToken = token;
    await SecureStorageService.saveToken(token);
  }

  /// Clear JWT token (logout) from secure storage
  static Future<void> clearToken() async {
    _jwtToken = null;
    await SecureStorageService.deleteToken();
  }

  /// Clear cached base URL and force re-detection
  static Future<void> clearCachedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_base_url');
    await prefs.remove('active_base_url_timestamp');
    _activeBaseUrl = null;
    _urlDiscoveryTime = null;
    print('🧹 Cleared cached API URL');
  }

  /// Get current JWT token
  static String? get token => _jwtToken;

  /// Check if user is authenticated
  static bool get isAuthenticated => _jwtToken != null && _jwtToken!.isNotEmpty;

  /// Get headers with JWT token
  static Map<String, String> _getHeaders(
      {Map<String, String>? additionalHeaders}) {
    final headers = {
      'Content-Type': 'application/json',
      ...?additionalHeaders,
    };

    if (_jwtToken != null && _jwtToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_jwtToken';
    }

    return headers;
  }

  /// Find working base URL by trying health check on each candidate.
  static Future<String?> _findWorkingBaseUrl({String endpoint = ''}) async {
    // Health check endpoint for the unified server
    String getHealthUrl(String baseUrl) => '$baseUrl/api/health';

    // Check cached URL first - only if cache is still valid
    if (_activeBaseUrl != null && _urlDiscoveryTime != null) {
      final cacheAge = DateTime.now().difference(_urlDiscoveryTime!);
      if (cacheAge < _urlCacheDuration) {
        // Cache still valid, verify it's still working (quick check)
        try {
          final healthUrl = getHealthUrl(_activeBaseUrl!);
          final response = await http
              .get(Uri.parse(healthUrl))
              .timeout(const Duration(seconds: 1)); // Reduced timeout for cached URL
          if (response.statusCode == 200) {
            return _activeBaseUrl; // Still working, return immediately
          }
        } catch (e) {
          // Cached URL not working, continue to search
          _activeBaseUrl = null;
          _urlDiscoveryTime = null;
        }
      } else {
        // Cache expired, clear it
        _activeBaseUrl = null;
        _urlDiscoveryTime = null;
      }
    }

    // Try each URL in declared order
    for (final baseUrl in baseUrls) {
      try {
        final healthUrl = getHealthUrl(baseUrl);
        final response = await http
            .get(Uri.parse(healthUrl))
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          _activeBaseUrl = baseUrl;
          _urlDiscoveryTime = DateTime.now(); // Cache discovery time
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_base_url', baseUrl);
          await prefs.setInt('active_base_url_timestamp', DateTime.now().millisecondsSinceEpoch);
          print('✅ Connected to backend: $baseUrl (for endpoint: $endpoint)');
          return baseUrl;
        }
      } catch (e) {
        // Try next URL
      }
    }

    return null;
  }

  /// Generic GET request
  static Future<http.Response?> get(String endpoint,
      {bool requireAuth = false}) async {
    if (requireAuth && !isAuthenticated) {
      throw Exception('Authentication required');
    }

    final baseUrl = await _findWorkingBaseUrl(endpoint: endpoint);
    if (baseUrl == null) {
      throw Exception('No backend server available');
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$endpoint'),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      return response;
    } catch (e) {
      print('❌ GET $endpoint failed: $e');
      rethrow;
    }
  }

  /// Generic POST request
  static Future<http.Response?> post(
    String endpoint,
    dynamic body, {
    bool requireAuth = false,
    Map<String, String>? additionalHeaders,
  }) async {
    if (requireAuth && !isAuthenticated) {
      throw Exception('Authentication required');
    }

    final baseUrl = await _findWorkingBaseUrl(endpoint: endpoint);
    if (baseUrl == null) {
      throw Exception('No backend server available');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _getHeaders(additionalHeaders: additionalHeaders),
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response;
    } catch (e) {
      print('❌ POST $endpoint failed: $e');
      rethrow;
    }
  }

  /// Generic PUT request
  static Future<http.Response?> put(
    String endpoint,
    dynamic body, {
    bool requireAuth = false,
  }) async {
    if (requireAuth && !isAuthenticated) {
      throw Exception('Authentication required');
    }

    final baseUrl = await _findWorkingBaseUrl(endpoint: endpoint);
    if (baseUrl == null) {
      throw Exception('No backend server available');
    }

    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: _getHeaders(),
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response;
    } catch (e) {
      print('❌ PUT $endpoint failed: $e');
      rethrow;
    }
  }

  /// Generic DELETE request
  static Future<http.Response?> delete(
    String endpoint, {
    bool requireAuth = false,
  }) async {
    if (requireAuth && !isAuthenticated) {
      throw Exception('Authentication required');
    }

    final baseUrl = await _findWorkingBaseUrl(endpoint: endpoint);
    if (baseUrl == null) {
      throw Exception('No backend server available');
    }

    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      return response;
    } catch (e) {
      print('❌ DELETE $endpoint failed: $e');
      rethrow;
    }
  }
}
