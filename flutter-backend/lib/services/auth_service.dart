import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Mobile Authentication Service
/// Implements: Registration, Email Verification, and Login endpoints
class AuthService {
  /// Register a new agency
  /// POST /api/mobile/auth/register
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String agencyName,
    String? phone,
    Map<String, dynamic>? additionalData,
  }) async {
    print('🔐 Registering new agency: $email');

    try {
      final body = {
        'email': email,
        'password': password,
        'agency_name': agencyName,
        if (phone != null) 'phone': phone,
        ...?additionalData,
      };

      // ✅ Registration is a public endpoint - no authentication required
      final response = await ApiClient.post(
        '/api/mobile/auth/register',
        body,
        requireAuth: false, // Explicitly set to false - registration is public
      );

      if (response == null) {
        // ✅ LIVE MODE: Always require real backend - no test mode fallback
        throw Exception('No response from server - Backend server is not running');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        print('✅ Registration successful');
        print('📋 Response data: $decoded');
        return decoded;
      } else {
        // Handle error response with detailed logging
        String errorMessage = 'Registration failed';
        Map<String, dynamic>? errorData;
        
        try {
          errorData = json.decode(response.body) as Map<String, dynamic>;
          errorMessage = (errorData['message'] ?? 
              errorData['error'] ?? 
              errorData['msg'] ??
              errorData['errorMessage'] ??
              'Registration failed').toString();
          
          print('❌ Registration failed: $errorMessage');
          print('❌ Status code: ${response.statusCode}');
          print('❌ Full error response: ${response.body}');
          print('❌ Error data: $errorData');
          
          // Include additional error details if available
          if (errorData.containsKey('errors')) {
            print('❌ Validation errors: ${errorData['errors']}');
          }
          if (errorData.containsKey('details')) {
            print('❌ Error details: ${errorData['details']}');
          }
        } catch (parseError) {
          // If response body is not JSON, use status code and raw body
          errorMessage = 'Registration failed (Status: ${response.statusCode})';
          if (response.body.isNotEmpty) {
            errorMessage += ': ${response.body}';
          }
          print('❌ Registration failed - Invalid JSON response');
          print('❌ Status code: ${response.statusCode}');
          print('❌ Raw response body: ${response.body}');
          print('❌ Parse error: $parseError');
        }
        
        // Create detailed error message
        final detailedError = errorData != null && errorData.containsKey('errors')
            ? '$errorMessage\n\nDetails: ${errorData['errors']}'
            : errorMessage;
        
        throw Exception(detailedError);
      }
    } catch (e) {
      print('❌ Registration error: $e');
      print('❌ Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Verify agency email address
  /// POST /api/mobile/auth/verify-email
  static Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String verificationCode,
  }) async {
    print('🔐 Verifying email: $email');

    try {
      final response = await ApiClient.post(
        '/api/mobile/auth/verify-email',
        {
          'email': email,
          'verification_code': verificationCode,
        },
      );

      if (response == null) {
        throw Exception('No response from server');
      }

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        
        // Save token if provided
        final token = decoded['token'];
        if (token != null && token is String && token.isNotEmpty) {
          await ApiClient.saveToken(token);
        }

        print('✅ Email verification successful');
        return decoded;
      } else {
        final errorData = json.decode(response.body);
        final message = (errorData['message'] ?? 
            errorData['error'] ?? 
            'Email verification failed').toString();
        throw Exception(message);
      }
    } catch (e) {
      print('❌ Email verification error: $e');
      rethrow;
    }
  }

  /// Login with email and password
  /// POST /api/mobile/auth/login
  /// Returns JWT token and user profile
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    print('🔐 Attempting login: $email');

    try {
      final response = await ApiClient.post(
        '/api/mobile/auth/login',
        {
          'email': email,
          'password': password,
        },
      );

      if (response == null) {
        throw Exception('No response from server');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        print('📋 Login response: $decoded');

        // Token is top-level in our API
        final token = decoded['token'];
        if (token != null && token is String && token.isNotEmpty) {
          await ApiClient.saveToken(token);
          print('✅ JWT token saved');
        } else {
          print('⚠️ No token in response');
        }

        // Normalize profile: API wraps fields under `data`
        final profile = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;

        // Persist
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile', json.encode(profile));
        final agencyId = profile['agency_id'] ?? profile['id'] ?? '';
        if (agencyId.toString().isNotEmpty) {
          await prefs.setString('agency_id', agencyId.toString());
          print('✅ Agency ID saved: $agencyId');
        }
        await prefs.setString('last_login', DateTime.now().toIso8601String());

        print('✅ Login successful');
        return decoded;
      } else {
        // Handle error response
        String errorMessage = 'Login failed';
        try {
          final errorData = json.decode(response.body);
          errorMessage = (errorData['message'] ?? 
              errorData['error'] ?? 
              errorData['msg'] ??
              'Login failed').toString();
          print('❌ Login failed: $errorMessage');
          print('❌ Status code: ${response.statusCode}');
          print('❌ Response body: ${response.body}');
        } catch (parseError) {
          // If response body is not JSON, use status code
          errorMessage = 'Login failed (Status: ${response.statusCode})';
          print('❌ Login failed - Invalid JSON response: ${response.body}');
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Login error: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e.toString().contains('No backend server available')) {
        throw Exception('Backend server is not running. Please start the backend server.');
      }
      rethrow;
    }
  }

  /// Register device for push notifications
  /// POST /api/mobile/auth/register-device
  static Future<bool> registerDevice({
    required String deviceToken,
    required String platform, // 'ios' or 'android'
    String? deviceModel,
    String? appVersion,
  }) async {
    print('📱 Registering device for push notifications...');

    try {
      final response = await ApiClient.post(
        '/api/mobile/auth/register-device',
        {
          'device_token': deviceToken,
          'platform': platform,
          'device_model': deviceModel,
          'app_version': appVersion,
        },
        requireAuth: true,
      );

      if (response == null) {
        return false;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Save device registration locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_token', deviceToken);
        await prefs.setString('device_platform', platform);
        await prefs.setBool('device_registered', true);

        print('✅ Device registered successfully');
        return true;
      } else {
        print('❌ Device registration failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Device registration error: $e');
      return false;
    }
  }

  /// Update device token when it changes
  /// PUT /api/mobile/auth/update-device
  static Future<bool> updateDevice({
    required String deviceToken,
    String? appVersion,
  }) async {
    print('🔄 Updating device token...');

    try {
      final response = await ApiClient.put(
        '/api/mobile/auth/update-device',
        {
          'device_token': deviceToken,
          'app_version': appVersion,
          'last_seen': DateTime.now().toIso8601String(),
        },
        requireAuth: true,
      );

      if (response == null) {
        return false;
      }

      if (response.statusCode == 200) {
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_token', deviceToken);

        print('✅ Device updated successfully');
        return true;
      } else {
        print('❌ Device update failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Device update error: $e');
      return false;
    }
  }

  /// Unregister device on logout
  /// DELETE /api/mobile/auth/unregister-device
  static Future<bool> unregisterDevice() async {
    print('🚫 Unregistering device...');

    try {
      final response = await ApiClient.delete(
        '/api/mobile/auth/unregister-device',
        requireAuth: true,
      );

      if (response == null) {
        return false;
      }

      if (response.statusCode == 200) {
        // Clear device info from local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('device_token');
        await prefs.remove('device_platform');
        await prefs.setBool('device_registered', false);

        print('✅ Device unregistered successfully');
        return true;
      } else {
        print('❌ Device unregister failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Device unregister error: $e');
      return false;
    }
  }

  /// Logout - clear token and unregister device
  static Future<void> logout() async {
    print('👋 Logging out...');

    try {
      // Unregister device from push notifications
      await unregisterDevice();

      // Clear JWT token
      await ApiClient.clearToken();

      // Clear user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile');
      await prefs.remove('agency_id');
      await prefs.remove('last_login');

      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  /// Get current user profile from storage
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');

      if (profileJson != null) {
        return json.decode(profileJson);
      }

      return null;
    } catch (e) {
      print('❌ Get user profile error: $e');
      return null;
    }
  }

  /// Get current agency ID
  static Future<String?> getAgencyId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('agency_id');
    } catch (e) {
      return null;
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    return ApiClient.isAuthenticated;
  }

  /// Request password reset
  /// POST /api/mobile/auth/forgot-password
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    print('🔐 Requesting password reset for: $email');

    try {
      final response = await ApiClient.post(
        '/api/mobile/auth/forgot-password',
        {
          'email': email,
        },
      );

      if (response == null) {
        throw Exception('No response from server');
      }

      final decoded = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && decoded['success'] == true) {
        print('✅ Password reset requested successfully');
        return decoded;
      } else {
        final message = (decoded['message'] ?? 'Failed to request password reset').toString();
        throw Exception(message);
      }
    } catch (e) {
      print('❌ Forgot password error: $e');
      rethrow;
    }
  }
}
