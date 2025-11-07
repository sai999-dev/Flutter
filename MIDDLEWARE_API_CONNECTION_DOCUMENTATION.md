# 🔌 Middleware API Connection Documentation

## Architecture Overview

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│  Flutter Mobile │         │  Middleware      │         │  Super Admin    │
│  App            │────────▶│  Layer (Node.js) │────────▶│  Portal API     │
│                 │         │                  │         │  (Backend)      │
└─────────────────┘         └──────────────────┘         └─────────────────┘
```

### Flow Architecture

1. **Mobile App** → Makes API calls through service layer
2. **Service Layer** → Uses `ApiClient` to communicate with middleware
3. **Middleware Layer** → Handles authentication, routing, and business logic
4. **Super Admin Portal API** → Source of truth for plans, leads, and agency data

---

## 📡 End-to-End API Endpoints

### Base URL Configuration

**Development:**
- Auto-detects from: `localhost:3000`, `3001`, or `3002`
- Health check: `GET /api/health`

**Production:**
- Set in `flutter-backend/lib/services/api_client.dart`:
  ```dart
  static const String? productionApiUrl = 'https://your-api-domain.com';
  ```

---

## 🔐 Authentication Flow

### Registration → Login → JWT Token

```
1. POST /api/mobile/auth/register
   └─> Returns: { token, agency_id, user_profile }

2. POST /api/mobile/auth/login
   └─> Returns: { token, data: { agency_id, ... } }

3. All subsequent requests include:
   Header: Authorization: Bearer <token>
```

**Token Storage:** Encrypted secure storage via `SecureStorageService`

---

## 📋 Complete Endpoint Mapping

### 1. Authentication Endpoints

| Mobile App Call | Middleware Endpoint | Super Admin Portal | Auth | Purpose |
|----------------|---------------------|-------------------|------|---------|
| `AuthService.register()` | `POST /api/mobile/auth/register` | Creates agency account | ❌ | Register new agency |
| `AuthService.login()` | `POST /api/mobile/auth/login` | Authenticates user | ❌ | User login |
| `AuthService.verifyEmail()` | `POST /api/mobile/auth/verify-email` | Verifies email | ❌ | Email verification |
| `AuthService.forgotPassword()` | `POST /api/mobile/auth/forgot-password` | Sends reset email | ❌ | Password reset |

**Request Example (Register):**
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

**Response Example:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "agency_id": "agency_123",
  "user_profile": {
    "email": "agency@example.com",
    "agency_name": "ABC Healthcare"
  }
}
```

---

### 2. Subscription Plans Endpoints

| Mobile App Call | Middleware Endpoint | Super Admin Portal | Auth | Purpose |
|----------------|---------------------|-------------------|------|---------|
| `SubscriptionService.getPlans()` | `GET /api/mobile/subscription/plans?isActive=true` | Fetches from plans table | ❌ | Get all active plans |
| `SubscriptionService.getSubscription()` | `GET /api/mobile/subscription` | Fetches agency subscription | ✅ | Get current subscription |
| `SubscriptionService.subscribe()` | `POST /api/mobile/subscription/subscribe` | Creates subscription | ✅ | Subscribe to plan |
| `SubscriptionService.upgrade()` | `PUT /api/mobile/subscription/upgrade` | Updates subscription | ✅ | Upgrade plan |
| `SubscriptionService.downgrade()` | `PUT /api/mobile/subscription/downgrade` | Updates subscription | ✅ | Downgrade plan |
| `SubscriptionService.cancel()` | `POST /api/mobile/subscription/cancel` | Cancels subscription | ✅ | Cancel subscription |

**Request Example (Get Plans):**
```
GET /api/mobile/subscription/plans?isActive=true
```

**Response Example:**
```json
{
  "plans": [
    {
      "id": "plan_1",
      "name": "Basic",
      "price_per_unit": 99,
      "base_zipcodes_included": 3,
      "features": [
        "3 zipcodes included",
        "Real-time lead notifications",
        "Basic analytics"
      ],
      "is_active": true
    },
    {
      "id": "plan_2",
      "name": "Premium",
      "price_per_unit": 199,
      "base_zipcodes_included": 7,
      "features": [
        "7 zipcodes included",
        "Real-time lead notifications",
        "Advanced analytics",
        "Priority support"
      ],
      "is_active": true
    }
  ]
}
```

---

### 3. Leads Management Endpoints

| Mobile App Call | Middleware Endpoint | Super Admin Portal | Auth | Purpose |
|----------------|---------------------|-------------------|------|---------|
| `LeadService.getLeads()` | `GET /api/mobile/leads?status=new&limit=50` | Fetches leads for agency | ✅ | Get filtered leads |
| `LeadService.getLeadDetail()` | `GET /api/mobile/leads/:leadId` | Fetches lead details | ✅ | Get lead details |
| `LeadService.acceptLead()` | `PUT /api/mobile/leads/:leadId/accept` | Updates lead status | ✅ | Accept lead |
| `LeadService.rejectLead()` | `PUT /api/mobile/leads/:leadId/reject` | Updates lead status | ✅ | Reject lead |
| `LeadService.updateLeadStatus()` | `PUT /api/mobile/leads/:leadId/status` | Updates lead status | ✅ | Update status |
| `LeadService.markAsViewed()` | `PUT /api/mobile/leads/:leadId/view` | Marks as viewed | ✅ | Mark viewed |
| `LeadService.trackCall()` | `POST /api/mobile/leads/:leadId/call` | Logs call activity | ✅ | Track phone call |
| `LeadService.addNotes()` | `POST /api/mobile/leads/:leadId/notes` | Adds notes | ✅ | Add notes |

**Request Example (Get Leads):**
```
GET /api/mobile/leads?status=new&from_date=2025-01-01T00:00:00Z&limit=50
```

**Response Example:**
```json
{
  "leads": [
    {
      "id": 1,
      "first_name": "John",
      "last_name": "Smith",
      "phone": "(214) 555-0101",
      "email": "john.smith@example.com",
      "zipcode": "75201",
      "city": "Dallas",
      "state": "TX",
      "age": 45,
      "status": "new",
      "created_at": "2025-11-03T10:00:00Z",
      "notes": "Interested in home care services"
    }
  ]
}
```

**Fallback (Dummy Leads):**
When API is unavailable, `LeadService` returns dummy leads for development/testing:
- 5 sample leads with realistic data
- Various statuses (new, contacted, accepted)
- Different zipcodes for testing filtering

---

### 4. Territory/Zipcode Endpoints

| Mobile App Call | Middleware Endpoint | Super Admin Portal | Auth | Purpose |
|----------------|---------------------|-------------------|------|---------|
| `TerritoryService.getZipcodes()` | `GET /api/mobile/territories` | Fetches agency zipcodes | ✅ | Get user zipcodes |
| `TerritoryService.addZipcode()` | `POST /api/mobile/territories` | Adds zipcode | ✅ | Add zipcode |
| `TerritoryService.updateTerritory()` | `PUT /api/mobile/territories/:id` | Updates territory | ✅ | Update zipcode |
| `TerritoryService.removeTerritory()` | `DELETE /api/mobile/territories/:id` | Removes territory | ✅ | Remove zipcode |

**Request Example (Get Zipcodes):**
```
GET /api/mobile/territories
Authorization: Bearer <token>
```

**Response Example:**
```json
{
  "zipcodes": ["75201", "75033", "75001"]
}
```

---

### 5. Document Verification Endpoints

| Mobile App Call | Middleware Endpoint | Super Admin Portal | Auth | Purpose |
|----------------|---------------------|-------------------|------|---------|
| `DocumentVerificationService.uploadDocument()` | `POST /api/mobile/auth/upload-document` | Uploads document | ✅ | Upload verification doc |
| `DocumentVerificationService.getVerificationStatus()` | `GET /api/mobile/auth/verification-status` | Gets status | ✅ | Check verification |
| `DocumentVerificationService.getDocuments()` | `GET /api/mobile/auth/documents` | Lists documents | ✅ | List uploaded docs |

---

### 6. Notification Endpoints

| Mobile App Call | Middleware Endpoint | Super Admin Portal | Auth | Purpose |
|----------------|---------------------|-------------------|------|---------|
| `NotificationService.getSettings()` | `GET /api/mobile/notifications/settings` | Gets preferences | ✅ | Get notification settings |
| `NotificationService.updateSettings()` | `PUT /api/mobile/notifications/settings` | Updates preferences | ✅ | Update settings |

---

## 🔄 Complete User Journey Endpoints

### Registration Flow

```
1. User opens app → LoginPage
2. Clicks "Create Account" → MultiStepRegisterPage
3. Step 1: Agency Info → User fills form
4. Step 2: Plan Selection → GET /api/mobile/subscription/plans
   └─> User selects plan
5. Step 3: Zipcode Selection → User selects zipcodes (validated locally)
6. Step 4: Password → User sets password
7. Payment Method (Stripe test mode) → Mobile creates PaymentMethod and includes payment_method_id
8. Registration → POST /api/mobile/auth/register (includes plan_id and optional payment_method_id)
   └─> Returns: { token, agency_id }
   └─> Saves token to secure storage
   └─> Navigates to HomePage
9. Post-Registration Verification → App prompts to upload business validity document (optional at this step)
  └─> POST /api/mobile/auth/upload-document (multipart). Admin will verify; leads begin after approval.
```

### Login Flow

```
1. User enters email/password
2. POST /api/mobile/auth/login
   └─> Returns: { token, data: { agency_id, ... } }
3. Save token to secure storage
4. Sync zipcodes → GET /api/mobile/territories
5. Navigate to HomePage
```

### View Leads Flow

```
1. User opens Leads tab
2. GET /api/mobile/leads?status=new
   └─> Returns: { leads: [...] }
3. Filter by user's zipcodes (client-side)
4. Display leads list
5. User clicks lead → GET /api/mobile/leads/:leadId
6. User accepts → PUT /api/mobile/leads/:leadId/accept
```

### View Plans Flow

```
1. User opens Plans tab
2. GET /api/mobile/subscription/plans?isActive=true
   └─> Returns: { plans: [...] }
3. GET /api/mobile/subscription (current subscription)
   └─> Returns: { subscription: { planName, monthlyPrice, ... } }
4. Display current plan + available plans
5. User can upgrade/downgrade via ManageSubscriptionModal
```

---

## 🏗️ Middleware Implementation Requirements

### Required Endpoints in Node.js Backend

All endpoints must be implemented in the middleware layer:

#### Authentication Routes
```javascript
POST   /api/mobile/auth/register
POST   /api/mobile/auth/login
POST   /api/mobile/auth/verify-email
POST   /api/mobile/auth/forgot-password
POST   /api/mobile/auth/register-device
PUT    /api/mobile/auth/update-device
DELETE /api/mobile/auth/unregister-device
POST   /api/mobile/auth/upload-document (multipart)
GET    /api/mobile/auth/verification-status
GET    /api/mobile/auth/documents
```

#### Subscription Routes
```javascript
GET    /api/mobile/subscription/plans?isActive=true
GET    /api/mobile/subscription
POST   /api/mobile/subscription/subscribe
PUT    /api/mobile/subscription/upgrade
PUT    /api/mobile/subscription/downgrade
POST   /api/mobile/subscription/cancel
GET    /api/mobile/subscription/invoices
PUT    /api/mobile/payment-method
```

#### Leads Routes
```javascript
GET    /api/mobile/leads?status=new&limit=50
GET    /api/mobile/leads/:leadId
PUT    /api/mobile/leads/:leadId/status
PUT    /api/mobile/leads/:leadId/view
POST   /api/mobile/leads/:leadId/call
POST   /api/mobile/leads/:leadId/notes
PUT    /api/mobile/leads/:leadId/accept
PUT    /api/mobile/leads/:leadId/reject
```

#### Territory Routes
```javascript
GET    /api/mobile/territories
POST   /api/mobile/territories
PUT    /api/mobile/territories/:id
DELETE /api/mobile/territories/:id
```

#### Notification Routes
```javascript
GET    /api/mobile/notifications/settings
PUT    /api/mobile/notifications/settings
```

#### Health Check
```javascript
GET    /api/health
```

---

## � Payments (Stripe)

Mobile app uses Stripe SDK to securely collect card details and create a PaymentMethod on-device (test mode by default). The server (middleware) owns all secret operations:

- Create Stripe Customer (if not exists)
- Attach the provided `payment_method_id`
- Create Subscription or PaymentIntent for the chosen `plan_id`
- Persist invoice/subscription state in the Admin Portal backend

Client payload examples:

```json
// Registration payload (optional payment method)
{
  "email": "agency@example.com",
  "password": "******",
  "agency_name": "ABC Healthcare",
  "plan_id": "plan_123",
  "zipcodes": ["75201"],
  "payment_method_id": "pm_1PNxxxxxxTEST"
}
```

Security notes:
- Never expose Stripe secret keys in the app
- Only the publishable key is configured client-side
- All charges/subscriptions are created by the middleware

---

## �🔐 Authentication Implementation

### JWT Token Flow

1. **Registration/Login:**
   - Backend returns JWT token in response
   - Mobile app saves to secure storage

2. **Subsequent Requests:**
   - Mobile app reads token from secure storage
   - Adds to header: `Authorization: Bearer <token>`
   - Middleware validates token

3. **Token Expiration:**
   - Middleware returns 401 Unauthorized
   - Mobile app clears token and redirects to login

### Secure Storage Implementation

```dart
// Save token
await SecureStorageService.saveToken(token);

// Get token
final token = await SecureStorageService.getToken();

// Clear token (logout)
await SecureStorageService.deleteToken();
```

---

## 📊 Response Format Standards

### Success Response

```json
{
  "success": true,
  "data": { ... },
  "message": "Operation successful"
}
```

### Error Response

```json
{
  "success": false,
  "error": "Error message",
  "message": "Detailed error description",
  "statusCode": 400
}
```

### List Response

```json
{
  "data": [ ... ],
  "total": 100,
  "page": 1,
  "limit": 50
}
```

---

## 🧪 Testing & Development

### Dummy Data for Testing

**Leads:**
- When API is unavailable, `LeadService` returns 5 dummy leads
- Includes various statuses and zipcodes for testing
- Production: Remove or disable dummy data

**Plans:**
- Fetch from Super Admin Portal API
- If unavailable, app shows empty state with message

### Development Mode

**Enable Debug Logging:**
- All API calls log to console
- Check for connection errors
- Verify endpoint responses

**Health Check:**
- App auto-detects working backend server
- Tries multiple ports (3000, 3001, 3002)
- Caches working URL for 5 minutes

---

## 🚀 Production Deployment Checklist

### Mobile App Configuration

- [ ] Set `productionApiUrl` in `api_client.dart`
- [ ] Remove debug print statements
- [ ] Disable dummy leads (or keep for fallback)
- [ ] Test all endpoints with production URL
- [ ] Verify JWT token handling
- [ ] Test offline scenarios

### Middleware Configuration

- [ ] All endpoints implemented
- [ ] CORS configured for mobile app domain
- [ ] JWT validation on protected routes
- [ ] Error handling implemented
- [ ] Rate limiting configured
- [ ] Logging configured
- [ ] Health check endpoint working

### Database Configuration

- [ ] Plans table seeded with active plans
- [ ] Leads table accessible
- [ ] Territories table accessible
- [ ] Agencies table accessible
- [ ] Indexes optimized

---

## 📝 Code Standards

### Service Layer Pattern

```dart
// ✅ CORRECT - Use service
final plans = await SubscriptionService.getPlans();

// ❌ WRONG - Direct API call
final response = await ApiClient.get('/api/mobile/subscription/plans');
```

### Error Handling

```dart
try {
  final result = await Service.method();
  // Handle success
} catch (e) {
  // Handle error gracefully
  print('Error: $e');
  // Show user-friendly message
}
```

### Response Parsing

```dart
// Handle multiple response formats
if (data is List) {
  return data;
} else if (data['data'] is List) {
  return data['data'];
} else if (data['plans'] is List) {
  return data['plans'];
}
```

---

## 🔍 Troubleshooting

### Common Issues

**1. "No backend server available"**
- Check backend is running
- Verify port (3000, 3001, or 3002)
- Check health endpoint: `GET /api/health`

**2. "Authentication required" (401)**
- Verify token is saved
- Check token expiration
- Re-login if expired

**3. "Endpoint not found" (404)**
- Verify endpoint path matches exactly
- Check middleware routes are registered
- Ensure middleware is running

**4. CORS Errors**
- Configure CORS in middleware
- Allow mobile app origin
- Check preflight requests

---

## 📈 Performance Optimization

### Caching Strategy

- **Leads:** 2-minute TTL (frequently changing)
- **Plans:** No cache (fetch on each request)
- **Zipcodes:** Cached locally (SharedPreferences)
- **User Profile:** Cached locally until logout

### Request Optimization

- Use query parameters for filtering
- Implement pagination for large lists
- Batch requests where possible
- Use compression for large payloads

---

## ✅ End-to-End Verification

### Test Flow

1. **Registration:**
   - ✅ Create account
   - ✅ Select plan
   - ✅ Select zipcodes
   - ✅ Complete registration
   - ✅ Verify token saved

2. **Login:**
   - ✅ Login with credentials
   - ✅ Verify token saved
   - ✅ Verify zipcodes synced

3. **View Leads:**
   - ✅ Fetch leads from API
   - ✅ Filter by zipcodes
   - ✅ Display leads list
   - ✅ View lead details

4. **View Plans:**
   - ✅ Fetch plans from API
   - ✅ Display current subscription
   - ✅ Show available plans
   - ✅ Display selected zipcodes

5. **Settings:**
   - ✅ Load notification settings
   - ✅ Update settings
   - ✅ Save preferences

---

## 📚 Additional Resources

- **API Endpoints Documentation:** See `API_ENDPOINTS_DOCUMENTATION.md`
- **Service Layer:** See `flutter-backend/lib/services/`
- **Architecture:** See `README.md`

---

**Last Updated:** 2025-11-03  
**Version:** 1.0.0  
**Architecture:** Mobile App → Middleware Layer → Super Admin Portal API

