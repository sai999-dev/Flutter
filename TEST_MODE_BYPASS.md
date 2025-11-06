# 🧪 Test Mode - Authentication Bypass

## Overview

The app now includes a **Test Mode** that bypasses backend authentication, allowing you to test the app without a running backend server or valid credentials.

## How to Use Test Mode

### Quick Test Login

1. **Open the login page**
2. **Click the orange "Use Test Credentials" button**
3. **App automatically:**
   - Fills in test credentials
   - Creates a mock JWT token
   - Saves mock user data
   - Enables test mode
   - Logs you in instantly

### Test Credentials

**Email:** `test@example.com`  
**Password:** `test123456`  
*(These are auto-filled - no backend authentication required)*

## What Test Mode Does

### ✅ Bypasses Authentication

- **No backend server required** - Test mode works offline
- **No API calls** - Mock data is used instead
- **Mock JWT token** - Generated automatically
- **Mock user data** - Pre-configured test profile

### ✅ Mock Data Created

When you use test credentials, the app creates:

```dart
{
  'agency_id': 'test_agency_123',
  'email': 'test@example.com',
  'agency_name': 'Test Agency',
  'contact_name': 'Test User',
  'user_name': 'Test User',
  'zipcodes': ['75201', '75033', '75001'],
  'subscription_plan': 'Premium',
  'monthly_price': 199.0
}
```

### ✅ API Calls Bypassed

In test mode:
- **GET requests** return `null` (services use dummy data)
- **POST requests** return `null` (services handle gracefully)
- **Authentication checks** are bypassed
- **Backend connection** is skipped

## Services That Work in Test Mode

### Leads Service
- Returns dummy leads when API is unavailable
- Already implemented in `LeadService._getDummyLeads()`

### Subscription Service
- Shows empty state when API is unavailable
- Plans can be tested with mock data

### Territory Service
- Uses cached zipcodes from SharedPreferences
- Test mode provides default zipcodes: `['75201', '75033', '75001']`

## Test Mode Indicators

### Visual Indicators

1. **Orange Snackbar Message:**
   ```
   🧪 Test Mode: Logged in with mock credentials (No backend required)
   ```

2. **Console Logs:**
   ```
   🧪 Using test credentials - Bypassing authentication
   ✅ Mock JWT token saved: test_jwt_token_...
   ✅ Test mode enabled - Using mock authentication
   🧪 Test mode: Skipping backend connection check for GET /api/...
   ```

### Storage Indicators

- `test_mode: true` in SharedPreferences
- Mock token in secure storage
- Mock user profile data saved

## Disabling Test Mode

### Method 1: Logout
- Logout from the app
- Test mode is cleared on logout

### Method 2: Manual Clear
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('test_mode', false);
```

### Method 3: Clear App Data
- Uninstall and reinstall app
- Or clear app data from device settings

## API Client Behavior in Test Mode

### Before (Normal Mode)
```dart
ApiClient.get('/api/mobile/leads', requireAuth: true)
// 1. Checks if token exists
// 2. Connects to backend
// 3. Makes API call
// 4. Returns response
```

### After (Test Mode)
```dart
ApiClient.get('/api/mobile/leads', requireAuth: true)
// 1. Checks test mode
// 2. Returns null immediately (no backend call)
// 3. Service uses dummy data
```

## Service Layer Handling

### LeadService Example

```dart
final response = await ApiClient.get('/api/mobile/leads');

if (response == null) {
  // In test mode, use dummy leads
  return _getDummyLeads();
}
```

### SubscriptionService Example

```dart
final response = await ApiClient.get('/api/mobile/subscription/plans');

if (response == null) {
  // Show empty state or use mock data
  return [];
}
```

## Testing Scenarios

### Scenario 1: No Backend Server
✅ **Test mode works** - No connection needed

### Scenario 2: Backend Server Running
✅ **Test mode works** - Bypasses backend anyway

### Scenario 3: Invalid Credentials
✅ **Test mode works** - No credential validation

### Scenario 4: Network Issues
✅ **Test mode works** - No network required

## Security Notes

⚠️ **IMPORTANT: Test Mode is for Development Only!**

- **Never enable in production**
- **Remove test credentials button before release**
- **Test mode bypasses all security checks**
- **Mock tokens are not validated**

## Production Checklist

Before releasing to production:

- [ ] Remove "Use Test Credentials" button
- [ ] Remove `_useTestCredentials()` method
- [ ] Remove test mode bypass logic
- [ ] Ensure all API calls require authentication
- [ ] Test with real backend authentication

## Code Locations

### Test Credentials Button
- **File:** `flutter-frontend/lib/main.dart`
- **Method:** `_useTestCredentials()`
- **Line:** ~156-245

### Test Mode Check
- **File:** `flutter-backend/lib/services/api_client.dart`
- **Method:** `isTestMode()`
- **Line:** ~94-97

### Authentication Bypass
- **File:** `flutter-backend/lib/services/api_client.dart`
- **Methods:** `get()`, `post()`, `put()`, `delete()`
- **Lines:** ~165-235

## Troubleshooting

### Test Mode Not Working

**Check:**
1. Is `test_mode` set to `true` in SharedPreferences?
2. Are console logs showing "🧪 Test mode" messages?
3. Is the mock token saved correctly?

### Still Getting Authentication Errors

**Solution:**
- Ensure test mode is enabled before making API calls
- Check that `isTestMode()` returns `true`
- Verify mock token is saved

### Want to Test with Real Backend

**Solution:**
- Don't use test credentials button
- Use regular login with valid credentials
- Test mode will be `false`

---

**Last Updated:** 2025-11-03  
**Status:** ✅ Test Mode Authentication Bypass Implemented

