# 📋 Leads Management - Middleware Endpoints Documentation

## Overview

Leads are generated and pushed by the middleware layer from different industries (Health, Insurance, Finance, Handyman). The mobile app fetches these leads through the middleware API endpoints.

## Architecture Flow

```
Industry Sources → Middleware Layer → Database → Mobile App
     (Health,          (Node.js)      (PostgreSQL)   (Flutter)
  Insurance, Finance,
    Handyman)
```

---

## 🔌 Middleware API Endpoints

### 1. Get Leads (Filtered by Agency)

**Endpoint:** `GET /api/mobile/leads`

**Description:** Fetches leads assigned to the authenticated agency, filtered by status, date range, and industry.

**Authentication:** Required (JWT token)

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `status` | string | No | Filter by status: `new`, `contacted`, `converting`, `closed`, `rejected` |
| `industry` | string | No | Filter by industry: `Health`, `Insurance`, `Finance`, `Handyman` |
| `from_date` | ISO8601 | No | Start date filter (e.g., `2025-11-03T00:00:00Z`) |
| `to_date` | ISO8601 | No | End date filter |
| `limit` | integer | No | Maximum number of leads to return (default: 50) |
| `offset` | integer | No | Pagination offset (default: 0) |

**Request Example:**
```http
GET /api/mobile/leads?status=new&industry=Health&limit=10
Authorization: Bearer <jwt_token>
```

**Success Response (200):**
```json
{
  "leads": [
    {
      "id": 1,
      "first_name": "Sarah",
      "last_name": "Johnson",
      "phone": "(214) 555-0101",
      "email": "sarah.johnson@example.com",
      "zipcode": "75201",
      "city": "Dallas",
      "state": "TX",
      "address": "1234 Main Street, Dallas, TX 75201",
      "age": 68,
      "industry": "Health",
      "service_type": "Home Care Services",
      "status": "new",
      "urgency_level": "HIGH",
      "source": "Website Form",
      "created_at": "2025-11-03T10:00:00Z",
      "updated_at": "2025-11-03T10:00:00Z",
      "notes": "Elderly client needs daily assistance...",
      "preferred_contact_time": "Morning (9 AM - 12 PM)",
      "budget": "1500-2000",
      "timeline": "ASAP"
    }
  ],
  "total": 25,
  "page": 1,
  "limit": 10
}
```

---

### 2. Get Lead Details

**Endpoint:** `GET /api/mobile/leads/:leadId`

**Description:** Fetches detailed information about a specific lead.

**Authentication:** Required (JWT token)

**Request Example:**
```http
GET /api/mobile/leads/1
Authorization: Bearer <jwt_token>
```

**Success Response (200):**
```json
{
  "id": 1,
  "first_name": "Sarah",
  "last_name": "Johnson",
  "phone": "(214) 555-0101",
  "email": "sarah.johnson@example.com",
  "zipcode": "75201",
  "city": "Dallas",
  "state": "TX",
  "address": "1234 Main Street, Dallas, TX 75201",
  "age": 68,
  "industry": "Health",
  "service_type": "Home Care Services",
  "status": "new",
  "urgency_level": "HIGH",
  "source": "Website Form",
  "created_at": "2025-11-03T10:00:00Z",
  "updated_at": "2025-11-03T10:00:00Z",
  "notes": "Elderly client needs daily assistance with medication and meal preparation. Prefers morning visits. Has Medicare coverage.",
  "preferred_contact_time": "Morning (9 AM - 12 PM)",
  "budget": "1500-2000",
  "timeline": "ASAP",
  "agency_id": "agency_123",
  "assigned_at": "2025-11-03T10:00:00Z"
}
```

---

### 3. Update Lead Status

**Endpoint:** `PUT /api/mobile/leads/:leadId/status`

**Description:** Updates the status of a lead (e.g., new → contacted → converting → closed).

**Authentication:** Required (JWT token)

**Request Body:**
```json
{
  "status": "contacted",
  "notes": "Called client - interested in home care services"
}
```

**Request Example:**
```http
PUT /api/mobile/leads/1/status
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "status": "contacted",
  "notes": "Called client - interested in home care services"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Lead status updated successfully",
  "lead": {
    "id": 1,
    "status": "contacted",
    "updated_at": "2025-11-03T11:00:00Z"
  }
}
```

**Valid Status Values:**
- `new` - Newly assigned lead
- `contacted` - Initial contact made
- `converting` - In process of conversion
- `closed` - Successfully converted
- `rejected` - Not interested/unqualified

---

### 4. Mark Lead as Viewed

**Endpoint:** `PUT /api/mobile/leads/:leadId/view`

**Description:** Marks a lead as viewed (for tracking purposes).

**Authentication:** Required (JWT token)

**Request Example:**
```http
PUT /api/mobile/leads/1/view
Authorization: Bearer <jwt_token>
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Lead marked as viewed",
  "viewed_at": "2025-11-03T11:00:00Z"
}
```

---

### 5. Track Phone Call

**Endpoint:** `POST /api/mobile/leads/:leadId/call`

**Description:** Logs a phone call interaction with a lead.

**Authentication:** Required (JWT token)

**Request Body:**
```json
{
  "duration": 300,
  "outcome": "interested",
  "notes": "Client wants to schedule consultation"
}
```

**Request Example:**
```http
POST /api/mobile/leads/1/call
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "duration": 300,
  "outcome": "interested",
  "notes": "Client wants to schedule consultation"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Call logged successfully",
  "call": {
    "id": 1,
    "lead_id": 1,
    "duration": 300,
    "outcome": "interested",
    "created_at": "2025-11-03T11:00:00Z"
  }
}
```

---

### 6. Add Notes to Lead

**Endpoint:** `POST /api/mobile/leads/:leadId/notes`

**Description:** Adds notes to a lead.

**Authentication:** Required (JWT token)

**Request Body:**
```json
{
  "notes": "Client prefers email communication. Available weekdays only."
}
```

**Request Example:**
```http
POST /api/mobile/leads/1/notes
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "notes": "Client prefers email communication. Available weekdays only."
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Notes added successfully",
  "note": {
    "id": 1,
    "lead_id": 1,
    "notes": "Client prefers email communication...",
    "created_at": "2025-11-03T11:00:00Z"
  }
}
```

---

### 7. Accept Lead

**Endpoint:** `PUT /api/mobile/leads/:leadId/accept`

**Description:** Accepts a lead assignment (marks as accepted by agency).

**Authentication:** Required (JWT token)

**Request Example:**
```http
PUT /api/mobile/leads/1/accept
Authorization: Bearer <jwt_token>
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Lead accepted successfully",
  "lead": {
    "id": 1,
    "status": "accepted",
    "accepted_at": "2025-11-03T11:00:00Z"
  }
}
```

---

### 8. Reject Lead

**Endpoint:** `PUT /api/mobile/leads/:leadId/reject`

**Description:** Rejects a lead assignment (marks as rejected by agency).

**Authentication:** Required (JWT token)

**Request Body (Optional):**
```json
{
  "reason": "Not in service area",
  "notes": "Client is outside our coverage zipcodes"
}
```

**Request Example:**
```http
PUT /api/mobile/leads/1/reject
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "reason": "Not in service area",
  "notes": "Client is outside our coverage zipcodes"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Lead rejected successfully",
  "lead": {
    "id": 1,
    "status": "rejected",
    "rejected_at": "2025-11-03T11:00:00Z",
    "rejection_reason": "Not in service area"
  }
}
```

---

## 📊 Lead Data Model

### Complete Lead Object Structure

```typescript
interface Lead {
  // Basic Information
  id: number;
  first_name: string;
  last_name: string;
  phone: string;
  email: string;
  
  // Location
  zipcode: string;
  city: string;
  state: string;
  address?: string;
  
  // Demographics
  age?: number;
  
  // Industry Classification
  industry: 'Health' | 'Insurance' | 'Finance' | 'Handyman';
  service_type: string; // e.g., "Home Care Services", "Life Insurance Consultation"
  
  // Status & Tracking
  status: 'new' | 'contacted' | 'converting' | 'closed' | 'rejected' | 'accepted';
  urgency_level: 'LOW' | 'MODERATE' | 'HIGH' | 'URGENT';
  source: string; // e.g., "Website Form", "Referral", "Online Ad", "Phone Call"
  
  // Timestamps
  created_at: string; // ISO8601
  updated_at: string; // ISO8601
  assigned_at?: string; // ISO8601
  viewed_at?: string; // ISO8601
  accepted_at?: string; // ISO8601
  rejected_at?: string; // ISO8601
  
  // Additional Information
  notes?: string;
  preferred_contact_time?: string;
  budget?: string;
  timeline?: string;
  
  // Agency Assignment
  agency_id: string;
  
  // Rejection Info (if rejected)
  rejection_reason?: string;
}
```

---

## 🏭 Industry-Specific Leads

### Health Industry

**Typical Lead Fields:**
- `industry`: `"Health"`
- `service_type`: `"Home Care Services"`, `"Medical Equipment"`, `"Caregiver Assistance"`
- Common `urgency_level`: `HIGH` (time-sensitive care needs)
- Common `source`: `"Website Form"`, `"Referral"`, `"Phone Call"`

**Example Lead:**
```json
{
  "industry": "Health",
  "service_type": "Home Care Services",
  "urgency_level": "HIGH",
  "notes": "Elderly client needs daily assistance with medication and meal preparation.",
  "preferred_contact_time": "Morning (9 AM - 12 PM)",
  "budget": "1500-2000"
}
```

### Insurance Industry

**Typical Lead Fields:**
- `industry`: `"Insurance"`
- `service_type`: `"Life Insurance Consultation"`, `"Health Insurance"`, `"Auto Insurance"`
- Common `urgency_level`: `MODERATE` (planning ahead)
- Common `source`: `"Referral"`, `"Online Ad"`, `"Website Form"`

**Example Lead:**
```json
{
  "industry": "Insurance",
  "service_type": "Life Insurance Consultation",
  "urgency_level": "MODERATE",
  "notes": "New homeowner looking for comprehensive life insurance coverage.",
  "preferred_contact_time": "Evening (5 PM - 8 PM)",
  "budget": "100-150/month"
}
```

### Finance Industry

**Typical Lead Fields:**
- `industry`: `"Finance"`
- `service_type`: `"Investment Advisory"`, `"Financial Planning"`, `"Retirement Planning"`
- Common `urgency_level`: `LOW` (long-term planning)
- Common `source`: `"Online Ad"`, `"Referral"`, `"Website Form"`

**Example Lead:**
```json
{
  "industry": "Finance",
  "service_type": "Investment Advisory",
  "urgency_level": "LOW",
  "notes": "Looking for financial planning services. Has $50K to invest.",
  "preferred_contact_time": "Weekend",
  "budget": "Fee-based"
}
```

### Handyman Industry

**Typical Lead Fields:**
- `industry`: `"Handyman"`
- `service_type`: `"Home Repairs"`, `"Plumbing"`, `"Electrical"`, `"Renovation"`
- Common `urgency_level`: `HIGH` (immediate repairs needed)
- Common `source`: `"Phone Call"`, `"Website Form"`, `"Referral"`

**Example Lead:**
```json
{
  "industry": "Handyman",
  "service_type": "Home Repairs",
  "urgency_level": "HIGH",
  "notes": "Kitchen sink leak, needs immediate repair.",
  "preferred_contact_time": "Any time",
  "budget": "500-1000",
  "timeline": "Today"
}
```

---

## 🔄 Lead Assignment Flow

### How Leads Are Pushed to Agencies

1. **Lead Generation:**
   - Leads are generated from various sources (website forms, referrals, ads)
   - Middleware layer receives leads and stores in database

2. **Lead Assignment:**
   - Middleware assigns leads to agencies based on:
     - Agency zipcode coverage
     - Agency industry specialization
     - Agency capacity
   - Lead status set to `"new"`

3. **Lead Notification:**
   - Middleware sends push notification to agency
   - Lead appears in mobile app

4. **Agency Action:**
   - Agency views lead details
   - Agency accepts or rejects lead
   - Agency updates lead status as they progress

---

## 📱 Mobile App Integration

### Service Layer Usage

**Get Leads:**
```dart
final leads = await LeadService.getLeads(
  status: 'new',
  industry: 'Health',
  limit: 10,
);
```

**Get Lead Details:**
```dart
final lead = await LeadService.getLeadDetail(leadId: 1);
```

**Update Status:**
```dart
await LeadService.updateLeadStatus(
  leadId,
  'contacted',
  notes: 'Called client',
);
```

**Track Call:**
```dart
await LeadService.trackCall(
  leadId,
  duration: 300,
  outcome: 'interested',
);
```

---

## 🧪 Demo/Test Leads

For development and testing, the app includes dummy leads:

- **Health Lead:** Sarah Johnson (Home Care Services)
- **Insurance Lead:** Michael Chen (Life Insurance Consultation)

These leads are returned when the API is unavailable (test mode or offline).

---

## ✅ Implementation Checklist

### Middleware Layer Requirements

- [ ] Implement `GET /api/mobile/leads` endpoint
- [ ] Implement `GET /api/mobile/leads/:leadId` endpoint
- [ ] Implement `PUT /api/mobile/leads/:leadId/status` endpoint
- [ ] Implement `PUT /api/mobile/leads/:leadId/view` endpoint
- [ ] Implement `POST /api/mobile/leads/:leadId/call` endpoint
- [ ] Implement `POST /api/mobile/leads/:leadId/notes` endpoint
- [ ] Implement `PUT /api/mobile/leads/:leadId/accept` endpoint
- [ ] Implement `PUT /api/mobile/leads/:leadId/reject` endpoint
- [ ] Filter leads by agency zipcode coverage
- [ ] Filter leads by industry
- [ ] Support pagination
- [ ] Support date range filtering

### Database Requirements

- [ ] Leads table with all required fields
- [ ] Industry field (Health, Insurance, Finance, Handyman)
- [ ] Status tracking
- [ ] Agency assignment tracking
- [ ] Notes and call history tables

---

**Last Updated:** 2025-11-03  
**Status:** ✅ End-to-End Implementation Complete

