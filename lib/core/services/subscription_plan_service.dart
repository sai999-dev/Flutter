import 'dart:convert';
import 'api_client.dart';

/// Subscription Management Service (Self-Service)
/// Implements all /api/mobile/subscription/* endpoints for agency self-service
class SubscriptionService {
  /// Get all active subscription plans
  /// GET /api/mobile/subscription/plans?isActive=true (public)
  static Future<List<Map<String, dynamic>>> getPlans(
      {bool activeOnly = true}) async {
    print('📦 Fetching subscription plans...');

    try {
      final endpoint =
          '/api/mobile/subscription/plans${activeOnly ? '?isActive=true' : ''}';
      final response = await ApiClient.get(
        endpoint,
        requireAuth: false, // Plans might be public
      );

      if (response == null) {
        print('❌ No response from server');
        return [];
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final plans =
              List<Map<String, dynamic>>.from(data['data']['plans'] ?? []);
          print('✅ Fetched ${plans.length} subscription plans');
          return plans;
        }
        return [];
      } else {
        print('❌ Failed to fetch plans: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Get subscription plans error: $e');
      return [];
    }
  }

  /// Get a specific plan by ID
  static Future<Map<String, dynamic>?> getPlanById(String planId) async {
    final plans = await getPlans();
    try {
      return plans.firstWhere((plan) => plan['id'] == planId);
    } catch (e) {
      return null;
    }
  }

  /// Get current subscription status from backend
  /// GET /api/mobile/subscription/status (requires auth)
  static Future<Map<String, dynamic>?> getSubscriptionStatus() async {
    print('📊 Fetching subscription status...');

    try {
      final response = await ApiClient.get(
        '/api/mobile/subscription/status',
        requireAuth: true,
      );

      if (response == null) {
        print('❌ No response from server');
        return null;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          print('✅ Fetched subscription status');
          return data['data'];
        }
        return null;
      } else {
        print('❌ Failed to fetch subscription status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Get subscription status error: $e');
      return null;
    }
  }
}
