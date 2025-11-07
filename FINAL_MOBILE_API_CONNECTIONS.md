# ✅ Final Mobile API Connections (Middleware Integration)

This document is the authoritative, error‑checked reference for all API endpoints the Flutter mobile app uses to connect to the Middleware Layer (Node.js) and, through it, to the Admin Portal backend and Stripe.

- Base path for all mobile endpoints: `/api/mobile/*`
- Health check path: `/api/health`
- Auth: Bearer JWT in `Authorization` header for protected endpoints
- Response format: JSON (see Error and Success formats below)

Notes:
- Production base URL is configured in `flutter-backend/lib/services/api_client.dart` (`productionApiUrl`).
- In development, the app auto-detects `http://localhost` candidates: 3000, 3001, 3002 via health check.
- All UI calls must go through the service layer (`flutter-backend/lib/services/*`).

---

## 🔐 Authentication

All routes under `/api/mobile/auth/*`.

1) Register
- Method: POST
- Endpoint: `/api/mobile/auth/register`
- Auth: No
- Request (example):
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
  "plan_id": "plan_123",
  "payment_method_id": "pm_1PNxxxxxxTEST"  
}
```
- Response (example):
```json
{
  "token": "<jwt>",
  "agency_id": "agency_123",
  "user_profile": {"email":"agency@example.com","agency_name":"ABC Healthcare"}
}
```

2) Login
- Method: POST
- Endpoint: `/api/mobile/auth/login`
- Auth: No
- Request:
```json
{ "email": "agency@example.com", "password": "SecurePass123" }
```
- Response:
```json
{ "token": "<jwt>", "data": { "agency_id": "agency_123", ... } }
```

3) Verify Email
- Method: POST
- Endpoint: `/api/mobile/auth/verify-email`
- Auth: No
- Request:
```json
{ "email": "agency@example.com", "verification_code": "123456" }
```

4) Forgot Password
- Method: POST
- Endpoint: `/api/mobile/auth/forgot-password`
- Auth: No
- Request:
```json
{ "email": "agency@example.com" }
```

5) Device Registration (Push)
- Method: POST
- Endpoint: `/api/mobile/auth/register-device`
- Auth: Yes
- Request:
```json
{ "device_token": "...", "platform": "ios|android", "device_model": "...", "app_version": "..." }
```

6) Update Device
- Method: PUT
- Endpoint: `/api/mobile/auth/update-device`
- Auth: Yes
- Request:
```json
{ "device_token": "...", "app_version": "...", "last_seen": "<ISO8601>" }
```

7) Unregister Device
- Method: DELETE
- Endpoint: `/api/mobile/auth/unregister-device`
- Auth: Yes

8) Upload Verification Document
- Method: POST (multipart)
- Endpoint: `/api/mobile/auth/upload-document`
- Auth: Yes
- Fields:
  - `document` (file), `agency_id`, `document_type` (business_license|certificate|tax_id|other), `description`

9) Verification Status
- Method: GET
- Endpoint: `/api/mobile/auth/verification-status`
- Auth: Yes

10) List Documents
- Method: GET
- Endpoint: `/api/mobile/auth/documents`
- Auth: Yes

Post‑registration policy: Registration does not block on verification. The app prompts to upload a business document after registration; admin verifies; leads begin after approval.

---

## 💳 Subscriptions & Payments

All routes under `/api/mobile/subscription/*` and `/api/mobile/payment-method`.

Stripe flow (client+server):
- Mobile uses Stripe SDK to collect card details and creates a PaymentMethod (client-side, test mode).
- `payment_method_id` may be included in registration or updated later.
- Middleware (server) owns Stripe secret operations: create/attach customer PMs, create subscriptions or PaymentIntents, and persist state.

1) Plans
- Method: GET
- Endpoint: `/api/mobile/subscription/plans?isActive=true`
- Auth: No
- Response (example):
```json
{
  "plans":[
    {"id":"plan_1","name":"Basic","price_per_unit":99,"base_zipcodes_included":3,"is_active":true},
    {"id":"plan_2","name":"Premium","price_per_unit":199,"base_zipcodes_included":7,"is_active":true}
  ]
}
```

2) Current Subscription
- Method: GET
- Endpoint: `/api/mobile/subscription`
- Auth: Yes

3) Subscribe
- Method: POST
- Endpoint: `/api/mobile/subscription/subscribe`
- Auth: Yes
- Request:
```json
{ "plan_id": "plan_123", "payment_method_id": "pm_1PNxxxxxxTEST" }
```

4) Upgrade
- Method: PUT
- Endpoint: `/api/mobile/subscription/upgrade`
- Auth: Yes
- Request:
```json
{ "plan_id": "plan_456", "prorated": true }
```

5) Downgrade
- Method: PUT
- Endpoint: `/api/mobile/subscription/downgrade`
- Auth: Yes
- Request:
```json
{ "plan_id": "plan_123", "immediate": false }
```

6) Cancel
- Method: POST
- Endpoint: `/api/mobile/subscription/cancel`
- Auth: Yes
- Request:
```json
{ "reason": "Switching", "immediate": false }
```

7) Invoices
- Method: GET
- Endpoint: `/api/mobile/subscription/invoices`
- Auth: Yes
- Query: `page`, `limit`

8) Update Payment Method
- Method: PUT
- Endpoint: `/api/mobile/payment-method`
- Auth: Yes
- Request:
```json
{ "payment_method_id": "pm_1PNxxxxxxTEST", "card_last4": "4242" }
```

---

## 📊 Leads

All routes under `/api/mobile/leads/*`.

1) List Leads
- Method: GET
- Endpoint: `/api/mobile/leads`
- Auth: Yes
- Query: `status`, `from_date`, `to_date`, `limit`

2) Lead Detail
- Method: GET
- Endpoint: `/api/mobile/leads/:leadId`
- Auth: Yes

3) Update Status
- Method: PUT
- Endpoint: `/api/mobile/leads/:leadId/status`
- Auth: Yes
- Request:
```json
{ "status": "accepted|rejected|contacted|...", "notes": "..." }
```

4) Mark Viewed
- Method: PUT
- Endpoint: `/api/mobile/leads/:leadId/view`
- Auth: Yes

5) Track Call
- Method: POST
- Endpoint: `/api/mobile/leads/:leadId/call`
- Auth: Yes

6) Add Notes
- Method: POST
- Endpoint: `/api/mobile/leads/:leadId/notes`
- Auth: Yes
- Request:
```json
{ "notes": "..." }
```

7) Accept Lead
- Method: PUT
- Endpoint: `/api/mobile/leads/:leadId/accept`
- Auth: Yes

8) Reject Lead
- Method: PUT
- Endpoint: `/api/mobile/leads/:leadId/reject`
- Auth: Yes
- Request:
```json
{ "reason": "Not in service area" }
```

---

## 🗺️ Territories (Zipcodes)

All routes under `/api/mobile/territories`.

1) Get Zipcodes
- Method: GET
- Endpoint: `/api/mobile/territories`
- Auth: Yes
- Response:
```json
{ "zipcodes": ["75201", "75033", "75001"] }
```

2) Add Zipcode
- Method: POST
- Endpoint: `/api/mobile/territories`
- Auth: Yes
- Request:
```json
{ "zipcode": "75201", "city": "Dallas, TX" }
```

3) Update Territory
- Method: PUT
- Endpoint: `/api/mobile/territories/:id`
- Auth: Yes

4) Remove Territory
- Method: DELETE
- Endpoint: `/api/mobile/territories/:id`
- Auth: Yes

---

## 🔔 Notification Settings

All routes under `/api/mobile/notifications/*`.

1) Get Settings
- Method: GET
- Endpoint: `/api/mobile/notifications/settings`
- Auth: Yes

2) Update Settings
- Method: PUT
- Endpoint: `/api/mobile/notifications/settings`
- Auth: Yes
- Request:
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

## 🏥 Health Check

- Method: GET
- Endpoint: `/api/health`
- Auth: No
- Purpose: Used by the client to auto-detect a working base URL.

---

## 🔒 Headers & Auth

- `Content-Type: application/json` (except multipart)
- `Authorization: Bearer <jwt>` for all protected endpoints

---

## ✅ Response Formats

Success (typical):
```json
{ "success": true, "data": { }, "message": "OK" }
```

Error:
```json
{ "success": false, "error": "Error message", "message": "Details", "statusCode": 400 }
```

Lists:
```json
{ "data": [ ... ], "total": 100, "page": 1, "limit": 50 }
```

The app’s service layer also accepts variants such as top-level arrays or named keys like `plans`, `leads`, or `documents` and normalizes them internally.

---

## 🔧 Client Implementation Contracts

- All calls must be made via services in `flutter-backend/lib/services/*`.
  - `api_client.dart`: base URL discovery, JWT handling
  - `auth_service.dart`: register/login/device + docs
  - `subscription_service.dart`: plans, subscribe, invoices, payment method
  - `lead_service.dart`: lead list/detail/actions
  - `territory_service.dart`: zipcodes CRUD
  - `notification_service.dart`: settings
- Multipart upload for documents uses `DocumentVerificationService.uploadDocument`.
- Stripe PaymentMethod is created on-device in `PaymentGatewayDialog` (CardField) and the ID is included in registration or saved for updates.

---

## 🚀 Production Checklist

- Set `productionApiUrl` in `flutter-backend/lib/services/api_client.dart` to your real API domain
- Configure Stripe keys (publishable key in app, secret key on middleware)
- Ensure CORS allows mobile origin
- Verify JWT validation on protected endpoints
- Confirm all `/api/mobile/*` routes exist in middleware
- Confirm health check `/api/health` returns 200

---

Last Updated: 2025-11-05
