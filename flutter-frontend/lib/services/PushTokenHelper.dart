import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushTokenHelper {
  static final FirebaseMessaging _fm = FirebaseMessaging.instance;

  // ----------------------------------------------------------
  // INITIALIZER (ANDROID ONLY)
  // ----------------------------------------------------------
  static Future<void> initializeFCM() async {
    if (kIsWeb) {
      print("🌍 Web detected — skipping Android FCM setup");
      return;
    }

    // Request notification permissions
    NotificationSettings settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print("🔔 Android Permission: ${settings.authorizationStatus}");

    // Generate + Save token
    await generateAndSaveToken();

    // Listen for token refresh
    _fm.onTokenRefresh.listen((newToken) {
      print("🔄 Android FCM token refreshed: $newToken");
      saveTokenToSupabase(newToken);
    });
  }

  // ----------------------------------------------------------
  // GENERATE TOKEN
  // ----------------------------------------------------------
  static Future<void> generateAndSaveToken() async {
    if (kIsWeb) return; // handled separately for web

    try {
      String? token = await _fm.getToken();

      if (token == null) {
        print("❌ Failed to generate FCM token");
        return;
      }

      print("📱 Android FCM Token: $token");
      await saveTokenToSupabase(token);
    } catch (e) {
      print("⚠ Error generating token: $e");
    }
  }

  // ----------------------------------------------------------
  // GET TOKEN (ANDROID + WEB)
  // ----------------------------------------------------------
  static Future<String?> getToken() async {
    try {
      return await _fm.getToken();
    } catch (e) {
      print("❌ Error getting FCM token: $e");
      return null;
    }
  }

  // ----------------------------------------------------------
  // SAVE TOKEN TO SUPABASE
  // ----------------------------------------------------------
  static Future<void> saveTokenToSupabase(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final agencyId = prefs.getInt("agency_id");

      if (agencyId == null) {
        print("⚠ No agency_id found, cannot save token");
        return;
      }

      final supabase = Supabase.instance.client;

      final response = await supabase
          .from("agencies")
          .update({"fcm_token": token})
          .eq("id", agencyId);

      print("⬆ FCM token saved for agency: $agencyId");
      print("Database Response: $response");
    } catch (e) {
      print("❌ Error saving token to Supabase: $e");
    }
  }
}
