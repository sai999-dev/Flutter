# 🔧 Authentication & Registration Troubleshooting Guide

## Common Issues & Solutions

### Issue 1: "No backend server available"

**Error Message:**
```
Registration failed: No backend server available
Login failed: No backend server available
```

**Causes:**
- Backend server is not running
- Wrong port (not 3000, 3001, or 3002)
- Backend server crashed
- Network connectivity issues

**Solutions:**
1. **Start the backend server:**
   ```bash
   cd super-admin-backend
   npm start
   ```

2. **Verify server is running:**
   - Check terminal for "Server running on port 3000" (or 3001, 3002)
   - Open browser: `http://localhost:3000/api/health`
   - Should return: `{"status": "ok"}` or similar

3. **Check health endpoint:**
   ```
   GET http://localhost:3000/api/health
   ```

4. **Clear cached URL:**
   - The app caches the working backend URL
   - If you changed ports, restart the app to clear cache

---

### Issue 2: "Registration failed" (400/409 Status)

**Error Message:**
```
Registration failed: Email already exists
Registration failed: Invalid email format
```

**Causes:**
- Email already registered
- Invalid email format
- Missing required fields
- Password doesn't meet requirements

**Solutions:**
1. **Check email format:**
   - Must be valid email: `user@example.com`
   - No spaces or special characters

2. **Use different email:**
   - Try a new email if "Email already exists"

3. **Check required fields:**
   - Agency name (required)
   - Contact name (required)
   - Email (required, valid format)
   - Password (required, min 6 characters)
   - Phone (optional but recommended)

4. **Check backend validation:**
   - Backend may have stricter password requirements
   - Check backend logs for specific validation errors

---

### Issue 3: "Login failed" (401 Status)

**Error Message:**
```
Login failed: Invalid credentials
Login failed: Authentication failed
```

**Causes:**
- Wrong email/password
- Account doesn't exist
- Account not activated
- Password incorrect

**Solutions:**
1. **Verify credentials:**
   - Check email spelling
   - Check password (case-sensitive)
   - Try resetting password

2. **Check if account exists:**
   - Try registering with same email
   - If "Email already exists", account exists

3. **Check backend logs:**
   - Backend may have specific error messages
   - Check for account activation requirements

---

### Issue 4: "Connection timeout"

**Error Message:**
```
Connection timeout. Please check your internet connection.
```

**Causes:**
- Slow network connection
- Backend server overloaded
- Firewall blocking requests
- Backend server not responding

**Solutions:**
1. **Check internet connection:**
   - Verify network is working
   - Try accessing backend in browser

2. **Increase timeout:**
   - Currently set to 10 seconds
   - Can be increased in `api_client.dart`

3. **Check firewall:**
   - Ensure localhost connections are allowed
   - Check antivirus isn't blocking

---

### Issue 5: "Invalid JSON response"

**Error Message:**
```
Registration failed (Status: 500)
Login failed - Invalid JSON response
```

**Causes:**
- Backend returning HTML error page instead of JSON
- Backend crashed
- Invalid response format
- CORS issues

**Solutions:**
1. **Check backend logs:**
   - Look for error messages
   - Check for crashes or exceptions

2. **Verify endpoint exists:**
   - Ensure `/api/mobile/auth/register` exists
   - Ensure `/api/mobile/auth/login` exists

3. **Check CORS configuration:**
   - Backend must allow requests from mobile app
   - Check CORS headers in backend

---

## 🔍 Debugging Steps

### Step 1: Check Backend Server Status

```bash
# Terminal 1: Start backend
cd super-admin-backend
npm start

# Terminal 2: Test health endpoint
curl http://localhost:3000/api/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-11-03T..."
}
```

### Step 2: Test Registration Endpoint

```bash
curl -X POST http://localhost:3000/api/mobile/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123456",
    "agency_name": "Test Agency",
    "contact_name": "Test User",
    "phone": "+1234567890",
    "zipcodes": ["75201"],
    "industry": "Healthcare"
  }'
```

**Expected Response (Success):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "agency_id": "agency_123",
  "user_profile": {
    "email": "test@example.com",
    "agency_name": "Test Agency"
  }
}
```

**Expected Response (Error):**
```json
{
  "error": "Email already exists",
  "message": "An account with this email already exists",
  "statusCode": 409
}
```

### Step 3: Test Login Endpoint

```bash
curl -X POST http://localhost:3000/api/mobile/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123456"
  }'
```

**Expected Response (Success):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "data": {
    "agency_id": "agency_123",
    "email": "test@example.com",
    "agency_name": "Test Agency"
  }
}
```

### Step 4: Check Mobile App Logs

**Flutter Console Output:**
```
🔐 Registering new agency: test@example.com
✅ Connected to backend: http://127.0.0.1:3000 (for endpoint: /api/mobile/auth/register)
📋 Response data: {token: ..., agency_id: ...}
✅ Registration successful
```

**If Error:**
```
❌ Registration failed: Email already exists
❌ Status code: 409
❌ Response body: {"error": "Email already exists"}
```

---

## 🛠️ Enhanced Error Handling

### Registration Error Handling

**Added:**
- Detailed error logging
- Status code logging
- Response body logging
- User-friendly error messages
- Specific error detection (email, password, server)

**Error Messages:**
- "Backend server is not running. Please start the server."
- "Email already exists or is invalid. Please use a different email."
- "Password does not meet requirements."
- "Connection timeout. Please check your internet connection."

### Login Error Handling

**Added:**
- Detailed error logging
- Status code logging
- Response body logging
- User-friendly error messages
- Server availability detection

**Error Messages:**
- "Backend server is not running. Please start the server."
- "Invalid credentials. Please check your email and password."
- "Connection timeout. Please check your internet connection."

---

## ✅ Verification Checklist

### Registration Test
- [ ] Backend server is running
- [ ] Health endpoint responds: `GET /api/health`
- [ ] Registration endpoint exists: `POST /api/mobile/auth/register`
- [ ] Email format is valid
- [ ] Password meets requirements (min 6 characters)
- [ ] All required fields are filled
- [ ] Zipcodes are selected (at least 1)
- [ ] Plan is selected

### Login Test
- [ ] Backend server is running
- [ ] Health endpoint responds: `GET /api/health`
- [ ] Login endpoint exists: `POST /api/mobile/auth/login`
- [ ] Email is correct
- [ ] Password is correct
- [ ] Account exists in database

---

## 🔐 Authentication Flow Debug

### Registration Flow
```
1. User fills form → Validates locally
2. Calls AuthService.register()
3. ApiClient.post('/api/mobile/auth/register')
4. Finds working backend URL (health check)
5. Sends request with body
6. Receives response
7. If 200/201: Save token, navigate to home
8. If error: Show error message
```

### Login Flow
```
1. User enters email/password
2. Calls AuthService.login()
3. ApiClient.post('/api/mobile/auth/login')
4. Finds working backend URL (health check)
5. Sends request with credentials
6. Receives response
7. If 200/201: Save token, sync zipcodes, navigate to home
8. If error: Show error message
```

---

## 📝 Backend Requirements

### Registration Endpoint: `POST /api/mobile/auth/register`

**Required Request Body:**
```json
{
  "email": "string (required, valid email)",
  "password": "string (required, min 6 chars)",
  "agency_name": "string (required)",
  "contact_name": "string (required)",
  "phone": "string (optional)",
  "business_name": "string (optional)",
  "zipcodes": ["string array"],
  "industry": "string (optional)",
  "plan_id": "string (optional)"
}
```

**Success Response (200/201):**
```json
{
  "token": "JWT token string",
  "agency_id": "string",
  "user_profile": {
    "email": "string",
    "agency_name": "string"
  }
}
```

**Error Response (400/409):**
```json
{
  "error": "Error message",
  "message": "Detailed error description",
  "statusCode": 400
}
```

### Login Endpoint: `POST /api/mobile/auth/login`

**Required Request Body:**
```json
{
  "email": "string (required)",
  "password": "string (required)"
}
```

**Success Response (200):**
```json
{
  "token": "JWT token string",
  "data": {
    "agency_id": "string",
    "email": "string",
    "agency_name": "string",
    "contact_name": "string"
  }
}
```

**Error Response (401):**
```json
{
  "error": "Invalid credentials",
  "message": "Email or password is incorrect",
  "statusCode": 401
}
```

---

## 🚨 Quick Fixes

### Fix 1: Backend Not Running
```bash
# Check if backend is running
curl http://localhost:3000/api/health

# If not responding, start backend
cd super-admin-backend
npm start
```

### Fix 2: Wrong Port
```bash
# Check which port backend is using
# Look in backend terminal output

# Or try different ports
curl http://localhost:3001/api/health
curl http://localhost:3002/api/health
```

### Fix 3: Clear App Cache
```dart
// In app, clear cached backend URL
await ApiClient.clearCachedUrl();
```

### Fix 4: Check Network
- Ensure mobile device/emulator can reach localhost
- For Android emulator: Use `10.0.2.2` instead of `localhost`
- For iOS simulator: Use `localhost` or `127.0.0.1`

---

## 📊 Debugging Commands

### Check Backend Status
```bash
# Health check
curl http://localhost:3000/api/health

# Test registration
curl -X POST http://localhost:3000/api/mobile/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123","agency_name":"Test"}'

# Test login
curl -X POST http://localhost:3000/api/mobile/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123"}'
```

### Check Mobile App Logs
```bash
# Run Flutter app with verbose logging
flutter run -v

# Check for specific errors
# Look for: "❌", "Registration error", "Login error"
```

---

## ✅ Success Indicators

### Registration Success
- ✅ Console shows: "✅ Registration successful"
- ✅ Console shows: "✅ JWT token saved"
- ✅ Console shows: "✅ Agency ID saved"
- ✅ User navigated to HomePage
- ✅ Welcome message displayed

### Login Success
- ✅ Console shows: "✅ Login successful"
- ✅ Console shows: "✅ JWT token saved"
- ✅ Console shows: "✅ Agency ID saved"
- ✅ User navigated to HomePage
- ✅ Welcome message displayed

---

**Last Updated:** 2025-11-03  
**Status:** Enhanced Error Handling Implemented

