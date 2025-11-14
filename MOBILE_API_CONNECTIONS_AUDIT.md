# Mobile App API Connections Audit

**Generated:** $(date)  
**Scope:** Flutter Backend Services Package (`flutter-backend/lib/services/`)  
**Analysis Type:** READ-ONLY - No files modified

---

## 1. SERVICE FILES SUMMARY

| Service File | Backend Endpoints Used | Authentication | Error Handling | Caching |
|-------------|----------------------|----------------|----------------|---------|
| `auth_service.dart` | 11 endpoints | JWT (varies) | ✅ Comprehensive | ❌ No |
| `document_verification_service.dart` | 3 endpoints | JWT Required | ✅ Good | ❌ No |
| `lead_service.dart` | 9 endpoints | JWT Required | ✅ Comprehensive | ✅ Yes (2 min TTL) |
| `notification_service.dart` | 2 endpoints | JWT Required | ✅ Good | ✅ Local Storage |
| `subscription_service.dart` | 8 endpoints | JWT (varies) | ✅ Good | ❌ No |
| `territory_service.dart` | 4 endpoints | JWT Required | ✅ Good | ✅ Local Storage |

**Total API Endpoints:** 37 unique endpoints

---

## 2. API CLIENT CONFIGURATION

### Base URL Configuration
- **Production URL:** Configurable via `productionApiUrl` (currently `null`)
- **Development URLs (fallback):**
  - `http://127.0.0.1:3002`
  - `http://localhost:3002`
  - `http://127.0.0.1:3001`
  - `http://localhost:3001`
  - `http://127.0.0.1:3000`
  - `http://localhost:3000`

### URL Discovery Mechanism
- **Health Check Endpoint:** `/api/health`
- **Cache Duration:** 5 minutes
- **Discovery Timeout:** 3 seconds per URL
- **Cached URL Verification:** 1 second timeout

### HTTP Configuration
- **Default Timeout:** 10 seconds (all HTTP methods)
- **Content-Type:** `application/json`
- **Headers:** 
  - `Content-Type: application/json`
  - `Authorization: Bearer {token}` (when authenticated)

### JWT Token Management
- **Storage:** `SecureStorageService` (encrypted secure storage)
- **Token Retrieval:** `SecureStorageService.getToken()`
- **Token Persistence:** `SecureStorageService.saveToken(token)`
- **Token Clearing:** `SecureStorageService.deleteToken()`
- **Authentication Check:** `ApiClient.isAuthenticated` (checks if token exists)
- **Token Refresh:** ❌ Not implemented (no automatic refresh logic)
- **Token Expiry Handling:** ❌ Not implemented (backend must handle 401 responses)

### Test Mode
- **Status:** Disabled in production builds (compile-time check)
- **Debug Mode:** Can be enabled via `SharedPreferences` (`test_mode` flag)
- **Security:** Production builds automatically disable test mode

---

## 3. DETAILED SERVICE ANALYSIS

### Service: `auth_service.dart`

**Total Functions:** 11  
**Authentication Required:** Varies by endpoint

#### 1. Register Agency
- **Endpoint:** `POST /api/mobile/auth/register`
- **Function:** `register({email, password, agencyName, phone?, additionalData?})`
- **Authentication:** ❌ No (`requireAuth: false`)
- **Request Body:**
```dart
{
  "email": String (normalized: trim, lowercase),
  "password": String (trimmed),
  "agency_name": String (trimmed),
  "phone": String? (trimmed, optional),
  ...additionalData
}
```
- **Response Expected:**
```dart
{
  "success": bool?,
  "token": String?,
  "agency": Map<String, dynamic>?,
  "data": Map<String, dynamic>?,
  "message": String?
}
```
- **Success Status Codes:** 200, 201
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Network error handling
  - ✅ Validation error parsing
  - ✅ Detailed error logging
  - **Error Fields Checked:** `message`, `error`, `msg`, `errorMessage`, `errors`, `details`
- **Data Transformations:**
  - Email normalized to lowercase and trimmed
  - Password trimmed
  - Agency name trimmed
  - Phone trimmed (if provided)

#### 2. Verify Email
- **Endpoint:** `POST /api/mobile/auth/verify-email`
- **Function:** `verifyEmail({email, verificationCode})`
- **Authentication:** ✅ Yes (default `requireAuth: true`)
- **Request Body:**
```dart
{
  "email": String,
  "verification_code": String
}
```
- **Response Expected:**
```dart
{
  "success": bool?,
  "token": String?,
  "message": String?
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Error message extraction
  - **Error Fields Checked:** `message`, `error`
- **Token Handling:** Automatically saves token if present in response

#### 3. Login
- **Endpoint:** `POST /api/mobile/auth/login`
- **Function:** `login(email, password)`
- **Authentication:** ❌ No (`requireAuth: false`)
- **Request Body:**
```dart
{
  "email": String (normalized: trim, lowercase),
  "password": String (trimmed)
}
```
- **Response Expected:**
```dart
{
  "token": String,
  "data": Map<String, dynamic>? (user profile),
  "agency_id": String?,
  "id": String?,
  ...other profile fields
}
```
- **Success Status Codes:** 200, 201
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Detailed error logging
  - ✅ Specific error message mapping
  - ✅ Backend server availability check
  - **Error Fields Checked:** `message`, `error`, `msg`
- **Data Transformations:**
  - Email normalized to lowercase and trimmed
  - Password trimmed
  - Clears existing token before login
  - Normalizes profile data (handles `data` wrapper)
  - Saves user profile to `SharedPreferences`
  - Saves agency ID to `SharedPreferences`
  - Saves last login timestamp

#### 4. Register Device (Push Notifications)
- **Endpoint:** `POST /api/mobile/auth/register-device`
- **Function:** `registerDevice({deviceToken, platform, deviceModel?, appVersion?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "device_token": String,
  "platform": String ("ios" | "android"),
  "device_model": String?,
  "app_version": String?
}
```
- **Response Expected:** Status 200 or 201
- **Success Status Codes:** 200, 201
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns `false` on error (non-throwing)
- **Local Storage:** Saves device token, platform, and registration status

#### 5. Update Device
- **Endpoint:** `PUT /api/mobile/auth/update-device`
- **Function:** `updateDevice({deviceToken, appVersion?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "device_token": String,
  "app_version": String?,
  "last_seen": String (ISO8601 timestamp)
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns `false` on error (non-throwing)
- **Local Storage:** Updates device token

#### 6. Unregister Device
- **Endpoint:** `DELETE /api/mobile/auth/unregister-device`
- **Function:** `unregisterDevice()`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:** None
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns `false` on error (non-throwing)
- **Local Storage:** Clears device token, platform, and registration status

#### 7. Logout
- **Endpoint:** None (local operation)
- **Function:** `logout()`
- **Authentication:** N/A
- **Operations:**
  - Calls `unregisterDevice()`
  - Clears JWT token via `ApiClient.clearToken()`
  - Clears user profile from `SharedPreferences`
  - Clears agency ID from `SharedPreferences`
  - Clears last login timestamp
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Non-throwing (errors logged only)

#### 8. Get User Profile (Local)
- **Endpoint:** None (local storage only)
- **Function:** `getUserProfile()`
- **Authentication:** N/A
- **Data Source:** `SharedPreferences` (`user_profile` key)
- **Returns:** `Map<String, dynamic>?` or `null`

#### 9. Get Agency ID (Local)
- **Endpoint:** None (local storage only)
- **Function:** `getAgencyId()`
- **Authentication:** N/A
- **Data Source:** `SharedPreferences` (`agency_id` key)
- **Returns:** `String?` or `null`

#### 10. Forgot Password
- **Endpoint:** `POST /api/mobile/auth/forgot-password`
- **Function:** `forgotPassword(email)`
- **Authentication:** ❌ No (`requireAuth: false`)
- **Request Body:**
```dart
{
  "email": String (normalized: trim, lowercase)
}
```
- **Response Expected:**
```dart
{
  "success": bool,
  "message": String?
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Error message extraction
  - **Error Fields Checked:** `message`

#### 11. Verify Reset Code
- **Endpoint:** `POST /api/mobile/auth/verify-reset-code`
- **Function:** `verifyResetCode(email, code)`
- **Authentication:** ❌ No (`requireAuth: false`)
- **Request Body:**
```dart
{
  "email": String (normalized: trim, lowercase),
  "code": String (trimmed, 6 digits)
}
```
- **Response Expected:**
```dart
{
  "success": bool,
  "message": String?
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Error message extraction
  - **Error Fields Checked:** `message`
  - **Default Error:** "Invalid or expired verification code"

#### 12. Reset Password
- **Endpoint:** `POST /api/mobile/auth/reset-password`
- **Function:** `resetPassword({email, code, newPassword})`
- **Authentication:** ❌ No (`requireAuth: false`)
- **Request Body:**
```dart
{
  "email": String (normalized: trim, lowercase),
  "code": String (trimmed),
  "new_password": String (trimmed, min 6 chars)
}
```
- **Response Expected:**
```dart
{
  "success": bool,
  "message": String?
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Password validation (min 6 characters)
  - ✅ Error message extraction
  - **Error Fields Checked:** `message`
  - **Default Error:** "Failed to reset password"

---

### Service: `document_verification_service.dart`

**Total Functions:** 4  
**Authentication Required:** Yes (except file picker)

#### 1. Upload Document
- **Endpoint:** `POST /api/mobile/auth/upload-document`
- **Function:** `uploadDocument({agencyId, filePath, documentType?, description?})`
- **Authentication:** ✅ Yes (JWT token in header)
- **Request Type:** Multipart Form Data
- **Request Fields:**
```dart
{
  "document": File (multipart),
  "agency_id": String,
  "document_type": String? ("business_license" | "certificate" | "tax_id" | "other"),
  "description": String?
}
```
- **File Constraints:**
  - Max size: 10MB
  - Allowed extensions: `.pdf`, `.png`, `.jpg`, `.jpeg`
- **Response Expected:**
```dart
{
  "success": bool?,
  "message": String?,
  "document_id": String?,
  ...other fields
}
```
- **Success Status Codes:** 200, 201
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ File existence check
  - ✅ File size validation
  - ✅ File type validation
  - ✅ Error message extraction
  - **Error Fields Checked:** `message`, `error`
- **Special Implementation:**
  - Uses `http.MultipartRequest` (not `ApiClient.post`)
  - Manually discovers base URL via health check
  - Manually adds Authorization header

#### 2. Pick Document (Local)
- **Endpoint:** None (local file picker)
- **Function:** `pickDocument()`
- **Authentication:** N/A
- **Returns:** `String?` (file path) or `null`
- **File Types:** PDF, PNG, JPG, JPEG
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Fallback to `FileType.any` if custom fails
  - ✅ File extension validation
  - ✅ File existence verification
  - ✅ User-friendly error messages
  - **Error Types Handled:**
    - Permission denied
    - Invalid file type
    - File path issues

#### 3. Get Verification Status
- **Endpoint:** `GET /api/mobile/auth/verification-status`
- **Function:** `getVerificationStatus()`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:** None
- **Response Expected:**
```dart
{
  "document_status": String ("pending" | "approved" | "rejected" | "no_document"),
  "message": String?,
  ...other status fields
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns default status on error (non-throwing)
  - ✅ Handles unauthenticated state
  - **Default Status:** `{document_status: "no_document", message: "..."}`

#### 4. Get Documents List
- **Endpoint:** `GET /api/mobile/auth/documents`
- **Function:** `getDocuments()`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:** None
- **Response Expected:**
```dart
{
  "documents": List<Map<String, dynamic>>?,
  "data": List<Map<String, dynamic>>?,
  ...or direct List
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns empty list on error (non-throwing)
  - ✅ Handles unauthenticated state
  - ✅ Handles multiple response formats

---

### Service: `lead_service.dart`

**Total Functions:** 10  
**Authentication Required:** Yes (all endpoints)  
**Caching:** ✅ Yes (2-minute TTL, cache key based on parameters)

#### 1. Get Leads
- **Endpoint:** `GET /api/mobile/leads`
- **Function:** `getLeads({status?, fromDate?, toDate?, limit?, forceRefresh?, excludeRejected?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Query Parameters:**
  - `status`: String? (lead status filter)
  - `from_date`: String? (ISO8601 date)
  - `to_date`: String? (ISO8601 date)
  - `limit`: int? (max results)
- **Response Expected:**
```dart
{
  "leads": List<Map<String, dynamic>>?,
  "data": List<Map<String, dynamic>>?,
  ...or direct List
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Cache fallback (stale cache if available)
  - ✅ Dummy data fallback for development
  - ✅ Rejected leads filtering
  - ✅ Handles multiple response formats
- **Caching:**
  - **TTL:** 2 minutes
  - **Cache Key:** `leads_{status}_{fromDate}_{toDate}_{limit}`
  - **Force Refresh:** Bypasses cache if `forceRefresh: true`
  - **Stale Cache:** Uses expired cache (up to 30 days) if API fails

#### 2. Get Lead Detail
- **Endpoint:** `GET /api/mobile/leads/:leadId`
- **Function:** `getLeadDetail(leadId)`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:** None
- **Response Expected:**
```dart
Map<String, dynamic> (lead object)
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns `null` on error (non-throwing)

#### 3. Update Lead Status
- **Endpoint:** `PUT /api/mobile/leads/:leadId/status`
- **Function:** `updateLeadStatus(leadId, status, {notes?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "status": String,
  "notes": String?
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns `false` on error (non-throwing)

#### 4. Mark Lead as Viewed
- **Endpoint:** `PUT /api/mobile/leads/:leadId/view`
- **Function:** `markAsViewed(leadId)`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:** `{}`
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns `false` on error (non-throwing)

#### 5. Track Phone Call
- **Endpoint:** `POST /api/mobile/leads/:leadId/call`
- **Function:** `trackCall(leadId)`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:** `{}`
- **Success Status Codes:** 200, 201
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns `false` on error (non-throwing)

#### 6. Add Notes
- **Endpoint:** `POST /api/mobile/leads/:leadId/notes`
- **Function:** `addNotes(leadId, notes)`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "notes": String
}
```
- **Success Status Codes:** 200, 201
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns `false` on error (non-throwing)

#### 7. Accept Lead
- **Endpoint:** `PUT /api/mobile/leads/:leadId/accept`
- **Function:** `acceptLead(leadId, {notes?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "notes": String?
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Clears cache on success
  - ✅ Returns `false` on error (non-throwing)
  - ✅ Error message extraction

#### 8. Mark Not Interested
- **Endpoint:** `PUT /api/mobile/leads/:leadId/reject`
- **Function:** `markNotInterested(leadId, {reason?, notes?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "status": "rejected",
  "reason": String?,
  "notes": String?
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Clears cache on success
  - ✅ Returns `false` on error (non-throwing)
  - ✅ Error message extraction

#### 9. Reject Lead
- **Endpoint:** `PUT /api/mobile/leads/:leadId/reject`
- **Function:** `rejectLead(leadId, {reason?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "reason": String?
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Clears cache on success
  - ✅ Returns `false` on error (non-throwing)
  - ✅ Error message extraction

#### 10. Clear Cache
- **Endpoint:** None (local operation)
- **Function:** `clearCache()`
- **Authentication:** N/A
- **Operations:** Clears all leads cache keys from `SharedPreferences`

#### 11. Mask Phone Number (Helper)
- **Endpoint:** None (utility function)
- **Function:** `maskPhoneNumber(phoneNumber)`
- **Returns:** Masked phone string (e.g., `21******01`)

---

### Service: `notification_service.dart`

**Total Functions:** 8  
**Authentication Required:** Yes (all endpoints)  
**Caching:** ✅ Yes (Local Storage via `SharedPreferences`)

#### 1. Get Settings
- **Endpoint:** `GET /api/mobile/notifications/settings`
- **Function:** `getSettings()`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:** None
- **Response Expected:**
```dart
{
  "push_enabled": bool?,
  "email_enabled": bool?,
  "sms_enabled": bool?,
  "sound_enabled": bool?,
  "vibration_enabled": bool?,
  "quiet_hours": Map<String, dynamic>?,
  "notification_types": List<String>?
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns local cached settings on error (non-throwing)
  - ✅ Fallback to individual preferences
- **Local Storage:** Saves to `SharedPreferences` (`notification_settings` key)

#### 2. Update Settings
- **Endpoint:** `PUT /api/mobile/notifications/settings`
- **Function:** `updateSettings({pushEnabled?, emailEnabled?, smsEnabled?, soundEnabled?, vibrationEnabled?, quietHours?, notificationTypes?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "push_enabled": bool?,
  "email_enabled": bool?,
  "sms_enabled": bool?,
  "sound_enabled": bool?,
  "vibration_enabled": bool?,
  "quiet_hours": Map<String, dynamic>?,
  "notification_types": List<String>?
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Saves locally even if backend fails
  - ✅ Returns `false` on error (non-throwing)
- **Local Storage:** 
  - Saves to `SharedPreferences` (`notification_settings` key)
  - Also saves individual preferences for backward compatibility

#### 3-7. Get Individual Settings (Local)
- **Functions:** `isPushEnabled()`, `isEmailEnabled()`, `isSmsEnabled()`, `isSoundEnabled()`, `isVibrationEnabled()`
- **Endpoint:** None (local storage only)
- **Data Source:** `SharedPreferences`
- **Returns:** `bool` (with defaults)

#### 8. Sync Settings
- **Endpoint:** None (calls `getSettings()` and `updateSettings()`)
- **Function:** `syncSettings()`
- **Operations:**
  - Fetches from backend
  - If backend fails, pushes local settings to backend
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Non-throwing

---

### Service: `subscription_service.dart`

**Total Functions:** 8  
**Authentication Required:** Varies by endpoint

#### 1. Get Plans
- **Endpoint:** `GET /api/mobile/subscription/plans`
- **Function:** `getPlans({activeOnly?})`
- **Authentication:** ❌ No (`requireAuth: false`)
- **Query Parameters:**
  - `isActive`: bool? (if `activeOnly: true`)
- **Response Expected:**
```dart
{
  "plans": List<Map<String, dynamic>>?,
  "data": List<Map<String, dynamic>>?,
  "data.plans": List<Map<String, dynamic>>?,
  ...or direct List
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns empty list on error (non-throwing)
  - ✅ Handles multiple response formats
  - ✅ Filters active plans if `activeOnly: true`
- **Active Plan Detection:** Checks `is_active`, `active`, `status`, `isActive` fields

#### 2. Subscribe
- **Endpoint:** `POST /api/mobile/subscription/subscribe`
- **Function:** `subscribe({planId, paymentMethodId?, additionalData?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "plan_id": String,
  "payment_method_id": String?,
  ...additionalData
}
```
- **Response Expected:**
```dart
{
  "success": bool?,
  "subscription": Map<String, dynamic>?,
  "message": String?
}
```
- **Success Status Codes:** 200, 201
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Error message extraction
  - **Error Fields Checked:** `message`, `error`

#### 3. Get Subscription
- **Endpoint:** `GET /api/mobile/subscription`
- **Function:** `getSubscription()`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:** None
- **Response Expected:**
```dart
{
  "subscription": Map<String, dynamic>?,
  "data": Map<String, dynamic>?,
  ...or direct Map
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns `null` on error (non-throwing)
  - ✅ Handles multiple response formats

#### 4. Upgrade Subscription
- **Endpoint:** `PUT /api/mobile/subscription/upgrade`
- **Function:** `upgrade({planId, prorated?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "plan_id": String,
  "prorated": bool (default: true)
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Error message extraction
  - **Error Fields Checked:** `message`, `error`

#### 5. Downgrade Subscription
- **Endpoint:** `PUT /api/mobile/subscription/downgrade`
- **Function:** `downgrade({planId, immediate?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "plan_id": String,
  "immediate": bool (default: false)
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Error message extraction
  - **Error Fields Checked:** `message`, `error`

#### 6. Cancel Subscription
- **Endpoint:** `POST /api/mobile/subscription/cancel`
- **Function:** `cancel({reason?, immediate?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "reason": String?,
  "immediate": bool (default: false)
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Error message extraction
  - **Error Fields Checked:** `message`, `error`

#### 7. Get Invoices
- **Endpoint:** `GET /api/mobile/subscription/invoices`
- **Function:** `getInvoices({page?, limit?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Query Parameters:**
  - `page`: int?
  - `limit`: int?
- **Response Expected:**
```dart
{
  "invoices": List<Map<String, dynamic>>?,
  "data": List<Map<String, dynamic>>?,
  ...or direct List
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns empty list on error (non-throwing)
  - ✅ Handles multiple response formats

#### 8. Update Payment Method
- **Endpoint:** `PUT /api/mobile/payment-method`
- **Function:** `updatePaymentMethod({paymentMethodId, cardDetails?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "payment_method_id": String,
  ...cardDetails
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Error message extraction
  - **Error Fields Checked:** `message`, `error`

---

### Service: `territory_service.dart`

**Total Functions:** 6  
**Authentication Required:** Yes (all endpoints)  
**Caching:** ✅ Yes (Local Storage via `SharedPreferences`)

#### 1. Get Zipcodes
- **Endpoint:** `GET /api/mobile/territories`
- **Function:** `getZipcodes()`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:** None
- **Response Expected:**
```dart
{
  "zipcodes": List<String>
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns local cached zipcodes on error (non-throwing)
- **Local Storage:** Saves to `SharedPreferences` (`user_zipcodes` key)

#### 2. Add Zipcode
- **Endpoint:** `POST /api/mobile/territories`
- **Function:** `addZipcode(zipcode, {city?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "zipcode": String,
  "city": String?
}
```
- **Success Status Codes:** 200, 201
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Saves locally even if backend fails
  - ✅ Handles 409 (already exists)
  - ✅ Handles 403 (limit reached)
  - ✅ Returns `false` on error (non-throwing)
- **Local Storage:** Adds to `SharedPreferences` (`user_zipcodes` key, format: `zipcode|city` or `zipcode`)

#### 3. Update Territory
- **Endpoint:** `PUT /api/mobile/territories/:territoryId`
- **Function:** `updateTerritory({territoryId, zipcode?, city?, additionalData?})`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:**
```dart
{
  "zipcode": String?,
  "city": String?,
  ...additionalData
}
```
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns `false` on error (non-throwing)

#### 4. Remove Territory
- **Endpoint:** `DELETE /api/mobile/territories/:territoryId`
- **Function:** `removeTerritory(territoryId)`
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Request Body:** None
- **Success Status Code:** 200
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Returns `false` on error (non-throwing)

#### 5. Remove Zipcode (Deprecated)
- **Endpoint:** `DELETE /api/mobile/territories/:zipcode`
- **Function:** `removeZipcode(zipcode)` ⚠️ **DEPRECATED**
- **Authentication:** ✅ Yes (`requireAuth: true`)
- **Note:** Use `removeTerritory(territoryId)` instead
- **Local Storage:** Removes from `SharedPreferences`

#### 6. Sync Zipcodes
- **Endpoint:** None (calls `getZipcodes()`)
- **Function:** `syncZipcodes()`
- **Operations:** Fetches from backend and saves locally
- **Error Handling:**
  - ✅ Try-catch present
  - ✅ Non-throwing

---

## 4. MOBILE-TO-BACKEND ENDPOINT MAPPING

| Mobile Service Call | Backend Endpoint | HTTP Method | Auth Required | Backend Controller Expected |
|--------------------|------------------|-------------|---------------|----------------------------|
| `AuthService.register()` | `/api/mobile/auth/register` | POST | ❌ No | `mobileAuthController.register` |
| `AuthService.verifyEmail()` | `/api/mobile/auth/verify-email` | POST | ✅ Yes | `mobileAuthController.verifyEmail` |
| `AuthService.login()` | `/api/mobile/auth/login` | POST | ❌ No | `mobileAuthController.login` |
| `AuthService.forgotPassword()` | `/api/mobile/auth/forgot-password` | POST | ❌ No | `mobileAuthController.forgotPassword` |
| `AuthService.verifyResetCode()` | `/api/mobile/auth/verify-reset-code` | POST | ❌ No | `mobileAuthController.verifyResetCode` |
| `AuthService.resetPassword()` | `/api/mobile/auth/reset-password` | POST | ❌ No | `mobileAuthController.resetPassword` |
| `AuthService.registerDevice()` | `/api/mobile/auth/register-device` | POST | ✅ Yes | `mobileAuthController.registerDevice` |
| `AuthService.updateDevice()` | `/api/mobile/auth/update-device` | PUT | ✅ Yes | `mobileAuthController.updateDevice` |
| `AuthService.unregisterDevice()` | `/api/mobile/auth/unregister-device` | DELETE | ✅ Yes | `mobileAuthController.unregisterDevice` |
| `DocumentVerificationService.uploadDocument()` | `/api/mobile/auth/upload-document` | POST | ✅ Yes | `mobileAuthController.uploadDocument` |
| `DocumentVerificationService.getVerificationStatus()` | `/api/mobile/auth/verification-status` | GET | ✅ Yes | `mobileAuthController.getVerificationStatus` |
| `DocumentVerificationService.getDocuments()` | `/api/mobile/auth/documents` | GET | ✅ Yes | `mobileAuthController.getDocuments` |
| `LeadService.getLeads()` | `/api/mobile/leads` | GET | ✅ Yes | `mobileLeadController.getLeads` |
| `LeadService.getLeadDetail()` | `/api/mobile/leads/:leadId` | GET | ✅ Yes | `mobileLeadController.getLeadDetail` |
| `LeadService.updateLeadStatus()` | `/api/mobile/leads/:leadId/status` | PUT | ✅ Yes | `mobileLeadController.updateLeadStatus` |
| `LeadService.markAsViewed()` | `/api/mobile/leads/:leadId/view` | PUT | ✅ Yes | `mobileLeadController.markAsViewed` |
| `LeadService.trackCall()` | `/api/mobile/leads/:leadId/call` | POST | ✅ Yes | `mobileLeadController.trackCall` |
| `LeadService.addNotes()` | `/api/mobile/leads/:leadId/notes` | POST | ✅ Yes | `mobileLeadController.addNotes` |
| `LeadService.acceptLead()` | `/api/mobile/leads/:leadId/accept` | PUT | ✅ Yes | `mobileLeadController.acceptLead` |
| `LeadService.markNotInterested()` | `/api/mobile/leads/:leadId/reject` | PUT | ✅ Yes | `mobileLeadController.rejectLead` |
| `LeadService.rejectLead()` | `/api/mobile/leads/:leadId/reject` | PUT | ✅ Yes | `mobileLeadController.rejectLead` |
| `NotificationService.getSettings()` | `/api/mobile/notifications/settings` | GET | ✅ Yes | `mobileNotificationController.getSettings` |
| `NotificationService.updateSettings()` | `/api/mobile/notifications/settings` | PUT | ✅ Yes | `mobileNotificationController.updateSettings` |
| `SubscriptionService.getPlans()` | `/api/mobile/subscription/plans` | GET | ❌ No | `mobileSubscriptionController.getPlans` |
| `SubscriptionService.subscribe()` | `/api/mobile/subscription/subscribe` | POST | ✅ Yes | `mobileSubscriptionController.subscribe` |
| `SubscriptionService.getSubscription()` | `/api/mobile/subscription` | GET | ✅ Yes | `mobileSubscriptionController.getSubscription` |
| `SubscriptionService.upgrade()` | `/api/mobile/subscription/upgrade` | PUT | ✅ Yes | `mobileSubscriptionController.upgrade` |
| `SubscriptionService.downgrade()` | `/api/mobile/subscription/downgrade` | PUT | ✅ Yes | `mobileSubscriptionController.downgrade` |
| `SubscriptionService.cancel()` | `/api/mobile/subscription/cancel` | POST | ✅ Yes | `mobileSubscriptionController.cancel` |
| `SubscriptionService.getInvoices()` | `/api/mobile/subscription/invoices` | GET | ✅ Yes | `mobileSubscriptionController.getInvoices` |
| `SubscriptionService.updatePaymentMethod()` | `/api/mobile/payment-method` | PUT | ✅ Yes | `mobilePaymentController.updatePaymentMethod` |
| `TerritoryService.getZipcodes()` | `/api/mobile/territories` | GET | ✅ Yes | `mobileTerritoryController.getZipcodes` |
| `TerritoryService.addZipcode()` | `/api/mobile/territories` | POST | ✅ Yes | `mobileTerritoryController.addZipcode` |
| `TerritoryService.updateTerritory()` | `/api/mobile/territories/:territoryId` | PUT | ✅ Yes | `mobileTerritoryController.updateTerritory` |
| `TerritoryService.removeTerritory()` | `/api/mobile/territories/:territoryId` | DELETE | ✅ Yes | `mobileTerritoryController.removeTerritory` |

**Total Endpoints:** 37

---

## 5. DATA MODELS USED

| Model/Class | Fields | Used in Services | Matches Backend Schema |
|------------|--------|-----------------|----------------------|
| **User Profile** | `agency_id`, `id`, `email`, `agency_name`, `phone`, ... | `AuthService` | ✅ Assumed (normalized via `data` wrapper) |
| **Lead** | `id`, `first_name`, `last_name`, `phone`, `email`, `zipcode`, `city`, `state`, `address`, `age`, `industry`, `service_type`, `status`, `urgency_level`, `source`, `created_at`, `updated_at`, `notes`, `preferred_contact_time`, `budget`, `timeline` | `LeadService` | ✅ Assumed (multiple response formats handled) |
| **Document** | `id`, `document_type`, `file_path`, `status`, `uploaded_at`, ... | `DocumentVerificationService` | ✅ Assumed (multiple response formats handled) |
| **Subscription Plan** | `id`, `name`, `price`, `features`, `is_active`, `active`, `status`, `isActive`, ... | `SubscriptionService` | ✅ Assumed (multiple response formats handled) |
| **Subscription** | `id`, `plan_id`, `status`, `start_date`, `end_date`, ... | `SubscriptionService` | ✅ Assumed (multiple response formats handled) |
| **Notification Settings** | `push_enabled`, `email_enabled`, `sms_enabled`, `sound_enabled`, `vibration_enabled`, `quiet_hours`, `notification_types` | `NotificationService` | ✅ Assumed |
| **Territory** | `id`, `zipcode`, `city`, ... | `TerritoryService` | ✅ Assumed |

**Note:** All models are handled as `Map<String, dynamic>` for flexibility. Services handle multiple response formats (direct objects, wrapped in `data`, wrapped in named keys).

---

## 6. ERROR HANDLING MATRIX

| Service Function | Network Errors | Validation Errors | Auth Errors | Server Errors | Timeout Errors |
|-----------------|----------------|------------------|-------------|---------------|----------------|
| `AuthService.register()` | ✅ Exception | ✅ Exception (detailed) | N/A | ✅ Exception | ✅ Exception |
| `AuthService.verifyEmail()` | ✅ Exception | ✅ Exception | ✅ Exception | ✅ Exception | ✅ Exception |
| `AuthService.login()` | ✅ Exception | ✅ Exception (mapped) | ✅ Exception (mapped) | ✅ Exception | ✅ Exception |
| `AuthService.forgotPassword()` | ✅ Exception | ✅ Exception | N/A | ✅ Exception | ✅ Exception |
| `AuthService.verifyResetCode()` | ✅ Exception | ✅ Exception | N/A | ✅ Exception | ✅ Exception |
| `AuthService.resetPassword()` | ✅ Exception | ✅ Exception (client-side validation) | N/A | ✅ Exception | ✅ Exception |
| `AuthService.registerDevice()` | ✅ Returns false | ✅ Returns false | ✅ Returns false | ✅ Returns false | ✅ Returns false |
| `DocumentVerificationService.uploadDocument()` | ✅ Exception | ✅ Exception (file validation) | ✅ Exception | ✅ Exception | ✅ Exception |
| `DocumentVerificationService.getVerificationStatus()` | ✅ Returns default | ✅ Returns default | ✅ Returns default | ✅ Returns default | ✅ Returns default |
| `DocumentVerificationService.getDocuments()` | ✅ Returns empty list | ✅ Returns empty list | ✅ Returns empty list | ✅ Returns empty list | ✅ Returns empty list |
| `LeadService.getLeads()` | ✅ Cache fallback | ✅ Cache fallback | ✅ Cache fallback | ✅ Cache fallback | ✅ Cache fallback |
| `LeadService.getLeadDetail()` | ✅ Returns null | ✅ Returns null | ✅ Returns null | ✅ Returns null | ✅ Returns null |
| `LeadService.updateLeadStatus()` | ✅ Returns false | ✅ Returns false | ✅ Returns false | ✅ Returns false | ✅ Returns false |
| `LeadService.acceptLead()` | ✅ Returns false | ✅ Returns false | ✅ Returns false | ✅ Returns false | ✅ Returns false |
| `NotificationService.getSettings()` | ✅ Local cache | ✅ Local cache | ✅ Local cache | ✅ Local cache | ✅ Local cache |
| `NotificationService.updateSettings()` | ✅ Local save | ✅ Local save | ✅ Local save | ✅ Local save | ✅ Local save |
| `SubscriptionService.getPlans()` | ✅ Returns empty list | ✅ Returns empty list | N/A | ✅ Returns empty list | ✅ Returns empty list |
| `SubscriptionService.subscribe()` | ✅ Exception | ✅ Exception | ✅ Exception | ✅ Exception | ✅ Exception |
| `TerritoryService.getZipcodes()` | ✅ Local cache | ✅ Local cache | ✅ Local cache | ✅ Local cache | ✅ Local cache |
| `TerritoryService.addZipcode()` | ✅ Local save | ✅ Local save | ✅ Local save | ✅ Local save | ✅ Local save |

**Error Handling Patterns:**
- **Throwing Functions:** Auth operations, critical operations (register, login, subscribe)
- **Non-Throwing Functions:** Device operations, lead operations (returns `false` or `null`)
- **Fallback Functions:** Lead service (cache), notification service (local storage), territory service (local storage)

---

## 7. DATA FLOW DOCUMENTATION

### Authentication Flow
```
UI Input → AuthService.login(email, password)
  → Normalize email (trim, lowercase)
  → Normalize password (trim)
  → Clear existing token
  → ApiClient.post('/api/mobile/auth/login', body, requireAuth: false)
    → Discover base URL (health check)
    → Build headers (no Authorization header)
    → HTTP POST request
    → Parse response
  → Extract token from response
  → Save token to SecureStorageService
  → Parse user profile (handle data wrapper)
  → Save profile to SharedPreferences
  → Save agency_id to SharedPreferences
  → Return decoded response
```

### Lead Fetching Flow (with Caching)
```
UI Request → LeadService.getLeads({status, fromDate, toDate, limit})
  → Build cache key from parameters
  → Check CacheService (2-minute TTL)
    → If cached and valid: return cached data
    → If forceRefresh: skip cache
  → Build query string from parameters
  → ApiClient.get('/api/mobile/leads?params', requireAuth: true)
    → Discover base URL
    → Add Authorization header (Bearer token)
    → HTTP GET request
    → Parse response
  → Handle multiple response formats (leads, data, direct list)
  → Filter rejected leads (if excludeRejected: true)
  → Cache results via CacheService
  → Return filtered leads
  → On error: return stale cache or dummy data
```

### Document Upload Flow
```
UI File Selection → DocumentVerificationService.pickDocument()
  → FilePicker.platform.pickFiles()
  → Validate file extension
  → Verify file exists
  → Return file path

UI Upload → DocumentVerificationService.uploadDocument({agencyId, filePath})
  → Validate file (size, extension)
  → Discover base URL (manual health check)
  → Get JWT token from ApiClient
  → Create MultipartRequest
  → Add Authorization header manually
  → Add file as multipart
  → Add form fields (agency_id, document_type, description)
  → Send request
  → Parse response
  → Return decoded response
```

---

## 8. MISSING IMPLEMENTATIONS

### Critical Missing Features
1. **Token Refresh Mechanism**
   - ❌ No automatic token refresh on 401 responses
   - ❌ No refresh token handling
   - **Impact:** Users must re-login when token expires

2. **Request Retry Logic**
   - ❌ No automatic retry on network failures
   - ❌ No exponential backoff
   - **Impact:** Temporary network issues cause immediate failures

3. **Request Cancellation**
   - ❌ No request cancellation support
   - **Impact:** Cannot cancel long-running requests

4. **Response Interceptors**
   - ❌ No global response interceptors
   - **Impact:** Cannot handle common errors globally (e.g., 401, 403)

### Incomplete Error Handling
1. **Timeout Handling**
   - ⚠️ Timeout errors are caught but generic message shown
   - **Recommendation:** Add specific timeout error types

2. **Network Connectivity Check**
   - ⚠️ No explicit network connectivity check before requests
   - **Recommendation:** Add connectivity check via `connectivity_plus` package

3. **Rate Limiting Handling**
   - ❌ No handling for 429 (Too Many Requests) responses
   - **Recommendation:** Add rate limit detection and backoff

### Security Concerns
1. **Token Storage**
   - ✅ Uses secure storage (good)
   - ⚠️ No token encryption verification
   - **Recommendation:** Verify secure storage implementation

2. **Sensitive Data Logging**
   - ⚠️ Passwords logged in debug (length only - acceptable)
   - ⚠️ Email addresses logged (acceptable for debugging)
   - **Recommendation:** Disable sensitive logging in production

3. **Certificate Pinning**
   - ❌ No SSL certificate pinning
   - **Recommendation:** Add certificate pinning for production

### Performance Optimizations
1. **Request Batching**
   - ❌ No request batching support
   - **Recommendation:** Batch multiple requests when possible

2. **Image Caching**
   - ❌ No image/document caching
   - **Recommendation:** Add image caching for document previews

3. **Pagination**
   - ⚠️ Limited pagination support (only in `getInvoices`)
   - **Recommendation:** Add pagination to `getLeads` and other list endpoints

---

## 9. RECOMMENDATIONS

### Security Improvements
1. **Implement Token Refresh**
   - Add refresh token mechanism
   - Automatically refresh expired tokens
   - Handle refresh failures gracefully

2. **Add Certificate Pinning**
   - Pin SSL certificates for production
   - Prevent man-in-the-middle attacks

3. **Enhance Error Messages**
   - Don't expose internal error details to users
   - Provide user-friendly error messages
   - Log detailed errors server-side only

### Error Handling Enhancements
1. **Implement Retry Logic**
   - Add automatic retry for transient failures
   - Use exponential backoff
   - Limit retry attempts

2. **Add Network Connectivity Check**
   - Check connectivity before making requests
   - Show appropriate offline messages
   - Queue requests when offline

3. **Handle Rate Limiting**
   - Detect 429 responses
   - Implement backoff strategy
   - Show user-friendly rate limit messages

### Performance Optimizations
1. **Add Request Batching**
   - Batch multiple API calls when possible
   - Reduce network round trips

2. **Implement Image Caching**
   - Cache document previews
   - Cache profile images
   - Use appropriate cache sizes

3. **Add Pagination Support**
   - Implement pagination for all list endpoints
   - Load data incrementally
   - Improve initial load times

### Code Quality Improvements
1. **Standardize Error Handling**
   - Create custom exception classes
   - Standardize error response format
   - Add error code mapping

2. **Add Request/Response Logging**
   - Add structured logging
   - Log request/response for debugging
   - Disable in production builds

3. **Improve Type Safety**
   - Create model classes instead of `Map<String, dynamic>`
   - Add JSON serialization
   - Improve compile-time type checking

### Testing Recommendations
1. **Add Unit Tests**
   - Test service methods
   - Test error handling
   - Test data transformations

2. **Add Integration Tests**
   - Test API client
   - Test authentication flow
   - Test caching mechanisms

3. **Add Mock Backend**
   - Create mock backend for testing
   - Test offline scenarios
   - Test error scenarios

---

## 10. API ENDPOINT SUMMARY

### Public Endpoints (No Authentication)
- `POST /api/mobile/auth/register`
- `POST /api/mobile/auth/login`
- `POST /api/mobile/auth/forgot-password`
- `POST /api/mobile/auth/verify-reset-code`
- `POST /api/mobile/auth/reset-password`
- `GET /api/mobile/subscription/plans`

### Protected Endpoints (JWT Required)
- All other endpoints require JWT token in `Authorization: Bearer {token}` header

### Endpoint Categories
- **Authentication:** 9 endpoints
- **Document Verification:** 3 endpoints
- **Lead Management:** 9 endpoints
- **Notifications:** 2 endpoints
- **Subscriptions:** 8 endpoints
- **Territories:** 4 endpoints

---

**End of Audit Report**


