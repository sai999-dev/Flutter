import 'dart:convert';
import 'api_client.dart';

/// Subscription Management Service (Self-Service)
/// Implements all /api/mobile/subscription/* endpoints for agency self-service
class SubscriptionService {
  /// Get all available subscription plans
  /// GET /api/mobile/subscription/plans
  static Future<List<Map<String, dynamic>>> getPlans({
    bool activeOnly = true,
  }) async {
    print('📦 Fetching subscription plans...');

    try {
      final endpoint = '/api/mobile/subscription/plans';
      final response = await ApiClient.get(
        endpoint,
        requireAuth: false, // Plans are typically public
      );

      if (response == null || response.statusCode != 200) {
        print('❌ Failed to fetch plans: ${response?.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      List<Map<String, dynamic>> plans = [];
      
      if (data['plans'] is List) {
        plans = List<Map<String, dynamic>>.from(data['plans']);
      } else if (data['data'] is List) {
        plans = List<Map<String, dynamic>>.from(data['data']);
      } else if (data is List) {
        plans = List<Map<String, dynamic>>.from(data);
      }

      if (activeOnly) {
        plans = plans.where((plan) => 
          plan['is_active'] == true || 
          plan['active'] == true ||
          plan['status'] == 'active'
        ).toList();
      }

      print('✅ Fetched ${plans.length} subscription plans');
      return plans;
    } catch (e) {
      print('❌ Get subscription plans error: $e');
      return [];
    }
  }

  /// Subscribe to a plan
  /// POST /api/mobile/subscription/subscribe
  static Future<Map<String, dynamic>> subscribe({
    required String planId,
    String? paymentMethodId,
    Map<String, dynamic>? additionalData,
  }) async {
    print('📦 Subscribing to plan: $planId');

    try {
      final body = {
        'plan_id': planId,
        if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
        ...?additionalData,
      };

      final response = await ApiClient.post(
        '/api/mobile/subscription/subscribe',
        body,
        requireAuth: true,
      );

      if (response == null) {
        throw Exception('No response from server');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        print('✅ Subscription successful');
        return decoded;
      } else {
        final errorData = json.decode(response.body);
        final message = (errorData['message'] ?? 
            errorData['error'] ?? 
            'Subscription failed').toString();
        throw Exception(message);
      }
    } catch (e) {
      print('❌ Subscribe error: $e');
      rethrow;
    }
  }

  /// Get current agency subscription details
  /// GET /api/mobile/subscription
  static Future<Map<String, dynamic>?> getSubscription() async {
    print('📊 Fetching current subscription...');

    try {
      final response = await ApiClient.get(
        '/api/mobile/subscription',
        requireAuth: true,
      );

      if (response == null || response.statusCode != 200) {
        print('❌ Failed to fetch subscription: ${response?.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final subscription = data['subscription'] ?? data['data'] ?? data;
      
      print('✅ Fetched subscription details');
      return subscription is Map<String, dynamic> 
          ? subscription 
          : null;
    } catch (e) {
      print('❌ Get subscription error: $e');
      return null;
    }
  }

  /// Upgrade subscription to a higher plan
  /// PUT /api/mobile/subscription/upgrade
  static Future<Map<String, dynamic>> upgrade({
    required String planId,
    bool prorated = true,
  }) async {
    print('📦 Upgrading subscription to plan: $planId');

    try {
      final response = await ApiClient.put(
        '/api/mobile/subscription/upgrade',
        {
          'plan_id': planId,
          'prorated': prorated,
        },
        requireAuth: true,
      );

      if (response == null) {
        throw Exception('No response from server');
      }

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        print('✅ Subscription upgraded successfully');
        return decoded;
      } else {
        final errorData = json.decode(response.body);
        final message = (errorData['message'] ?? 
            errorData['error'] ?? 
            'Upgrade failed').toString();
        throw Exception(message);
      }
    } catch (e) {
      print('❌ Upgrade subscription error: $e');
      rethrow;
    }
  }

  /// Downgrade subscription to a lower plan
  /// PUT /api/mobile/subscription/downgrade
  static Future<Map<String, dynamic>> downgrade({
    required String planId,
    bool immediate = false,
  }) async {
    print('📦 Downgrading subscription to plan: $planId');

    try {
      final response = await ApiClient.put(
        '/api/mobile/subscription/downgrade',
        {
          'plan_id': planId,
          'immediate': immediate,
        },
        requireAuth: true,
      );

      if (response == null) {
        throw Exception('No response from server');
      }

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        print('✅ Subscription downgraded successfully');
        return decoded;
      } else {
        final errorData = json.decode(response.body);
        final message = (errorData['message'] ?? 
            errorData['error'] ?? 
            'Downgrade failed').toString();
        throw Exception(message);
      }
    } catch (e) {
      print('❌ Downgrade subscription error: $e');
      rethrow;
    }
  }

  /// Cancel subscription
  /// POST /api/mobile/subscription/cancel
  static Future<Map<String, dynamic>> cancel({
    String? reason,
    bool immediate = false,
  }) async {
    print('📦 Cancelling subscription...');

    try {
      final response = await ApiClient.post(
        '/api/mobile/subscription/cancel',
        {
          if (reason != null) 'reason': reason,
          'immediate': immediate,
        },
        requireAuth: true,
      );

      if (response == null) {
        throw Exception('No response from server');
      }

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        print('✅ Subscription cancelled successfully');
        return decoded;
      } else {
        final errorData = json.decode(response.body);
        final message = (errorData['message'] ?? 
            errorData['error'] ?? 
            'Cancel failed').toString();
        throw Exception(message);
      }
    } catch (e) {
      print('❌ Cancel subscription error: $e');
      rethrow;
    }
  }

  /// Get subscription invoices/billing history
  /// GET /api/mobile/subscription/invoices
  static Future<List<Map<String, dynamic>>> getInvoices({
    int? page,
    int? limit,
  }) async {
    print('📄 Fetching invoices...');

    try {
      String endpoint = '/api/mobile/subscription/invoices';
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();

      if (queryParams.isNotEmpty) {
        endpoint += '?${queryParams.entries.map((e) => 
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}'
        ).join('&')}';
      }

      final response = await ApiClient.get(
        endpoint,
        requireAuth: true,
      );

      if (response == null || response.statusCode != 200) {
        print('❌ Failed to fetch invoices: ${response?.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      List<Map<String, dynamic>> invoices = [];
      
      if (data['invoices'] is List) {
        invoices = List<Map<String, dynamic>>.from(data['invoices']);
      } else if (data['data'] is List) {
        invoices = List<Map<String, dynamic>>.from(data['data']);
      } else if (data is List) {
        invoices = List<Map<String, dynamic>>.from(data);
      }

      print('✅ Fetched ${invoices.length} invoices');
      return invoices;
    } catch (e) {
      print('❌ Get invoices error: $e');
      return [];
    }
  }

  /// Update payment method
  /// PUT /api/mobile/payment-method
  static Future<Map<String, dynamic>> updatePaymentMethod({
    required String paymentMethodId,
    Map<String, dynamic>? cardDetails,
  }) async {
    print('💳 Updating payment method...');

    try {
      final body = {
        'payment_method_id': paymentMethodId,
        ...?cardDetails,
      };

      final response = await ApiClient.put(
        '/api/mobile/payment-method',
        body,
        requireAuth: true,
      );

      if (response == null) {
        throw Exception('No response from server');
      }

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        print('✅ Payment method updated successfully');
        return decoded;
      } else {
        final errorData = json.decode(response.body);
        final message = (errorData['message'] ?? 
            errorData['error'] ?? 
            'Update payment method failed').toString();
        throw Exception(message);
      }
    } catch (e) {
      print('❌ Update payment method error: $e');
      rethrow;
    }
  }
}

