import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Territory/Zipcode Management Service
/// Implements: GET/POST/DELETE /api/mobile/territories
class TerritoryService {
  /// Get agency's selected zipcodes from backend
  /// GET /api/mobile/territories
  static Future<List<String>> getZipcodes() async {
    print('📍 Fetching agency territories...');

    try {
      final response = await ApiClient.get(
        '/api/mobile/territories',
        requireAuth: true,
      );

      if (response == null) {
        print('❌ No response from server');
        return await _getLocalZipcodes();
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final zipcodes = List<String>.from(data['zipcodes'] ?? []);

        // Save to local storage for offline access
        await _saveLocalZipcodes(zipcodes);

        print('✅ Fetched ${zipcodes.length} territories');
        return zipcodes;
      } else {
        print('❌ Failed to fetch territories: ${response.statusCode}');
        return await _getLocalZipcodes();
      }
    } catch (e) {
      print('❌ Get territories error: $e');
      // Return local cached territories if available
      return await _getLocalZipcodes();
    }
  }

  /// Add new zipcode territory
  /// POST /api/mobile/territories
  static Future<bool> addZipcode(String zipcode, {String? city}) async {
    print('📍 Adding territory: $zipcode');

    try {
      final response = await ApiClient.post(
        '/api/mobile/territories',
        {
          'zipcode': zipcode,
          'city': city,
        },
        requireAuth: true,
      );

      if (response == null) {
        // Save locally even if backend fails
        await _addLocalZipcode(zipcode, city);
        return false;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Also save locally
        await _addLocalZipcode(zipcode, city);
        print('✅ Territory added successfully');
        return true;
      } else if (response.statusCode == 409) {
        print('⚠️ Territory already exists');
        return false;
      } else if (response.statusCode == 403) {
        print('❌ Territory limit reached');
        final data = json.decode(response.body);
        throw Exception(data['error'] ?? 'Territory limit reached');
      } else {
        print('❌ Failed to add territory: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Add territory error: $e');
      rethrow;
    }
  }

  /// Update existing territory
  /// PUT /api/mobile/territories/:id
  static Future<bool> updateTerritory({
    required String territoryId,
    String? zipcode,
    String? city,
    Map<String, dynamic>? additionalData,
  }) async {
    print('📍 Updating territory: $territoryId');

    try {
      final body = <String, dynamic>{};
      if (zipcode != null) body['zipcode'] = zipcode;
      if (city != null) body['city'] = city;
      if (additionalData != null) body.addAll(additionalData);

      final response = await ApiClient.put(
        '/api/mobile/territories/$territoryId',
        body,
        requireAuth: true,
      );

      if (response == null) {
        return false;
      }

      if (response.statusCode == 200) {
        print('✅ Territory updated successfully');
        return true;
      } else {
        print('❌ Failed to update territory: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Update territory error: $e');
      return false;
    }
  }

  /// Remove territory by ID
  /// DELETE /api/mobile/territories/:id
  static Future<bool> removeTerritory(String territoryId) async {
    print('📍 Removing territory: $territoryId');

    try {
      final response = await ApiClient.delete(
        '/api/mobile/territories/$territoryId',
        requireAuth: true,
      );

      if (response == null) {
        return false;
      }

      if (response.statusCode == 200) {
        print('✅ Territory removed successfully');
        return true;
      } else {
        print('❌ Failed to remove territory: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Remove territory error: $e');
      return false;
    }
  }

  /// Remove zipcode territory (legacy method - kept for backward compatibility)
  /// DELETE /api/mobile/territories/:zipcode
  @Deprecated('Use removeTerritory(territoryId) instead')
  static Future<bool> removeZipcode(String zipcode) async {
    print('📍 Removing territory by zipcode: $zipcode');

    try {
      final response = await ApiClient.delete(
        '/api/mobile/territories/$zipcode',
        requireAuth: true,
      );

      if (response == null) {
        await _removeLocalZipcode(zipcode);
        return false;
      }

      if (response.statusCode == 200) {
        await _removeLocalZipcode(zipcode);
        print('✅ Territory removed successfully');
        return true;
      } else {
        print('❌ Failed to remove territory: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Remove territory error: $e');
      return false;
    }
  }

  /// Sync local zipcodes with backend on login
  static Future<void> syncZipcodes() async {
    print('🔄 Syncing zipcodes...');

    try {
      // Get zipcodes from backend
      final serverZipcodes = await getZipcodes();

      // Save to local storage
      await _saveLocalZipcodes(serverZipcodes);

      print('✅ Zipcodes synced successfully');
    } catch (e) {
      print('❌ Sync zipcodes error: $e');
    }
  }

  // ===== LOCAL STORAGE HELPERS =====

  static Future<List<String>> _getLocalZipcodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedZipcodes = prefs.getStringList('user_zipcodes') ?? [];
      return savedZipcodes;
    } catch (e) {
      print('❌ Get local zipcodes error: $e');
      return [];
    }
  }

  static Future<void> _saveLocalZipcodes(List<String> zipcodes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_zipcodes', zipcodes);
    } catch (e) {
      print('❌ Save local zipcodes error: $e');
    }
  }

  static Future<void> _addLocalZipcode(String zipcode, String? city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedZipcodes = prefs.getStringList('user_zipcodes') ?? [];
      final entry = city != null ? '$zipcode|$city' : zipcode;

      if (!savedZipcodes.contains(entry)) {
        savedZipcodes.add(entry);
        await prefs.setStringList('user_zipcodes', savedZipcodes);
      }
    } catch (e) {
      print('❌ Add local zipcode error: $e');
    }
  }

  static Future<void> _removeLocalZipcode(String zipcode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedZipcodes = prefs.getStringList('user_zipcodes') ?? [];
      savedZipcodes.removeWhere((z) => z.startsWith(zipcode));
      await prefs.setStringList('user_zipcodes', savedZipcodes);
    } catch (e) {
      print('❌ Remove local zipcode error: $e');
    }
  }
}
