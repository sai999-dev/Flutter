import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {

  /// Register a new agency
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String agencyName,
    String? phone,
    Map<String, dynamic>? additionalData,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    print('🔐 Registering new agency: $normalizedEmail');

    try {
      final body = {
        'email': normalizedEmail,
        'password': normalizedPassword,
        'agency_name': agencyName.trim(),
        if (phone != null) 'phone': phone.trim(),
        ...?additionalData,
      };

      final response = await ApiClient.post(
        '/api/mobile/auth/register',
        body,
        requireAuth: false,
      );

      if (response == null) {
        throw Exception('No response from server');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        print('✅ Registration successful');
        return decoded;
      } else {
        final errorData = json.decode(response.body);
        final message = errorData['message'] ?? "Registration failed";
        throw Exception(message);
      }
    } catch (e) {
      print('❌ Registration error: $e');
      rethrow;
    }
  }

  /// Verify email
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
        final decoded = json.decode(response.body);
        final token = decoded['token'];
        if (token != null) await ApiClient.saveToken(token);
        print('✅ Email verification successful');
        return decoded;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Verification failed');
      }
    } catch (e) {
      print('❌ Verify email error: $e');
      rethrow;
    }
  }

  /// LOGIN
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    print('🔐 Attempting login: $normalizedEmail');

    await ApiClient.clearToken();

    try {
      final response = await ApiClient.post(
        '/api/mobile/auth/login',
        {
          'email': normalizedEmail,
          'password': normalizedPassword,
        },
        requireAuth: false,
      );

      if (response == null) throw Exception('No response from server');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);

        final token = decoded['token'];
        if (token != null) await ApiClient.saveToken(token);

        final profile = decoded['data'] is Map<String, dynamic>
            ? decoded['data']
            : decoded;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile', json.encode(profile));

        final agencyId = profile['agency_id'] ?? profile['id'] ?? '';
        if (agencyId.toString().isNotEmpty) {
          await prefs.setString('agency_id', agencyId.toString());
        }

        print('✅ Login successful');

        return decoded;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('❌ Login error: $e');
      rethrow;
    }
  }

  /// REGISTER DEVICE (Unused, but kept)
  static Future<bool> registerDevice({
    required String deviceToken,
    required String platform,
    String? deviceModel,
    String? appVersion,
  }) async {
    print('📱 Registering device...');

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

      if (response == null) return false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_token', deviceToken);
        await prefs.setBool('device_registered', true);

        return true;
      }
      return false;
    } catch (e) {
      print('❌ Register device error: $e');
      return false;
    }
  }

  /// UPDATE DEVICE
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

      if (response == null) return false;

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_token', deviceToken);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Update device error: $e');
      return false;
    }
  }

  /// UNREGISTER
  static Future<bool> unregisterDevice() async {
    print('🚫 Unregistering device...');

    try {
      final response = await ApiClient.delete(
        '/api/mobile/auth/unregister-device',
        requireAuth: true,
      );

      if (response == null) return false;

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('device_token');
        await prefs.setBool('device_registered', false);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Unregister error: $e');
      return false;
    }
  }

  /// LOGOUT
  static Future<void> logout() async {
    print('👋 Logging out...');

    try {
      await unregisterDevice();
      await ApiClient.clearToken();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile');
      await prefs.remove('agency_id');
      await prefs.remove('last_login');

      print('✅ Logout complete');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  /// GET PROFILE
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      if (profileJson != null) return json.decode(profileJson);
      return null;
    } catch (e) {
      print('❌ Get profile error: $e');
      return null;
    }
  }

  static Future<String?> getAgencyId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('agency_id');
    } catch (e) {
      return null;
    }
  }

  static Future<bool> isLoggedIn() async {
    return ApiClient.isAuthenticated;
  }

  /// Forgot password
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      final response = await ApiClient.post(
        '/api/mobile/auth/forgot-password',
        {'email': normalizedEmail},
        requireAuth: false,
      );

      if (response == null) throw Exception("No server response");

      final decoded = json.decode(response.body);
      if (decoded['success'] == true) return decoded;

      throw Exception(decoded['message'] ?? "Failed");
    } catch (e) {
      print("❌ Forgot password error: $e");
      rethrow;
    }
  }

  /// Verify reset code
  static Future<Map<String, dynamic>> verifyResetCode(
      String email, String code) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      final response = await ApiClient.post(
        '/api/mobile/auth/verify-reset-code',
        {
          'email': normalizedEmail,
          'code': code.trim(),
        },
        requireAuth: false,
      );

      if (response == null) throw Exception("No server response");

      final decoded = json.decode(response.body);
      if (decoded['success'] == true) return decoded;

      throw Exception(decoded['message'] ?? "Invalid code");
    } catch (e) {
      print("❌ Verify code error: $e");
      rethrow;
    }
  }

  /// Reset password
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (newPassword.length < 6) {
      throw Exception("Password must be at least 6 characters");
    }

    try {
      final response = await ApiClient.post(
        '/api/mobile/auth/reset-password',
        {
          'email': normalizedEmail,
          'code': code.trim(),
          'new_password': newPassword.trim(),
        },
        requireAuth: false,
      );

      if (response == null) throw Exception("No server response");

      final decoded = json.decode(response.body);
      if (decoded['success'] == true) return decoded;

      throw Exception(decoded['message'] ?? "Reset failed");
    } catch (e) {
      print("❌ Reset password error: $e");
      rethrow;
    }
  }
}
