import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage Service for sensitive data
/// Uses flutter_secure_storage for encrypted storage on device
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Save JWT token securely
  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: 'jwt_token', value: token);
    } catch (e) {
      print('❌ Secure storage save token error: $e');
      rethrow;
    }
  }

  /// Get JWT token
  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: 'jwt_token');
    } catch (e) {
      print('❌ Secure storage get token error: $e');
      return null;
    }
  }

  /// Delete JWT token
  static Future<void> deleteToken() async {
    try {
      await _storage.delete(key: 'jwt_token');
    } catch (e) {
      print('❌ Secure storage delete token error: $e');
    }
  }

  /// Clear all secure storage
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('❌ Secure storage clear all error: $e');
    }
  }

  /// Save any sensitive key-value pair
  static Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      print('❌ Secure storage write error: $e');
      rethrow;
    }
  }

  /// Read any sensitive key-value pair
  static Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      print('❌ Secure storage read error: $e');
      return null;
    }
  }

  /// Delete any sensitive key-value pair
  static Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      print('❌ Secure storage delete error: $e');
    }
  }
}

