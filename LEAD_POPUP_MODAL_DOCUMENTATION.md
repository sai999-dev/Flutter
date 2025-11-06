# 🎯 Lead Popup Modal - Implementation Documentation

## Overview

The lead popup modal appears automatically when the mobile app opens, showing new/unviewed leads to the user. Users can choose to "Communicate" or mark as "Not Interested", allowing the portal admin to identify and reassign leads accordingly.

---

## 🔄 Flow Architecture

```
App Opens → Check for New Leads → Show Popup → User Action
                                              ↓
                                    ┌─────────┴─────────┐
                                    ↓                   ↓
                            Communicate          Not Interested
                                    ↓                   ↓
                            Mark as Contacted    Mark as Rejected
                                    ↓                   ↓
                            Navigate to Leads    Portal Admin Reassigns
```

---

## 📱 Popup Modal Features

### When It Appears

- **On App Launch:** Checks for new/unviewed leads when `HomePage` initializes
- **Automatic:** No manual trigger needed
- **Filtered:** Only shows leads matching user's zipcode coverage
- **Unviewed Only:** Only shows leads that haven't been viewed yet

### What It Shows

1. **Lead Information:**
   - Full name (first + last)
   - Industry badge with icon and color
   - Service type
   - Phone number
   - Location (city, zipcode)
   - Notes (truncated if long)
   - Urgency level badge

2. **Additional Info:**
   - Shows count of remaining leads waiting
   - Industry-specific color coding

### User Actions

#### 1. "Communicate" Button
- **Action:** Marks lead as "contacted"
- **API Call:** `PUT /api/mobile/leads/:leadId/status` with status: "contacted"
- **Also:** Marks lead as viewed
- **Navigation:** Switches to Leads tab (index 0)
- **Next:** Shows next lead popup if available (after 2 seconds)

#### 2. "Not Interested" Button
- **Action:** Marks lead as "rejected" with reason "Not interested"
- **API Call:** `PUT /api/mobile/leads/:leadId/reject` with:
  - `status: "rejected"`
  - `reason: "Not interested"`
  - `notes: "Marked as not interested by mobile user"`
- **Portal Admin:** Can identify these leads and reassign to other users
- **Next:** Shows next lead popup if available (after 0.5 seconds)

---

## 🔌 Middleware Endpoint Integration

### Endpoint: Mark Lead as Not Interested

**PUT `/api/mobile/leads/:leadId/reject`**

**Request Body:**
```json
{
  "status": "rejected",
  "reason": "Not interested",
  "notes": "Marked as not interested by mobile user"
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Lead rejected successfully",
  "lead": {
    "id": 1,
    "status": "rejected",
    "rejected_at": "2025-11-03T12:00:00Z",
    "rejection_reason": "Not interested"
  }
}
```

**Purpose:** 
- Portal admin can query for leads with `status: "rejected"` and `reason: "Not interested"`
- These leads can be reassigned to other agencies
- Portal admin dashboard can show list of rejected leads for reassignment

---

## 💻 Implementation Details

### Lead Check Logic

```dart
Future<void> _checkForNewLeads() async {
  // 1. Get new leads (status: 'new')
  final leads = await LeadService.getLeads(status: 'new', limit: 10);
  
  // 2. Filter by user's zipcodes
  final filteredLeads = leads.where((lead) {
    return userZipcodes.contains(lead['zipcode']);
  }).toList();

  // 3. Find unviewed leads (viewed_at is null)
  final unviewedLeads = filteredLeads.where((lead) {
    return lead['viewed_at'] == null;
  }).toList();

  // 4. Show popup for first unviewed lead
  if (unviewedLeads.isNotEmpty) {
    await _showLeadPopupModal(unviewedLeads[0], unviewedLeads.sublist(1));
  }
}
```

### Popup Modal Structure

```dart
AlertDialog(
  barrierDismissible: false,  // Cannot dismiss by tapping outside
  title: Row([
    Industry Icon + Color,
    "New Lead Available" + Industry name,
    Urgency Badge
  ]),
  content: [
    Lead Info Card (name, service, phone, location, notes),
    Remaining Leads Count (if any)
  ],
  actions: [
    "Not Interested" Button (red),
    "Communicate" Button (teal)
  ]
)
```

### Action Handlers

#### Not Interested Handler

```dart
Future<void> _handleNotInterested(int? leadId, remainingLeads) async {
  // 1. Call API to mark as not interested
  await LeadService.markNotInterested(
    leadId,
    reason: 'Not interested',
    notes: 'Marked as not interested by mobile user'
  );
  
  // 2. Show success message
  // 3. Show next lead if available
}
```

#### Communicate Handler

```dart
Future<void> _handleCommunicate(lead, remainingLeads) async {
  // 1. Mark as contacted
  await LeadService.updateLeadStatus(leadId, 'contacted');
  
  // 2. Mark as viewed
  await LeadService.markAsViewed(leadId);
  
  // 3. Navigate to Leads tab
  setState(() => _currentIndex = 0);
  
  // 4. Show next lead if available (after delay)
}
```

---

## 🎨 UI Design

### Industry Color Coding

| Industry | Color | Icon |
|----------|-------|------|
| Health | Green (#10B981) | medical_services |
| Insurance | Blue (#3B82F6) | shield |
| Finance | Orange (#F59E0B) | account_balance |
| Handyman | Purple (#8B5CF6) | build |

### Urgency Badges

- **HIGH/URGENT:** Red (#EF4444)
- **MODERATE/MEDIUM:** Orange (#F59E0B)
- **LOW:** Green (#10B981)

### Modal Styling

- **Rounded corners:** 20px radius
- **Cannot dismiss:** `barrierDismissible: false`
- **Back button disabled:** `WillPopScope` returns `false`
- **Compact design:** Optimized for mobile screens
- **Scrollable content:** Handles long notes

---

## 🔄 Portal Admin Workflow

### Identifying Not Interested Leads

**Query in Portal Admin:**
```sql
SELECT * FROM leads 
WHERE status = 'rejected' 
  AND rejection_reason = 'Not interested'
  AND rejected_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
ORDER BY rejected_at DESC;
```

**Portal Admin Actions:**
1. View list of rejected leads
2. See rejection reason: "Not interested"
3. See notes: "Marked as not interested by mobile user"
4. Reassign to different agency
5. Update lead status back to "new" for new agency

---

## 📊 Lead Status Flow

```
new (assigned by portal)
  ↓
[Popup appears]
  ↓
User chooses:
  ├─→ Communicate → contacted → converting → closed
  └─→ Not Interested → rejected (portal admin reassigns)
```

---

## ✅ Implementation Checklist

### Mobile App
- [x] Check for new leads on app open
- [x] Filter by user zipcodes
- [x] Filter by unviewed leads
- [x] Show popup modal
- [x] "Communicate" button handler
- [x] "Not Interested" button handler
- [x] Show next lead if available
- [x] Industry color coding
- [x] Urgency badges
- [x] Complete lead information display

### Middleware Layer
- [ ] Implement `PUT /api/mobile/leads/:leadId/reject` endpoint
- [ ] Accept `status`, `reason`, and `notes` in request body
- [ ] Update lead status to "rejected"
- [ ] Store rejection reason and notes
- [ ] Return success response with updated lead data

### Portal Admin
- [ ] Query endpoint for rejected leads
- [ ] Filter by `status: "rejected"` and `reason: "Not interested"`
- [ ] Display list of rejected leads
- [ ] Reassign functionality
- [ ] Update lead status back to "new" when reassigned

---

## 🧪 Testing

### Test Scenarios

1. **App Opens with New Lead:**
   - ✅ Popup appears automatically
   - ✅ Shows complete lead information
   - ✅ "Communicate" button works
   - ✅ "Not Interested" button works

2. **Multiple Leads:**
   - ✅ Shows first lead
   - ✅ After action, shows next lead
   - ✅ Shows count of remaining leads

3. **No New Leads:**
   - ✅ No popup appears
   - ✅ App opens normally

4. **Not Interested Action:**
   - ✅ API call made to `/api/mobile/leads/:id/reject`
   - ✅ Lead marked as rejected
   - ✅ Portal admin can see rejected lead

5. **Communicate Action:**
   - ✅ Lead marked as contacted
   - ✅ Lead marked as viewed
   - ✅ Navigates to Leads tab

---

## 📝 Code Locations

### Mobile App
- **Lead Check:** `_HomePageState._checkForNewLeads()`
- **Popup Modal:** `_HomePageState._showLeadPopupModal()`
- **Not Interested Handler:** `_HomePageState._handleNotInterested()`
- **Communicate Handler:** `_HomePageState._handleCommunicate()`

### Backend Service
- **Mark Not Interested:** `LeadService.markNotInterested()`
- **Update Status:** `LeadService.updateLeadStatus()`
- **Mark Viewed:** `LeadService.markAsViewed()`

---

## 🚀 Benefits

1. **Immediate Lead Visibility:** Users see new leads immediately
2. **Quick Decision Making:** Easy "Communicate" or "Not Interested" choice
3. **Portal Admin Efficiency:** Can quickly identify and reassign rejected leads
4. **Better Lead Distribution:** Leads not matched to one agency can go to others
5. **User Experience:** Clear, actionable interface

---

**Last Updated:** 2025-11-03  
**Status:** ✅ Lead Popup Modal Implemented

