import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/lead_popup_service.dart';  // Adjust path if needed

class RealtimeLeadListener {
  static RealtimeChannel? _channel;

  /// Call this AFTER the agency logs in
  static void startListening(String agencyId) {
    print("🔔 Starting realtime listener for agency: $agencyId");

    final supabase = Supabase.instance.client;

    // If already subscribed, remove old one
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }

    _channel = supabase.channel('audit_logs_changes').on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: 'INSERT',
        schema: 'public',
        table: 'audit_logs',
      ),
      (payload, [ref]) {
        final newRow = payload['new'];
        if (newRow == null) return;

        final logAgencyId = newRow['agency_id']?.toString() ?? '';
        final action = newRow['action_status']?.toString() ?? '';

        print("🔍 New audit log row: $newRow");

        // Check if this is for this agency
        if (logAgencyId == agencyId && action == 'assigned') {
          final leadData = newRow['lead_data'];
          print("🎉 New lead received for this agency!");
          LeadPopupService.show(leadData); // Show popup
        }
      },
    );
    _channel!.subscribe();

    print("✅ Realtime audit log listener activated.");
  }

  /// Call this on logout
  static void stopListening() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
      print("🛑 Realtime listener stopped.");
    }
  }
}
