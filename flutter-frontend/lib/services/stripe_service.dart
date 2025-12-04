import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class StripeService {
  static const String baseUrl = 'http://localhost:5000/api/stripe';

  /// Create a Stripe checkout session and redirect to Stripe's hosted checkout page
  ///
  /// Parameters:
  /// - planId: The subscription plan ID
  /// - agencyId: The agency ID (optional if agency not created yet)
  /// - email: User's email address
  /// - customPrice: Optional custom price override
  /// - unitsPurchased: Optional number of units purchased
  ///
  /// Returns a Map with sessionId, url, subscriptionId, and transactionId
  static Future<Map<String, dynamic>> createCheckoutSession({
    required String planId,
    String? agencyId,
    required String email,
    double? customPrice,
    int? unitsPurchased,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/checkout-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'planId': planId,
          if (agencyId != null) 'agencyId': agencyId,
          'email': email,
          if (customPrice != null) 'customPrice': customPrice,
          if (unitsPurchased != null) 'unitsPurchased': unitsPurchased,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'sessionId': data['sessionId'],
          'url': data['url'],
          'subscriptionId': data['subscriptionId'],
          'transactionId': data['transactionId'],
        };
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to create checkout session');
      }
    } catch (e) {
      print('Error creating checkout session: $e');
      rethrow;
    }
  }

  /// Redirect user to Stripe's hosted checkout page
  ///
  /// Parameters:
  /// - checkoutUrl: The URL returned from createCheckoutSession
  static Future<bool> redirectToCheckout(String checkoutUrl) async {
    final uri = Uri.parse(checkoutUrl);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      throw Exception('Could not launch Stripe checkout');
    }
  }

  /// Get checkout session details
  ///
  /// Parameters:
  /// - sessionId: The Stripe checkout session ID
  static Future<Map<String, dynamic>> getCheckoutSession(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/checkout-session/$sessionId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to get checkout session');
      }
    } catch (e) {
      print('Error getting checkout session: $e');
      rethrow;
    }
  }

  /// Get subscription details
  ///
  /// Parameters:
  /// - subscriptionId: The subscription ID from your database
  static Future<Map<String, dynamic>> getSubscription(String subscriptionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/subscription/$subscriptionId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to get subscription');
      }
    } catch (e) {
      print('Error getting subscription: $e');
      rethrow;
    }
  }

  /// Update subscription
  ///
  /// Parameters:
  /// - subscriptionId: The subscription ID
  /// - customPricePerUnit: Optional custom price per unit
  /// - unitsPurchased: Optional number of units
  static Future<Map<String, dynamic>> updateSubscription(
    String subscriptionId, {
    double? customPricePerUnit,
    int? unitsPurchased,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/subscription/$subscriptionId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (customPricePerUnit != null) 'custom_price_per_unit': customPricePerUnit,
          if (unitsPurchased != null) 'units_purchased': unitsPurchased,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to update subscription');
      }
    } catch (e) {
      print('Error updating subscription: $e');
      rethrow;
    }
  }

  /// Cancel subscription
  ///
  /// Parameters:
  /// - subscriptionId: The subscription ID
  /// - immediate: Whether to cancel immediately or at period end
  static Future<Map<String, dynamic>> cancelSubscription(
    String subscriptionId, {
    bool immediate = false,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/subscription/$subscriptionId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'immediate': immediate,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to cancel subscription');
      }
    } catch (e) {
      print('Error canceling subscription: $e');
      rethrow;
    }
  }
}
