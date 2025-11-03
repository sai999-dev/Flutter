import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache Service for Flutter App
/// Provides TTL-based caching for API responses
class CacheService {
  static const String _cachePrefix = 'api_cache_';
  static const String _timestampPrefix = 'cache_ts_';

  /// Get cached data if still valid
  static Future<Map<String, dynamic>?> getCached(
    String key, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final timestampKey = '$_timestampPrefix$key';

      // Check if cache exists
      final cachedData = prefs.getString(cacheKey);
      final cachedTimestamp = prefs.getInt(timestampKey);

      if (cachedData == null || cachedTimestamp == null) {
        return null;
      }

      // Check if cache is expired
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheAge = now - cachedTimestamp;
      if (cacheAge > ttl.inMilliseconds) {
        // Cache expired, remove it
        await prefs.remove(cacheKey);
        await prefs.remove(timestampKey);
        return null;
      }

      // Return cached data
      return json.decode(cachedData) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Cache get error: $e');
      return null;
    }
  }

  /// Cache data with TTL
  static Future<void> setCached(
    String key,
    Map<String, dynamic> data, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final timestampKey = '$_timestampPrefix$key';

      await prefs.setString(cacheKey, json.encode(data));
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ Cache set error: $e');
    }
  }

  /// Clear specific cache
  static Future<void> clearCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final timestampKey = '$_timestampPrefix$key';

      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
    } catch (e) {
      print('❌ Cache clear error: $e');
    }
  }

  /// Clear all caches
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith(_cachePrefix) || key.startsWith(_timestampPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('❌ Clear all cache error: $e');
    }
  }

  /// Cache list data
  static Future<List<Map<String, dynamic>>?> getCachedList(
    String key, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final cached = await getCached(key, ttl: ttl);
    if (cached == null) return null;

    if (cached.containsKey('data') && cached['data'] is List) {
      return List<Map<String, dynamic>>.from(cached['data']);
    }
    return null;
  }

  /// Cache list data
  static Future<void> setCachedList(
    String key,
    List<Map<String, dynamic>> data, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    await setCached(key, {'data': data}, ttl: ttl);
  }
}

