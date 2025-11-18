import 'package:supabase_flutter/supabase_flutter.dart';

/// Audit Logs Service
/// Fetches lead information from audit_logs table for dashboard display
class AuditLogsService {
  static final _supabase = Supabase.instance.client;

  /// Get communicated leads from audit_logs for the logged-in agency
  /// Returns leads that have been marked as 'contacted' via the communicate button
  static Future<List<Map<String, dynamic>>> getCommunicatedLeads(
    String agencyId,
  ) async {
    try {
      print('📊 Fetching communicated leads from audit_logs for agency: $agencyId');

      // Query audit_logs table for leads that have been communicated with
      final response = await _supabase
          .from('audit_logs')
          .select('*')
          .eq('agency_id', agencyId)
          .or('action_status.eq.assigned,action_status.eq.contacted')
          .order('created_at', ascending: false)
          .limit(50);

      if (response == null || response.isEmpty) {
        print('📊 No communicated leads found');
        return [];
      }

      // Transform audit_logs data to lead format
      final leads = <Map<String, dynamic>>[];
      for (var log in response) {
        final leadData = log['lead_data'] as Map<String, dynamic>?;
        if (leadData != null) {
          // Extract lead information from lead_data field
          final lead = {
            'id': log['lead_id'] ?? leadData['id'],
            'first_name': leadData['first_name'] ??
                leadData['firstName'] ??
                leadData['lead_name'] ??
                leadData['name'] ??
                'Unknown',
            'last_name': leadData['last_name'] ?? leadData['lastName'] ?? '',
            'phone': leadData['phone_number'] ?? leadData['phone'] ?? '',
            'email': leadData['email'] ?? '',
            'city': leadData['city'] ?? '',
            'zipcode': leadData['zipcode'] ?? leadData['zip'] ?? '',
            'state': leadData['state'] ?? '',
            'address': leadData['address'] ?? leadData['street'] ?? '',
            'urgency_level': leadData['urgency_level'] ?? leadData['urgency'] ?? 'MODERATE',
            'notes': leadData['notes'] ?? leadData['description'] ?? '',
            'service_type': leadData['service_type'] ?? leadData['serviceType'] ?? '',
            'industry': leadData['industry'] ?? log['industry'] ?? '',
            'status': log['action_status'] ?? 'assigned',
            'created_at': log['created_at'],
            'updated_at': log['updated_at'],
            // Additional fields from raw_payload
            'budget_range': leadData['budget_range'] ?? leadData['budget'] ?? '',
            'property_type': leadData['property_type'] ?? '',
            'timeline': leadData['timeline'] ?? '',
          };
          leads.add(lead);
        }
      }

      print('✅ Found ${leads.length} communicated leads from audit_logs');
      return leads;
    } catch (e) {
      print('❌ Error fetching communicated leads from audit_logs: $e');
      return [];
    }
  }

  /// Mark a lead as communicated in audit_logs
  /// This is called when the communicate button is clicked
  static Future<bool> markAsCommunicated(
    String agencyId,
    int leadId,
    Map<String, dynamic> leadData,
  ) async {
    try {
      print('📝 Marking lead $leadId as communicated in audit_logs');

      // Update existing audit log entry for this lead
      final existingLogs = await _supabase
          .from('audit_logs')
          .select()
          .eq('agency_id', agencyId)
          .eq('lead_id', leadId);

      if (existingLogs.isNotEmpty) {
        // Update existing entry
        await _supabase
            .from('audit_logs')
            .update({
              'action_status': 'contacted',
              'lead_data': leadData,
            })
            .eq('agency_id', agencyId)
            .eq('lead_id', leadId);
      }

      print('✅ Lead marked as communicated in audit_logs');
      return true;
    } catch (e) {
      print('❌ Error marking lead as communicated in audit_logs: $e');
      return false;
    }
  }

  /// Get all leads assigned to an agency from audit_logs
  /// This includes both assigned and contacted leads
  static Future<List<Map<String, dynamic>>> getAssignedLeads(
    String agencyId,
  ) async {
    try {
      print('📊 Fetching all assigned leads from audit_logs for agency: $agencyId');

      final response = await _supabase
          .from('audit_logs')
          .select('*')
          .eq('agency_id', agencyId)
          .order('created_at', ascending: false);

      if (response == null || response.isEmpty) {
        print('📊 No assigned leads found');
        return [];
      }

      final leads = <Map<String, dynamic>>[];
      for (var log in response) {
        final leadData = log['lead_data'] as Map<String, dynamic>?;
        if (leadData != null) {
          final lead = {
            'id': log['lead_id'] ?? leadData['id'],
            'first_name': leadData['first_name'] ??
                leadData['firstName'] ??
                leadData['lead_name'] ??
                leadData['name'] ??
                'Unknown',
            'last_name': leadData['last_name'] ?? leadData['lastName'] ?? '',
            'phone': leadData['phone_number'] ?? leadData['phone'] ?? '',
            'email': leadData['email'] ?? '',
            'city': leadData['city'] ?? '',
            'zipcode': leadData['zipcode'] ?? leadData['zip'] ?? '',
            'state': leadData['state'] ?? '',
            'address': leadData['address'] ?? leadData['street'] ?? '',
            'urgency_level': leadData['urgency_level'] ?? leadData['urgency'] ?? 'MODERATE',
            'notes': leadData['notes'] ?? leadData['description'] ?? '',
            'service_type': leadData['service_type'] ?? leadData['serviceType'] ?? '',
            'industry': leadData['industry'] ?? log['industry'] ?? '',
            'status': log['action_status'] ?? 'assigned',
            'created_at': log['created_at'],
            'updated_at': log['updated_at'],
            'budget_range': leadData['budget_range'] ?? leadData['budget'] ?? '',
            'property_type': leadData['property_type'] ?? '',
            'timeline': leadData['timeline'] ?? '',
          };
          leads.add(lead);
        }
      }

      print('✅ Found ${leads.length} assigned leads from audit_logs');
      return leads;
    } catch (e) {
      print('❌ Error fetching assigned leads from audit_logs: $e');
      return [];
    }
  }
}
