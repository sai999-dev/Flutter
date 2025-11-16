import 'package:flutter/material.dart';
import 'package:flutter_backend/services/lead_service.dart';
import 'package:flutter_backend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LeadPopupService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Show a popup when a new lead is assigned (realtime notification)
  static Future<void> show(Map<String, dynamic>? leadData) async {
    if (leadData == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Extract lead information - try multiple field names
    final rawPayload = leadData['raw_payload'] as Map<String, dynamic>? ?? {};

    // Get agency industry from lead data or user profile
    String agencyIndustry = 'General';
    try {
      // First try to get from lead's raw_payload (industry category)
      if (rawPayload['industry'] != null && rawPayload['industry'].toString().isNotEmpty) {
        agencyIndustry = rawPayload['industry'].toString();
      } else if (leadData['industry'] != null && leadData['industry'].toString().isNotEmpty) {
        agencyIndustry = leadData['industry'].toString();
      } else {
        // Fallback to user profile
        final prefs = await SharedPreferences.getInstance();
        final profileJson = prefs.getString('user_profile');
        if (profileJson != null) {
          final profile = json.decode(profileJson);
          print('📋 User profile: $profile');
          // Try multiple field names for industry
          agencyIndustry = profile['industry']?.toString() ??
                          profile['business_type']?.toString() ??
                          profile['vertical']?.toString() ??
                          profile['category']?.toString() ??
                          'General';
        }
      }
      print('🏢 Industry displayed: $agencyIndustry');
    } catch (e) {
      print('⚠️ Could not load industry: $e');
    }

    final firstName = leadData['first_name'] ?? leadData['firstName'] ?? '';
    final lastName = leadData['last_name'] ?? leadData['lastName'] ?? '';
    final fullName = leadData['full_name'] ?? leadData['fullName'] ?? '';
    final contactName = leadData['contact_name'] ?? leadData['contactName'] ?? '';
    final leadName = leadData['lead_name'] ?? '';

    // Build name with fallback logic
    String name = '';
    if (leadName.toString().isNotEmpty) {
      name = leadName.toString();
    } else if (firstName.toString().isNotEmpty || lastName.toString().isNotEmpty) {
      name = '$firstName $lastName'.trim();
    } else if (fullName.toString().isNotEmpty) {
      name = fullName.toString();
    } else if (contactName.toString().isNotEmpty) {
      name = contactName.toString();
    } else if (rawPayload['name'] != null) {
      name = rawPayload['name'].toString();
    } else {
      name = leadData['name']?.toString() ?? 'Lead Contact';
    }

    final serviceType = leadData['service_type'] ?? leadData['serviceType'] ?? rawPayload['needs'] ?? '';
    final phone = leadData['phone_number'] ?? leadData['phone'] ?? rawPayload['phone'] ?? '';
    final email = leadData['email'] ?? rawPayload['email'] ?? '';
    final city = rawPayload['city'] ?? leadData['city'] ?? '';
    final state = rawPayload['state'] ?? leadData['state'] ?? '';
    final zipcode = rawPayload['zipcode'] ?? leadData['zipcode'] ?? leadData['zip'] ?? '';
    final address = leadData['address'] ?? rawPayload['address'] ?? leadData['street'] ?? '';
    final urgency = leadData['urgency_level'] ?? leadData['urgency'] ?? 'MODERATE';
    final notes = leadData['notes'] ?? leadData['description'] ?? leadData['additional_details'] ?? rawPayload['additional_details'] ?? '';
    final budget = leadData['budget_range'] ?? leadData['budget'] ?? rawPayload['budget_range'] ?? '';
    final propertyType = leadData['property_type'] ?? rawPayload['property_type'] ?? '';
    final timeline = leadData['timeline'] ?? rawPayload['timeline'] ?? '';
    final leadId = leadData['id'];

    // Industry color coding based on AGENCY industry
    Color industryColor;
    IconData industryIcon;
    switch (agencyIndustry.toUpperCase()) {
      case 'HEALTH':
      case 'HEALTHCARE':
        industryColor = const Color(0xFF10B981);
        industryIcon = Icons.medical_services;
        break;
      case 'INSURANCE':
        industryColor = const Color(0xFF3B82F6);
        industryIcon = Icons.shield;
        break;
      case 'FINANCE':
      case 'FINANCIAL':
        industryColor = const Color(0xFFF59E0B);
        industryIcon = Icons.account_balance;
        break;
      case 'HANDYMAN':
        industryColor = const Color(0xFF8B5CF6);
        industryIcon = Icons.build;
        break;
      default:
        industryColor = const Color(0xFF64748B);
        industryIcon = Icons.business;
    }

    // Urgency color
    Color urgencyColor;
    if (urgency == 'URGENT' || urgency == 'HIGH') {
      urgencyColor = const Color(0xFFEF4444);
    } else if (urgency == 'MODERATE' || urgency == 'MEDIUM') {
      urgencyColor = const Color(0xFFF59E0B);
    } else {
      urgencyColor = const Color(0xFF10B981);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: industryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(industryIcon, color: industryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New Lead Available',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(agencyIndustry,
                        style: TextStyle(fontSize: 12, color: industryColor)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  urgency == 'HIGH'
                      ? 'HIGH'
                      : urgency == 'MODERATE'
                          ? 'MED'
                          : 'LOW',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: urgencyColor),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lead Name
                      Text(name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A))),

                      // Agency Industry (under name)
                      const SizedBox(height: 2),
                      Text(agencyIndustry,
                          style: TextStyle(
                              fontSize: 12,
                              color: industryColor,
                              fontWeight: FontWeight.w600)),

                      // Service Type
                      if (serviceType.toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.work_outline,
                                size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(serviceType.toString(),
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF64748B))),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Phone
                      if (phone.toString().isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.phone,
                                size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(phone.toString(),
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Email
                      if (email.toString().isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.email,
                                size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(email.toString(),
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Location (City, State, Zipcode)
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                                [
                                  if (city.toString().isNotEmpty) city.toString(),
                                  if (state.toString().isNotEmpty) state.toString(),
                                  if (zipcode.toString().isNotEmpty) zipcode.toString(),
                                ].where((s) => s.isNotEmpty).join(', '),
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B))),
                          ),
                        ],
                      ),

                      // Address
                      if (address.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.home,
                                size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(address.toString(),
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF64748B)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],

                      // Property Type
                      if (propertyType.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.apartment,
                                size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text('Type: ${propertyType.toString()}',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],

                      // Budget
                      if (budget.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.attach_money,
                                size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text('Budget: ${budget.toString()}',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],

                      // Timeline
                      if (timeline.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.schedule,
                                size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text('Timeline: ${timeline.toString()}',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],

                      // Notes
                      if (notes.toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Notes:',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              Text(notes.toString(),
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF64748B)),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            Row(
              children: [
                // Not Interested Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _handleNotInterested(context, leadId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 18),
                        SizedBox(width: 6),
                        Text('Not Interested',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Communicate Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _handleCommunicate(context, leadData);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00888C),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.message, size: 18),
                        SizedBox(width: 6),
                        Text('Communicate',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    print('✅ Lead popup shown for: $name');
  }

  /// Handle "Not Interested" action
  static Future<void> _handleNotInterested(BuildContext context, int? leadId) async {
    if (leadId == null) return;

    try {
      print('🚫 Sending "Not Interested" API call for lead: $leadId');

      final success = await LeadService.markNotInterested(
        leadId,
        reason: 'Not interested',
        notes: 'Marked as not interested by mobile user - Portal admin can reassign',
      );

      if (success) {
        print('✅ API call successful - Lead marked as not interested');
        await LeadService.clearCache();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Lead removed. Portal admin will reassign it.'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('❌ API call failed - Lead status not updated');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Failed to update lead status. Please try again.'),
              backgroundColor: Color(0xFFF59E0B),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error marking lead as not interested: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Handle "Communicate" action
  static Future<void> _handleCommunicate(BuildContext context, Map<String, dynamic> lead) async {
    final leadId = lead['id'];
    if (leadId != null) {
      try {
        print('📞 Communicating with lead: $leadId');

        // Update lead status to contacted
        await LeadService.updateLeadStatus(leadId, 'contacted',
            notes: 'User chose to communicate via realtime notification');
        await LeadService.markAsViewed(leadId);

        // Clear cache to ensure fresh data
        await LeadService.clearCache();

        print('✅ Lead marked as contacted and saved: $leadId');

        if (context.mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Lead saved successfully! Check your dashboard.'),
                backgroundColor: Color(0xFF10B981),
                duration: Duration(seconds: 3)),
          );
        }
      } catch (e) {
        print('❌ Error updating lead status: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('❌ Error: $e'),
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 3)),
          );
        }
      }
    }
  }
}
