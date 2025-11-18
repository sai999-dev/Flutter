// Flutter Backend Package
// Export all backend services for easy importing

import 'package:firebase_messaging/firebase_messaging.dart';

class PushTokenHelper {
  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      print("❌ Error getting FCM token: $e");
      return null;
    }
  }
}


// Services
export 'services/api_client.dart';
export 'services/auth_service.dart';
export 'services/lead_service.dart';
export 'services/subscription_service.dart';
export 'services/territory_service.dart';
export 'services/notification_service.dart';
export 'services/document_verification_service.dart';
export 'services/audit_logs_service.dart';
// Note: subscription_plan_service.dart not exported due to name conflict

// Storage
export 'storage/secure_storage_service.dart';
export 'storage/cache_service.dart';

// Utils
export 'utils/zipcode_lookup_service.dart';
export 'utils/zipcode_service.dart';

