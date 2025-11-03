# Mobile App API Endpoints Documentation

This document outlines all **28 mobile API endpoints** implemented in the Flutter mobile app, which connect to the backend API middleware layer (separate repository).

> **Note**: Originally documented 18 endpoints. After comprehensive codebase analysis, **10 additional endpoints** were identified that are critical for full app functionality.

## Architecture

- **Database**: PostgreSQL (Single Source of Truth)
- **Backend API**: Middleware Layer (Separate Repository) - Exposes REST APIs
- **Mobile App**: Flutter (iOS/Android) - Consumes `/api/mobile/*` endpoints
- **Authentication**: JWT Token-based

## API Base URL

The mobile app connects to the backend API middleware layer. Base URLs are configured in `lib/core/services/api_client.dart`:

- Development: `http://localhost:3002` (or `http://127.0.0.1:3002`)
- Fallback: `http://localhost:3001`, `http://localhost:3000`

All endpoints are prefixed with `/api/mobile/`

---

## 1. Registration & Onboarding (3 Endpoints)

### 1.1. Register Agency
**POST** `/api/mobile/auth/register`

Register a new agency account.

**Request Body:**
```json
{
  "email": "agency@example.com",
  "password": "securepassword",
  "agency_name": "Agency Name",
  "phone": "+1234567890" // optional
}
```

**Service**: `AuthService.register()`

**Response:** 
```json
{
  "success": true,
  "message": "Registration successful",
  "data": { ... }
}
```

---

### 1.2. Verify Email
**POST** `/api/mobile/auth/verify-email`

Verify agency email address with verification code.

**Request Body:**
```json
{
  "email": "agency@example.com",
  "verification_code": "123456"
}
```

**Service**: `AuthService.verifyEmail()`

**Response:**
```json
{
  "success": true,
  "token": "jwt_token_here",
  "message": "Email verified"
}
```

---

### 1.3. Login
**POST** `/api/mobile/auth/login`

Authenticate agency user and receive JWT token.

**Request Body:**
```json
{
  "email": "agency@example.com",
  "password": "securepassword"
}
```

**Service**: `AuthService.login()`

**Response:**
```json
{
  "token": "jwt_token_here",
  "data": {
    "agency_id": "123",
    "email": "agency@example.com",
    ...
  }
}
```

---

## 2. Subscription Management - Self-Service (8 Endpoints)

### 2.1. Get Subscription Plans
**GET** `/api/mobile/subscription/plans`

Retrieve all available subscription plans (public endpoint).

**Service**: `SubscriptionService.getPlans()`

**Response:**
```json
{
  "plans": [
    {
      "id": "plan_123",
      "name": "Basic Plan",
      "price": 29.99,
      "features": [...],
      "is_active": true
    }
  ]
}
```

---

### 2.2. Subscribe to Plan
**POST** `/api/mobile/subscription/subscribe`

Subscribe agency to a subscription plan.

**Request Body:**
```json
{
  "plan_id": "plan_123",
  "payment_method_id": "pm_xxx" // optional
}
```

**Service**: `SubscriptionService.subscribe()`

**Authentication**: Required (JWT)

---

### 2.3. Get Current Subscription
**GET** `/api/mobile/subscription`

Get current agency subscription details.

**Service**: `SubscriptionService.getSubscription()`

**Authentication**: Required (JWT)

**Response:**
```json
{
  "subscription": {
    "id": "sub_123",
    "plan_id": "plan_123",
    "status": "active",
    "start_date": "2024-01-01",
    "end_date": "2024-12-31"
  }
}
```

---

### 2.4. Upgrade Subscription
**PUT** `/api/mobile/subscription/upgrade`

Upgrade to a higher tier subscription plan.

**Request Body:**
```json
{
  "plan_id": "plan_premium",
  "prorated": true
}
```

**Service**: `SubscriptionService.upgrade()`

**Authentication**: Required (JWT)

---

### 2.5. Downgrade Subscription
**PUT** `/api/mobile/subscription/downgrade`

Downgrade to a lower tier subscription plan.

**Request Body:**
```json
{
  "plan_id": "plan_basic",
  "immediate": false
}
```

**Service**: `SubscriptionService.downgrade()`

**Authentication**: Required (JWT)

---

### 2.6. Cancel Subscription
**POST** `/api/mobile/subscription/cancel`

Cancel agency subscription.

**Request Body:**
```json
{
  "reason": "No longer needed", // optional
  "immediate": false
}
```

**Service**: `SubscriptionService.cancel()`

**Authentication**: Required (JWT)

---

### 2.7. Get Invoices
**GET** `/api/mobile/subscription/invoices`

Retrieve billing history/invoices.

**Query Parameters:**
- `page` (optional): Page number
- `limit` (optional): Results per page

**Service**: `SubscriptionService.getInvoices()`

**Authentication**: Required (JWT)

**Response:**
```json
{
  "invoices": [
    {
      "id": "inv_123",
      "amount": 29.99,
      "status": "paid",
      "date": "2024-01-01",
      "pdf_url": "..."
    }
  ]
}
```

---

### 2.8. Update Payment Method
**PUT** `/api/mobile/payment-method`

Update payment method for subscription billing.

**Request Body:**
```json
{
  "payment_method_id": "pm_xxx",
  "card_details": { ... } // optional
}
```

**Service**: `SubscriptionService.updatePaymentMethod()`

**Authentication**: Required (JWT)

---

## 3. Territory Setup (4 Endpoints)

### 3.1. Get Territories
**GET** `/api/mobile/territories`

Retrieve all territories (zipcodes) assigned to agency.

**Service**: `TerritoryService.getZipcodes()`

**Authentication**: Required (JWT)

**Response:**
```json
{
  "zipcodes": ["75201", "75202", "75203"],
  "territories": [
    {
      "id": "terr_1",
      "zipcode": "75201",
      "city": "Dallas"
    }
  ]
}
```

---

### 3.2. Add Territory
**POST** `/api/mobile/territories`

Add a new territory (zipcode) to agency.

**Request Body:**
```json
{
  "zipcode": "75201",
  "city": "Dallas" // optional
}
```

**Service**: `TerritoryService.addZipcode()`

**Authentication**: Required (JWT)

---

### 3.3. Update Territory
**PUT** `/api/mobile/territories/:id`

Update an existing territory.

**Request Body:**
```json
{
  "zipcode": "75201",
  "city": "Dallas"
}
```

**Service**: `TerritoryService.updateTerritory()`

**Authentication**: Required (JWT)

---

### 3.4. Delete Territory
**DELETE** `/api/mobile/territories/:id`

Remove a territory from agency.

**Service**: `TerritoryService.removeTerritory()`

**Authentication**: Required (JWT)

---

## 4. Lead Management (3 Endpoints)

### 4.1. Get Leads
**GET** `/api/mobile/leads`

Retrieve leads assigned to the agency.

**Query Parameters:**
- `status` (optional): Filter by status (new, contacted, qualified, converted)
- `from_date` (optional): ISO 8601 date
- `to_date` (optional): ISO 8601 date
- `limit` (optional): Maximum results

**Service**: `LeadService.getLeads()`

**Authentication**: Required (JWT)

**Response:**
```json
{
  "leads": [
    {
      "id": 123,
      "first_name": "John",
      "last_name": "Doe",
      "email": "john@example.com",
      "phone": "+1234567890",
      "status": "new",
      "assigned_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

---

### 4.2. Accept Lead
**PUT** `/api/mobile/leads/:id/accept`

Accept a lead assignment.

**Request Body:**
```json
{
  "notes": "Interested customer" // optional
}
```

**Service**: `LeadService.acceptLead()`

**Authentication**: Required (JWT)

---

### 4.3. Reject Lead
**PUT** `/api/mobile/leads/:id/reject`

Reject a lead assignment.

**Request Body:**
```json
{
  "reason": "Not interested" // optional
}
```

**Service**: `LeadService.rejectLead()`

**Authentication**: Required (JWT)

---

---

### 4.4. Get Lead Detail
**GET** `/api/mobile/leads/:id`

Get detailed information for a specific lead.

**Service**: `LeadService.getLeadDetail()`

**Authentication**: Required (JWT)

**Response:**
```json
{
  "id": 123,
  "first_name": "John",
  "last_name": "Doe",
  "email": "john@example.com",
  "phone": "+1234567890",
  "address": "123 Main St",
  "city": "Dallas",
  "state": "TX",
  "zipcode": "75201",
  "status": "new",
  "notes": "...",
  "assigned_at": "2024-01-01T00:00:00Z"
}
```

---

### 4.5. Update Lead Status
**PUT** `/api/mobile/leads/:id/status`

Update the status of a lead (workflow management).

**Request Body:**
```json
{
  "status": "contacted", // new, contacted, qualified, converted, rejected
  "notes": "Called customer" // optional
}
```

**Service**: `LeadService.updateLeadStatus()`

**Authentication**: Required (JWT)

---

### 4.6. Mark Lead as Viewed
**PUT** `/api/mobile/leads/:id/view`

Mark a lead as viewed (analytics tracking).

**Service**: `LeadService.markAsViewed()`

**Authentication**: Required (JWT)

---

### 4.7. Track Phone Call
**POST** `/api/mobile/leads/:id/call`

Track a phone call made to a lead (analytics).

**Service**: `LeadService.trackCall()`

**Authentication**: Required (JWT)

**Usage**: Automatically called when user clicks "Call" button in app

---

### 4.8. Add Notes to Lead
**POST** `/api/mobile/leads/:id/notes`

Add notes/comments to a lead.

**Request Body:**
```json
{
  "notes": "Customer interested in services. Follow up next week."
}
```

**Service**: `LeadService.addNotes()`

**Authentication**: Required (JWT)

---

## 5. Notification Management (2 Endpoints)

### 5.1. Get Notification Settings
**GET** `/api/mobile/notifications/settings`

Get user's notification preferences.

**Service**: `NotificationService.getSettings()`

**Authentication**: Required (JWT)

**Response:**
```json
{
  "push_enabled": true,
  "email_enabled": true,
  "sms_enabled": false,
  "sound_enabled": true,
  "vibration_enabled": true,
  "quiet_hours": {
    "start": "22:00",
    "end": "08:00"
  },
  "notification_types": ["lead_assigned", "subscription_expiring"]
}
```

---

### 5.2. Update Notification Settings
**PUT** `/api/mobile/notifications/settings`

Update notification preferences.

**Request Body:**
```json
{
  "push_enabled": true,
  "email_enabled": false,
  "sms_enabled": false,
  "sound_enabled": true,
  "vibration_enabled": true,
  "quiet_hours": {
    "start": "22:00",
    "end": "08:00"
  },
  "notification_types": ["lead_assigned"]
}
```

**Service**: `NotificationService.updateSettings()`

**Authentication**: Required (JWT)

---

## 6. Device Management (3 Endpoints)

### 6.1. Register Device for Push Notifications
**POST** `/api/mobile/auth/register-device`

Register device token for push notifications.

**Request Body:**
```json
{
  "device_token": "fcm_token_or_apns_token",
  "platform": "ios", // or "android"
  "device_model": "iPhone 14",
  "app_version": "1.0.0"
}
```

**Service**: `AuthService.registerDevice()`

**Authentication**: Required (JWT)

**Usage**: Called automatically on login or app start

---

### 6.2. Update Device Token
**PUT** `/api/mobile/auth/update-device`

Update device token when it changes (e.g., FCM token refresh).

**Request Body:**
```json
{
  "device_token": "new_fcm_token",
  "app_version": "1.0.1",
  "last_seen": "2024-01-01T00:00:00Z"
}
```

**Service**: `AuthService.updateDevice()`

**Authentication**: Required (JWT)

---

### 6.3. Unregister Device
**DELETE** `/api/mobile/auth/unregister-device`

Unregister device (called on logout).

**Service**: `AuthService.unregisterDevice()`

**Authentication**: Required (JWT)

**Usage**: Automatically called during logout process

---

## 7. Password Reset (1 Endpoint)

### 7.1. Forgot Password
**POST** `/api/mobile/auth/forgot-password`

Request password reset email.

**Request Body:**
```json
{
  "email": "agency@example.com"
}
```

**Service**: `AuthService.forgotPassword()`

**Authentication**: Not required (public)

**Response:**
```json
{
  "success": true,
  "message": "Password reset email sent"
}
```

---

## Implementation Details

### Service Files

All API services are located in `lib/core/services/`:

- **`auth_service.dart`**: Authentication endpoints (register, verify-email, login, logout, device management, password reset)
- **`subscription_service.dart`**: All subscription self-service endpoints
- **`territory_service.dart`**: Territory management endpoints
- **`lead_service.dart`**: Lead management endpoints (get, accept, reject, detail, status, notes, call tracking, view tracking)
- **`notification_service.dart`**: Notification preferences management
- **`api_client.dart`**: Centralized HTTP client with JWT token management

### Authentication

- JWT tokens are stored securely using `flutter_secure_storage` (encrypted storage)
- Tokens are automatically attached to authenticated requests via `Authorization: Bearer <token>` header
- Token is saved on successful login/email verification
- Token is cleared on logout
- Device registration for push notifications happens automatically on login

### Error Handling

All services include:
- Comprehensive error handling
- User-friendly error messages
- Network timeout handling (10-30 seconds)
- Automatic retry with cached URLs

### Caching

- Lead data is cached for 2 minutes to reduce API calls
- Territory data is cached locally for offline access
- Cache is automatically cleared on relevant mutations

---

## Production Considerations

1. **Environment Configuration**: Update base URLs for production in `api_client.dart`
2. **HTTPS**: Ensure all production endpoints use HTTPS
3. **Token Refresh**: Implement JWT refresh token mechanism if needed
4. **Rate Limiting**: Backend should implement rate limiting
5. **Error Monitoring**: Integrate crash reporting (Firebase Crashlytics, Sentry)
6. **Network Monitoring**: Monitor API response times and error rates

---

## Testing

All endpoints can be tested independently using the service methods:

```dart
// Example: Register new agency
try {
  final result = await AuthService.register(
    email: 'test@example.com',
    password: 'password123',
    agencyName: 'Test Agency',
  );
  print('Registration successful: $result');
} catch (e) {
  print('Registration failed: $e');
}
```

---

**Last Updated**: Based on architecture requirements
**Backend Repository**: Separate repository (middleware layer)
**Mobile App Repository**: This repository

