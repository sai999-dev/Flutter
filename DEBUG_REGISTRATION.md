# 🔍 Debug Registration - Test the Endpoint

## I See Your Registration Request

From the network logs, I can see the registration request is being sent correctly:

**Request:**
- URL: `http://127.0.0.1:3002/api/mobile/auth/register`
- Method: `POST`
- Body includes `business_name: "aaa"` ✅

**Request Body:**
```json
{
  "email": "aaa@gmail.com",
  "password": "12345678",
  "agency_name": "aaa",
  "phone": " 532472828",
  "business_name": "aaa",
  "contact_name": "aaa",
  "zipcodes": ["75202"],
  "industry": "Healthcare",
  "plan_id": "ad7c81db-0455-424b-b9ed-d4a217495ab8",
  "payment_method_id": "pm_test_1762451900172"
}
```

---

## 🧪 Test the Endpoint Directly

I've created a PowerShell test script. Run it to see the exact error:

```powershell
.\test_registration.ps1
```

Or test manually with curl:

```bash
curl -X POST http://127.0.0.1:3002/api/mobile/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "aaa@gmail.com",
    "password": "12345678",
    "agency_name": "aaa",
    "phone": "532472828",
    "business_name": "aaa",
    "contact_name": "aaa",
    "zipcodes": ["75202"],
    "industry": "Healthcare",
    "plan_id": "ad7c81db-0455-424b-b9ed-d4a217495ab8",
    "payment_method_id": "pm_test_1762451900172"
  }'
```

---

## 🔍 What to Check

### 1. Check Backend Server Logs

**Look at your backend terminal** (where you ran `npm start`). You should see:

```
POST /api/mobile/auth/register
Error: [database error message]
```

**The backend logs will show the exact database error.**

### 2. Common Issues

**Issue 1: Phone Number Has Leading Space**
- Your request has: `"phone": " 532472828"` (space before number)
- Backend might reject this or database might have issues
- **Fix:** Remove the space: `"phone": "532472828"`

**Issue 2: Missing Columns**
- Even though `business_name` was added, there might be other missing columns
- Check backend error message for other column names

**Issue 3: Data Type Mismatch**
- `zipcodes` is sent as array `["75202"]`
- Database might expect different format (TEXT[], JSON, etc.)

**Issue 4: Foreign Key Constraints**
- `plan_id` references another table
- If the plan doesn't exist, registration will fail

**Issue 5: Payment Method ID Format**
- `payment_method_id: "pm_test_1762451900172"` might not be valid
- Backend might validate this

---

## 📋 Check These Things

### 1. Backend Server Logs
**Most Important!** Check your backend terminal for the exact error.

### 2. Database Schema
Run this SQL to see all columns:
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'agencies'
ORDER BY ordinal_position;
```

### 3. Test with Minimal Data
Try registration with just required fields:
```json
{
  "email": "test@example.com",
  "password": "12345678",
  "agency_name": "Test Agency"
}
```

### 4. Check Plan ID Exists
Verify the plan exists in database:
```sql
SELECT * FROM subscription_plans 
WHERE id = 'ad7c81db-0455-424b-b9ed-d4a217495ab8';
```

---

## 🚀 Quick Fixes to Try

### Fix 1: Remove Phone Space
The phone number has a leading space. Try without it:
```json
"phone": "532472828"  // No space
```

### Fix 2: Test Without Optional Fields
Try registration with minimal data first:
```json
{
  "email": "test@example.com",
  "password": "12345678",
  "agency_name": "Test Agency",
  "business_name": "Test Business"
}
```

### Fix 3: Check Backend Code
Open your backend registration controller and verify:
- It's using correct table name: `agencies`
- It's handling all the fields correctly
- It's not trying to insert into non-existent columns

---

## 📞 What I Need

**Please share:**

1. **Backend server terminal output** - The exact error from backend
2. **Result of test script** - Run `.\test_registration.ps1` and share output
3. **Database columns** - Result of the SQL query above
4. **Backend registration code** - The file that handles registration

The backend logs will show exactly what's wrong!

---

**Last Updated:** 2025-01-03  
**Status:** 🔍 Need backend error details

