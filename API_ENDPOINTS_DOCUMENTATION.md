# 📡 Mobile App API Endpoints Documentation

## Architecture Overview

The Flutter mobile app communicates with a **Node.js middleware layer** (separate repository) that exposes all endpoints under `/api/mobile/*`. The architecture follows a **service-oriented pattern** where all API calls are made through centralized service classes.

### Base URL Configuration

**Development:** Auto-detects from multiple ports:
- `http://127.0.0.1:3002`
- `http://localhost:3002`
- `http://127.0.0.1:3001`
- `http://localhost:3001`
- `http://127.0.0.1:3000`
- `http://localhost:3000`

**Production:** Set in `flutter-backend/lib/services/api_client.dart`:
```dart
static const String? productionApiUrl = 'https://your-api-domain.com';
```

### Health Check Endpoint

**Endpoint:** `GET /api/health`  
**Purpose:** Auto-detection of working backend server  
**Auth Required:** No  
**Service:** `ApiClient._findWorkingBaseUrl()`

---

## 📋 Complete API Endpoints List

### 🔐 Authentication Endpoints (`/api/mobile/auth/*`)

| Method | Endpoint | Auth Required | Service | Description |
|--------|----------|---------------|---------|-------------|
| `POST` | `/api/mobile/auth/register` | ❌ | `AuthService.register()` | Register new agency account |
| `POST` | `/api/mobile/auth/verify-email` | ❌ | `AuthService.verifyEmail()` | Verify email address with code |
| `POST` | `/api/mobile/auth/login` | ❌ | `AuthService.login()` | Login with email/password |
| `POST` | `/api/mobile/auth/forgot-password` | ❌ | `AuthService.forgotPassword()` | Request password reset |
| `POST` | `/api/mobile/auth/register-device` | ✅ | `AuthService.registerDevice()` | Register device for push notifications |
| `PUT` | `/api/mobile/auth/update-device` | ✅ | `AuthService.updateDevice()` | Update device token |
| `DELETE` | `/api/mobile/auth/unregister-device` | ✅ | `AuthService.unregisterDevice()` | Unregister device on logout |

**Request Body Examples:**

**Register:**
```json
{
  "email": "agency@example.com",
  "password": "SecurePass123",
  "agency_name": "ABC Healthcare",
  "phone": "+1234567890",
  "business_name": "ABC Healthcare",
  "contact_name": "John Doe",
  "zipcodes": ["75201", "75033"],
  "industry": "Healthcare",
  "plan_id": "plan_123"
}
```

**Login:**
```json
{
  "email": "agency@example.com",
  "password": "SecurePass123"
}
```

---

### 📊 Leads Endpoints (`/api/mobile/leads/*`)

| Method | Endpoint | Auth Required | Service | Description |
|--------|----------|---------------|---------|-------------|
| `GET` | `/api/mobile/leads` | ✅ | `LeadService.getLeads()` | Get agency's assigned leads (with filters) |
| `GET` | `/api/mobile/leads/:leadId` | ✅ | `LeadService.getLeadDetail()` | Get detailed lead information |
| `PUT` | `/api/mobile/leads/:leadId/status` | ✅ | `LeadService.updateLeadStatus()` | Update lead status |
| `PUT` | `/api/mobile/leads/:leadId/view` | ✅ | `LeadService.markAsViewed()` | Mark lead as viewed |
| `POST` | `/api/mobile/leads/:leadId/call` | ✅ | `LeadService.trackCall()` | Track phone call to lead |
| `POST` | `/api/mobile/leads/:leadId/notes` | ✅ | `LeadService.addNotes()` | Add notes to lead |
| `PUT` | `/api/mobile/leads/:leadId/accept` | ✅ | `LeadService.acceptLead()` | Accept a lead |
| `PUT` | `/api/mobile/leads/:leadId/reject` | ✅ | `LeadService.rejectLead()` | Reject a lead |

**Query Parameters for GET /api/mobile/leads:**
- `status` - Filter by status (e.g., "new", "accepted", "rejected")
- `from_date` - ISO8601 date string
- `to_date` - ISO8601 date string
- `limit` - Number of results to return

**Example:**
```
GET /api/mobile/leads?status=new&from_date=2025-01-01T00:00:00Z&limit=50
```

**Request Body Examples:**

**Update Status:**
```json
{
  "status": "accepted",
  "notes": "Interested in services"
}
```

**Accept Lead:**
```json
{
  "notes": "Will contact tomorrow"
}
```

**Reject Lead:**
```json
{
  "reason": "Not in service area"
}
```

---

### 💳 Subscription Endpoints (`/api/mobile/subscription/*`)

| Method | Endpoint | Auth Required | Service | Description |
|--------|----------|---------------|---------|-------------|
| `GET` | `/api/mobile/subscription/plans` | ❌ | `SubscriptionService.getPlans()` | Get all available subscription plans from Super Admin Portal |
| `GET` | `/api/mobile/subscription` | ✅ | `SubscriptionService.getSubscription()` | Get current agency subscription |
| `POST` | `/api/mobile/subscription/subscribe` | ✅ | `SubscriptionService.subscribe()` | Subscribe to a plan |
| `PUT` | `/api/mobile/subscription/upgrade` | ✅ | `SubscriptionService.upgrade()` | Upgrade to higher plan |
| `PUT` | `/api/mobile/subscription/downgrade` | ✅ | `SubscriptionService.downgrade()` | Downgrade to lower plan |
| `POST` | `/api/mobile/subscription/cancel` | ✅ | `SubscriptionService.cancel()` | Cancel subscription |
| `GET` | `/api/mobile/subscription/invoices` | ✅ | `SubscriptionService.getInvoices()` | Get billing invoices |
| `PUT` | `/api/mobile/payment-method` | ✅ | `SubscriptionService.updatePaymentMethod()` | Update payment method |

**Query Parameters:**

**GET /api/mobile/subscription/plans:**
- `isActive=true` - Filter active plans only

**GET /api/mobile/subscription/invoices:**
- `page` - Page number
- `limit` - Results per page

**Request Body Examples:**

**Subscribe:**
```json
{
  "plan_id": "plan_123",
  "payment_method_id": "pm_123"
}
```

**Upgrade:**
```json
{
  "plan_id": "plan_456",
  "prorated": true
}
```

**Cancel:**
```json
{
  "reason": "Switching to competitor",
  "immediate": false
}
```

---

### 🗺️ Territory/Zipcode Endpoints (`/api/mobile/territories`)

| Method | Endpoint | Auth Required | Service | Description |
|--------|----------|---------------|---------|-------------|
| `GET` | `/api/mobile/territories` | ✅ | `TerritoryService.getZipcodes()` | Get agency's selected zipcodes |
| `POST` | `/api/mobile/territories` | ✅ | `TerritoryService.addZipcode()` | Add new zipcode territory |
| `PUT` | `/api/mobile/territories/:id` | ✅ | `TerritoryService.updateTerritory()` | Update existing territory |
| `DELETE` | `/api/mobile/territories/:id` | ✅ | `TerritoryService.removeTerritory()` | Remove territory by ID |
| `DELETE` | `/api/mobile/territories/:zipcode` | ✅ | `TerritoryService.removeZipcode()` | Remove territory by zipcode (deprecated) |

**Request Body Examples:**

**Add Zipcode:**
```json
{
  "zipcode": "75201",
  "city": "Dallas, TX"
}
```

**Update Territory:**
```json
{
  "zipcode": "75201",
  "city": "Dallas, Texas",
  "additionalData": {}
}
```

**Response Format (GET):**
```json
{
  "zipcodes": ["75201", "75033", "75001"]
}
```

---

### 📄 Document Verification Endpoints (`/api/mobile/auth/*`)

| Method | Endpoint | Auth Required | Service | Description |
|--------|----------|---------------|---------|-------------|
| `POST` | `/api/mobile/auth/upload-document` | ✅ | `DocumentVerificationService.uploadDocument()` | Upload verification document (multipart) |
| `GET` | `/api/mobile/auth/verification-status` | ✅ | `DocumentVerificationService.getVerificationStatus()` | Get document verification status |
| `GET` | `/api/mobile/auth/documents` | ✅ | `DocumentVerificationService.getDocuments()` | Get uploaded documents list |

**Request Format (Upload):**
- Content-Type: `multipart/form-data`
- Fields:
  - `file` - Document file (PDF, image, etc.)
  - `document_type` - Type of document
  - `agency_id` - Agency ID

**Response Format (Status):**
```json
{
  "status": "pending|approved|rejected",
  "message": "Status message",
  "documents": []
}
```

---

### 🔔 Notification Endpoints (`/api/mobile/notifications/*`)

| Method | Endpoint | Auth Required | Service | Description |
|--------|----------|---------------|---------|-------------|
| `GET` | `/api/mobile/notifications/settings` | ✅ | `NotificationService.getSettings()` | Get notification preferences |
| `PUT` | `/api/mobile/notifications/settings` | ✅ | `NotificationService.updateSettings()` | Update notification preferences |

**Request Body Example:**
```json
{
  "email_notifications": true,
  "push_notifications": true,
  "sms_notifications": false,
  "lead_notifications": true,
  "subscription_notifications": true
}
```

---

## 🔧 Architecture Compliance

### ✅ Correct Implementation Pattern

All API calls should go through service classes:

```dart
// ✅ CORRECT - Use service
final plans = await SubscriptionService.getPlans();

// ✅ CORRECT - Use service
final response = await AuthService.register(
  email: email,
  password: password,
  agencyName: name,
);

// ❌ WRONG - Direct API call
final response = await ApiClient.post('/api/v1/agencies/register', data);
```

### 🔍 Fixed Issues

1. **Registration Endpoint Mismatch:**
   - **Before:** Direct call to `/api/v1/agencies/register` in `main.dart`
   - **After:** Uses `AuthService.register()` which calls `/api/mobile/auth/register`
   - **Status:** ✅ Fixed

### 📝 Service Layer Structure

```
flutter-backend/lib/services/
├── api_client.dart              # Base HTTP client & JWT management
├── auth_service.dart            # Authentication endpoints
├── lead_service.dart            # Lead management endpoints
├── subscription_service.dart    # Subscription endpoints
├── territory_service.dart       # Zipcode/territory endpoints
├── document_verification_service.dart  # Document upload endpoints
└── notification_service.dart    # Notification settings endpoints
```

---

## 🚨 Common Issues & Solutions

### Issue 1: Endpoint Not Found (404)
**Cause:** Backend server not running or wrong endpoint path  
**Solution:** 
1. Verify backend server is running on port 3000, 3001, or 3002
2. Check endpoint path matches exactly (case-sensitive)
3. Ensure endpoint exists in backend middleware layer

### Issue 2: Authentication Required (401)
**Cause:** JWT token missing or expired  
**Solution:**
1. Ensure user is logged in
2. Check `ApiClient.isAuthenticated` returns true
3. Verify token is saved in secure storage
4. Re-login if token expired

### Issue 3: Wrong Endpoint Path
**Cause:** Using old `/api/v1/*` instead of `/api/mobile/*`  
**Solution:** Always use service classes, never call endpoints directly

### Issue 4: CORS Errors
**Cause:** Backend CORS configuration  
**Solution:** Ensure backend allows requests from mobile app origin

---

## 📊 Endpoint Summary Statistics

- **Total Endpoints:** 29
- **Authentication Required:** 24 (83%)
- **Public Endpoints:** 5 (17%)
- **Service Classes:** 7
- **Health Check Endpoints:** 1

### By Category:
- **Authentication:** 8 endpoints
- **Leads:** 8 endpoints
- **Subscriptions:** 8 endpoints
- **Territories:** 5 endpoints
- **Documents:** 3 endpoints
- **Notifications:** 2 endpoints

---

## 🔐 Authentication Flow

1. **Registration:** `POST /api/mobile/auth/register` → Returns JWT token
2. **Login:** `POST /api/mobile/auth/login` → Returns JWT token
3. **Token Storage:** Saved to secure storage via `ApiClient.saveToken()`
4. **Subsequent Requests:** Token sent in `Authorization: Bearer <token>` header
5. **Logout:** `DELETE /api/mobile/auth/unregister-device` → Clear token

Note: Registration does not require prior agency document verification. After registration, the app prompts the user to upload a business validity document. Admin will verify; leads start after approval.

---

## 📝 Notes for Backend Developers

1. All endpoints should return JSON responses
2. Error responses should follow format:
   ```json
   {
     "error": "Error message",
     "message": "Detailed message",
     "statusCode": 400
   }
   ```
3. Success responses should include relevant data
4. JWT tokens should be validated on all protected endpoints
5. CORS must be configured for mobile app origins
6. Health check endpoint (`/api/health`) should return 200 OK

---

## ✅ Verification Checklist

- [x] All endpoints use `/api/mobile/*` prefix
- [x] All API calls go through service classes
- [x] No direct `ApiClient` calls from UI layer
- [x] JWT authentication implemented correctly
- [x] Health check endpoint configured
- [x] Production URL configuration available
- [x] Error handling implemented
- [x] Response caching where appropriate

---

**Last Updated:** 2025-11-03  
**Version:** 1.0.0  
**Architecture:** Service-Oriented with Middleware Layer

