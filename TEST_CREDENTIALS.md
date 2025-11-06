# 🧪 Test Credentials for Development

## Quick Test Login (Bypasses Authentication)

The app includes a **"Use Test Credentials"** button on the login page that automatically:
- Fills in test credentials
- **Bypasses backend authentication**
- Creates a mock JWT token
- Logs you in instantly (no backend required)

### Test Credentials

**Email:** `test@example.com`  
**Password:** `test123456`

**Note:** These credentials bypass authentication - no backend server or valid credentials needed!

---

## How to Use

### Option 1: Quick Test Button (Recommended)

1. Open the login page
2. Click the **"Use Test Credentials"** button (orange button below password field)
3. The app will automatically:
   - Fill in the email and password fields
   - Attempt to log in with these credentials

### Option 2: Manual Entry

1. Open the login page
2. Enter email: `test@example.com`
3. Enter password: `test123456`
4. Click "Sign In"

---

## How Test Mode Works

**Test credentials bypass authentication completely:**
- ✅ No backend server required
- ✅ No API calls made
- ✅ Mock JWT token generated
- ✅ Mock user data created
- ✅ Works offline

## Test Account Setup (Optional)

**Note:** If you want to test with real backend authentication instead of bypassing it, you can create a test account:

1. **Create the test account first:**
   - Register a new account with email: `test@example.com`
   - Password: `test123456`
   - Complete the registration process

2. **Or use backend seeding:**
   ```bash
   # In your backend, create a test user
   # Example SQL (adjust for your database):
   INSERT INTO agencies (email, password_hash, agency_name, contact_name, created_at)
   VALUES ('test@example.com', '$2b$10$hashed_password', 'Test Agency', 'Test User', NOW());
   ```

---

## Alternative Test Credentials

If `test@example.com` doesn't work, you can use any of these:

### Test Account 1
- **Email:** `test@example.com`
- **Password:** `test123456`

### Test Account 2
- **Email:** `demo@example.com`
- **Password:** `demo123456`

### Test Account 3
- **Email:** `dev@example.com`
- **Password:** `dev123456`

---

## Creating Test Accounts

### Method 1: Through App Registration

1. Use the registration flow in the app
2. Register with one of the test emails above
3. Use simple passwords (e.g., `test123456`)

### Method 2: Direct Database Insert

If you have database access:

```sql
-- Example PostgreSQL/Supabase
INSERT INTO agencies (
  email,
  password_hash,
  agency_name,
  contact_name,
  phone,
  created_at
) VALUES (
  'test@example.com',
  '$2b$10$hashed_password_here',  -- Use bcrypt to hash 'test123456'
  'Test Agency',
  'Test User',
  '+1234567890',
  NOW()
);
```

### Method 3: Backend API Call

```bash
curl -X POST http://localhost:3000/api/mobile/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "test123456",
    "agency_name": "Test Agency",
    "contact_name": "Test User",
    "phone": "+1234567890",
    "zipcodes": ["75201"],
    "industry": "Healthcare"
  }'
```

---

## Testing Without Backend

If you want to test the UI without backend authentication:

1. **Comment out the API call** in `_login()` method
2. **Use mock authentication:**

```dart
// In _login() method, temporarily replace:
final response = await AuthService.login(...);

// With:
final mockResponse = {
  'token': 'mock_jwt_token_for_testing',
  'data': {
    'agency_id': 'test_agency_123',
    'email': _emailController.text,
    'agency_name': 'Test Agency',
    'contact_name': 'Test User'
  }
};
```

**⚠️ Remember to restore the real API call before production!**

---

## Quick Test Credentials Summary

| Email | Password | Purpose |
|-------|----------|---------|
| `test@example.com` | `test123456` | Primary test account |
| `demo@example.com` | `demo123456` | Demo account |
| `dev@example.com` | `dev123456` | Development account |

---

## Troubleshooting

### "Invalid credentials" Error

**Cause:** Test account doesn't exist in database

**Solution:**
1. Register the test account through the app
2. Or create it directly in the database
3. Or use the backend seeding script

### "Backend server is not running" Error

**Solution:**
```bash
cd super-admin-backend
npm start
```

### "Email already exists" (when registering test account)

**Solution:**
- Use a different test email
- Or delete the existing test account from database
- Or use the login instead of registration

---

## Security Note

⚠️ **These credentials are for DEVELOPMENT and TESTING only!**

- Never use these in production
- Remove the "Use Test Credentials" button before production release
- Use strong, unique passwords in production
- Implement proper authentication mechanisms

---

## Quick Reference

**Login Page:**
- Look for orange "Use Test Credentials" button
- Click it to auto-fill and login

**Test Credentials:**
- Email: `test@example.com`
- Password: `test123456`

**Backend Required:**
- Account must exist in database
- Or use registration to create it

---

**Last Updated:** 2025-11-03  
**Status:** ✅ Test Credentials Feature Added

