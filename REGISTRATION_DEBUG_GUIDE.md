# 🔍 Registration Debug Guide

## Enhanced Error Logging Added

I've added comprehensive error logging to help diagnose registration failures. When registration fails, check the console output for detailed information.

---

## 📋 What to Check When Registration Fails

### 1. **Check Console Logs**

Look for these log messages in your Flutter console:

**Request Logs:**
```
📤 POST http://localhost:3000/api/mobile/auth/register
📤 Request body: {...}
📤 Request headers: {...}
📤 requireAuth: false, includeAuth: false
📤 JWT token present: false
```

**Response Logs:**
```
📥 Response status: 200/201/400/409/500
📥 Response headers: {...}
📥 Response body: {...}
```

**Error Logs:**
```
❌ Registration failed: [error message]
❌ Status code: [code]
❌ Full error response: [response body]
❌ Error data: [parsed error]
```

---

## 🔍 Common Issues & Solutions

### Issue 1: "No backend server available"

**Check:**
1. Is backend server running?
   ```bash
   cd super-admin-backend
   npm start
   ```

2. Is backend accessible?
   - Test: `curl http://localhost:3000/api/health`
   - Should return: `{"status": "ok"}`

3. Check console for:
   ```
   ✅ Connected to backend: http://127.0.0.1:3000
   ```

**Solution:**
- Start backend server
- Check if port 3000, 3001, or 3002 is available
- For Android emulator: Backend should be accessible from host machine

---

### Issue 2: "Registration failed: [specific error]"

**Check console logs for:**
- Status code (400, 409, 500, etc.)
- Error message from backend
- Validation errors

**Common Status Codes:**
- **400 Bad Request**: Invalid data format or missing required fields
- **409 Conflict**: Email already exists
- **500 Internal Server Error**: Backend server error

**Solution:**
- Read the error message from backend
- Check if all required fields are filled
- Verify email format
- Check password requirements

---

### Issue 3: "Connection timeout"

**Check:**
1. Network connection
2. Backend server is running
3. Firewall/antivirus blocking connection
4. For Android emulator: Use `10.0.2.2:3000` instead of `localhost`

**Solution:**
- Check internet connection
- Verify backend is running
- Check firewall settings
- For emulator: Update backend URL in `api_client.dart`

---

### Issue 4: JWT Token Still Being Sent

**Check console logs:**
```
📤 Request headers: {Content-Type: application/json, Authorization: Bearer ...}
📤 JWT token present: true
```

**If you see Authorization header:**
- This means JWT is being sent when it shouldn't be
- Registration should NOT have Authorization header

**Solution:**
- Verify `requireAuth: false` is set for registration
- Check `_getHeaders()` is not including JWT when `includeAuth: false`

---

## 🧪 Testing Registration

### Step 1: Check Backend Health
```bash
curl http://localhost:3000/api/health
```

### Step 2: Test Registration Endpoint Directly
```bash
curl -X POST http://localhost:3000/api/mobile/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "test123456",
    "agency_name": "Test Agency",
    "phone": "1234567890"
  }'
```

### Step 3: Check Flutter Console
- Look for detailed request/response logs
- Check for error messages
- Verify headers don't include Authorization

---

## 📝 Registration Request Format

**Expected Request:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "agency_name": "Agency Name",
  "phone": "1234567890",
  "business_name": "Business Name",
  "contact_name": "Contact Name",
  "zipcodes": ["75201", "75033"],
  "industry": "Healthcare",
  "plan_id": "plan_id_here",
  "payment_method_id": "pm_xxx"
}
```

**Expected Headers:**
```
Content-Type: application/json
(No Authorization header)
```

**Expected Response (Success):**
```json
{
  "token": "jwt_token_here",
  "agency_id": "agency_id_here",
  "email": "user@example.com",
  "agency_name": "Agency Name"
}
```

---

## 🔧 Debug Checklist

- [ ] Backend server is running
- [ ] Backend health endpoint responds
- [ ] Registration endpoint exists: `POST /api/mobile/auth/register`
- [ ] Request headers don't include Authorization
- [ ] Request body format is correct
- [ ] All required fields are provided
- [ ] Email format is valid
- [ ] Password meets requirements
- [ ] Network connection is available
- [ ] Console shows detailed error logs

---

## 📞 Next Steps

1. **Run registration again**
2. **Check console logs** for detailed error information
3. **Share the error logs** if registration still fails
4. **Check backend logs** for server-side errors

The enhanced logging will show exactly what's being sent and what error is being returned, making it much easier to diagnose the issue.

---

**Last Updated:** 2025-01-03  
**Status:** ✅ Enhanced error logging added

