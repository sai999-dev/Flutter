// lib/services/api_endpoints.dart
import '../config/api_config.dart';

class ApiEndpoints {
  // Health Check
  static final String health = "${ApiConfig.activeBaseUrl}/api/health";

  // Authentication Endpoints
  static final String register = "${ApiConfig.activeBaseUrl}/api/mobile/auth/register";
  static final String verifyEmail = "${ApiConfig.activeBaseUrl}/api/mobile/auth/verify-email";
  static final String login = "${ApiConfig.activeBaseUrl}/api/mobile/auth/login";
  static final String forgotPassword = "${ApiConfig.activeBaseUrl}/api/mobile/auth/forgot-password";
  static final String verifyCode = "${ApiConfig.activeBaseUrl}/api/mobile/auth/verify-reset-code";
  static final String resetPassword = "${ApiConfig.activeBaseUrl}/api/mobile/auth/reset-password";
  static final String registerDevice = "${ApiConfig.activeBaseUrl}/api/mobile/auth/register-device";
  static final String updateDevice = "${ApiConfig.activeBaseUrl}/api/mobile/auth/update-device";
  static final String unregisterDevice = "${ApiConfig.activeBaseUrl}/api/mobile/auth/unregister-device";

  // Document Verification Endpoints
  static final String uploadDocument = "${ApiConfig.activeBaseUrl}/api/mobile/auth/upload-document";
  static final String verificationStatus = "${ApiConfig.activeBaseUrl}/api/mobile/auth/verification-status";
  static final String documents = "${ApiConfig.activeBaseUrl}/api/mobile/auth/documents";

  // Subscription Endpoints
  static final String subscriptionPlans = "${ApiConfig.activeBaseUrl}/api/mobile/subscription/plans";
  static final String subscribe = "${ApiConfig.activeBaseUrl}/api/mobile/subscription/subscribe";
  static final String subscription = "${ApiConfig.activeBaseUrl}/api/mobile/subscription";
  static final String upgradeSubscription = "${ApiConfig.activeBaseUrl}/api/mobile/subscription/upgrade";
  static final String downgradeSubscription = "${ApiConfig.activeBaseUrl}/api/mobile/subscription/downgrade";
  static final String cancelSubscription = "${ApiConfig.activeBaseUrl}/api/mobile/subscription/cancel";
  static final String subscriptionInvoices = "${ApiConfig.activeBaseUrl}/api/mobile/subscription/invoices";
  static final String paymentMethod = "${ApiConfig.activeBaseUrl}/api/mobile/payment-method";

  // Lead Endpoints
  static String leads({String? queryString}) => "${ApiConfig.activeBaseUrl}/api/mobile/leads${queryString ?? ''}";
  static String leadById(String leadId) => "${ApiConfig.activeBaseUrl}/api/mobile/leads/$leadId";
  static String leadStatus(String leadId) => "${ApiConfig.activeBaseUrl}/api/mobile/leads/$leadId/status";
  static String leadView(String leadId) => "${ApiConfig.activeBaseUrl}/api/mobile/leads/$leadId/view";
  static String leadCall(String leadId) => "${ApiConfig.activeBaseUrl}/api/mobile/leads/$leadId/call";
  static String leadNotes(String leadId) => "${ApiConfig.activeBaseUrl}/api/mobile/leads/$leadId/notes";
  static String leadAccept(String leadId) => "${ApiConfig.activeBaseUrl}/api/mobile/leads/$leadId/accept";
  static String leadReject(String leadId) => "${ApiConfig.activeBaseUrl}/api/mobile/leads/$leadId/reject";

  // Territory Endpoints
  static final String territories = "${ApiConfig.activeBaseUrl}/api/mobile/territories";
  static String territoryById(String territoryId) => "${ApiConfig.activeBaseUrl}/api/mobile/territories/$territoryId";
  static String territoryByZipcode(String zipcode) => "${ApiConfig.activeBaseUrl}/api/mobile/territories/$zipcode";

  // Notification Endpoints
  static final String notificationSettings = "${ApiConfig.activeBaseUrl}/api/mobile/notifications/settings";
}

