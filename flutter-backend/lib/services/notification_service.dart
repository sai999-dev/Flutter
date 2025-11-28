// ------------------------
// 🔥 FCM NOTIFICATION SERVICE (Required)
// ------------------------

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';




class FCMNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// 🚀 Initialize notifications (Android only)
  static Future<void> initNotifications() async {
    if (kIsWeb) {
      print("🌍 Web detected — Skipping Android notification initialization");
      return;
    }

    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    final token = await _fcm.getToken();
    print("🔑 Android FCM Token: $token");

    // Save token to backend
    if (token != null) {
      await ApiClient.post('/api/v1/agencies/save-device-token', {
        'token': token,
        "agency_id": "4fb78be8-6cc0-4740-be77-706de3af29fa",
      });
    }

    // Setup local notifications channel
    const channel = AndroidNotificationChannel(
      'high_priority',
      'High Priority Notifications',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Initialize local notification plugin
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print("📌 Notification clicked!");
      },
    );

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Foreground Notification: ${message.notification?.title}");

      _notifications.show(
        message.hashCode,
        message.notification?.title,
        message.notification?.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_priority',
            'High Priority Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    });

    // Background click handler
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📲 User clicked notification while app was closed");
    });
  }
}






/// Notification Settings Service
/// Implements: GET /api/mobile/notifications/settings, PUT /api/mobile/notifications/settings
class NotificationService {
  /// Get notification preferences from backend
  /// GET /api/mobile/notifications/settings
  static Future<Map<String, dynamic>?> getSettings() async {
    print('📲 Fetching notification settings...');

    try {
      final response = await ApiClient.get(
        '/api/mobile/notifications/settings',
        requireAuth: true,
      );

      if (response == null) {
        return null;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Save to local storage for offline access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('notification_settings', json.encode(data));

        print('✅ Notification settings loaded');
        return data;
      } else {
        print('❌ Failed to fetch settings: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Get notification settings error: $e');
      // Return local cached settings if available
      return await _getLocalSettings();
    }
  }

  /// Update notification preferences on backend
  /// PUT /api/mobile/notifications/settings
  static Future<bool> updateSettings({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    Map<String, dynamic>? quietHours,
    List<String>? notificationTypes,
  }) async {
    print('💾 Updating notification settings...');

    try {
      final settings = <String, dynamic>{};

      if (pushEnabled != null) settings['push_enabled'] = pushEnabled;
      if (emailEnabled != null) settings['email_enabled'] = emailEnabled;
      if (smsEnabled != null) settings['sms_enabled'] = smsEnabled;
      if (soundEnabled != null) settings['sound_enabled'] = soundEnabled;
      if (vibrationEnabled != null) {
        settings['vibration_enabled'] = vibrationEnabled;
      }
      if (quietHours != null) settings['quiet_hours'] = quietHours;
      if (notificationTypes != null) {
        settings['notification_types'] = notificationTypes;
      }

      final response = await ApiClient.put(
        '/api/mobile/notifications/settings',
        settings,
        requireAuth: true,
      );

      if (response == null) {
        // Save locally even if backend fails
        await _saveLocalSettings(settings);
        return false;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('notification_settings', json.encode(data));

        // Also update individual preferences for backward compatibility
        if (pushEnabled != null) {
          await prefs.setBool('push_notifications', pushEnabled);
        }
        if (emailEnabled != null) {
          await prefs.setBool('email_notifications', emailEnabled);
        }
        if (smsEnabled != null) {
          await prefs.setBool('sms_notifications', smsEnabled);
        }

        print('✅ Notification settings updated');
        return true;
      } else {
        print('❌ Failed to update settings: ${response.statusCode}');
        // Save locally as fallback
        await _saveLocalSettings(settings);
        return false;
      }
    } catch (e) {
      print('❌ Update notification settings error: $e');
      // Save locally as fallback
      await _saveLocalSettings({
        if (pushEnabled != null) 'push_enabled': pushEnabled,
        if (emailEnabled != null) 'email_enabled': emailEnabled,
        if (smsEnabled != null) 'sms_enabled': smsEnabled,
        if (soundEnabled != null) 'sound_enabled': soundEnabled,
        if (vibrationEnabled != null) 'vibration_enabled': vibrationEnabled,
      });
      return false;
    }
  }

  /// Get local cached settings
  static Future<Map<String, dynamic>?> _getLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('notification_settings');

      if (settingsJson != null) {
        return json.decode(settingsJson);
      }

      // Fallback to old individual preferences
      return {
        'push_enabled': prefs.getBool('push_notifications') ?? true,
        'email_enabled': prefs.getBool('email_notifications') ?? true,
        'sms_enabled': prefs.getBool('sms_notifications') ?? false,
        'sound_enabled': true,
        'vibration_enabled': true,
      };
    } catch (e) {
      return null;
    }
  }

  /// Save settings locally
  static Future<void> _saveLocalSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notification_settings', json.encode(settings));

      // Update individual preferences for backward compatibility
      if (settings.containsKey('push_enabled')) {
        await prefs.setBool('push_notifications', settings['push_enabled']);
      }
      if (settings.containsKey('email_enabled')) {
        await prefs.setBool('email_notifications', settings['email_enabled']);
      }
      if (settings.containsKey('sms_enabled')) {
        await prefs.setBool('sms_notifications', settings['sms_enabled']);
      }
    } catch (e) {
      print('❌ Save local settings error: $e');
    }
  }

  /// Get individual notification preference (with offline support)
  static Future<bool> isPushEnabled() async {
    final settings = await _getLocalSettings();
    return settings?['push_enabled'] ?? true;
  }

  static Future<bool> isEmailEnabled() async {
    final settings = await _getLocalSettings();
    return settings?['email_enabled'] ?? true;
  }

  static Future<bool> isSmsEnabled() async {
    final settings = await _getLocalSettings();
    return settings?['sms_enabled'] ?? false;
  }

  static Future<bool> isSoundEnabled() async {
    final settings = await _getLocalSettings();
    return settings?['sound_enabled'] ?? true;
  }

  static Future<bool> isVibrationEnabled() async {
    final settings = await _getLocalSettings();
    return settings?['vibration_enabled'] ?? true;
  }

  /// Sync local settings with backend (call on app start)
  static Future<void> syncSettings() async {
    print('🔄 Syncing notification settings with backend...');

    try {
      // Get settings from backend
      final backendSettings = await getSettings();

      if (backendSettings != null) {
        print('✅ Settings synced from backend');
      } else {
        // Push local settings to backend if backend doesn't have them
        final localSettings = await _getLocalSettings();
        if (localSettings != null) {
          await updateSettings(
            pushEnabled: localSettings['push_enabled'],
            emailEnabled: localSettings['email_enabled'],
            smsEnabled: localSettings['sms_enabled'],
            soundEnabled: localSettings['sound_enabled'],
            vibrationEnabled: localSettings['vibration_enabled'],
          );
          print('✅ Local settings pushed to backend');
        }
      }
    } catch (e) {
      print('❌ Sync settings error: $e');
    }
  }
}
