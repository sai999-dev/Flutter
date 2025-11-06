# 🔍 Check Registration Error - Step by Step

## Step 1: Check Current Error Logs

**Please check your Flutter console/terminal logs again** and look for:

```
❌ Registration failed: [what error message?]
❌ Status code: [what status code?]
❌ Full error response: [what does it say?]
```

**Share the complete error message** so I can identify the exact issue.

---

## Step 2: Common Issues After Adding Column

### Issue 1: Backend Not Restarted
- ✅ Did you restart the backend server after adding the column?
- The backend needs to be restarted to pick up schema changes

### Issue 2: Schema Cache Not Cleared
- Supabase might have cached the old schema
- Try refreshing the schema cache in Supabase dashboard

### Issue 3: Column Name Mismatch
- Backend might be looking for a different column name
- Check if backend code uses `business_name` or `businessName` (camelCase)

### Issue 4: Other Missing Columns
- There might be other missing columns besides `business_name`
- Check backend error message for other column names

### Issue 5: Data Type Mismatch
- Column might exist but with wrong data type
- Backend expects specific data type

---

## Step 3: Verify Column Was Added Correctly

**Run this SQL to verify:**
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'agencies' 
AND column_name = 'business_name';
```

**Should return:**
```
column_name   | data_type          | is_nullable
--------------|--------------------|-------------
business_name | character varying | YES
```

---

## Step 4: Check Backend Registration Code

**The backend registration endpoint should be inserting:**
- `email`
- `password` (hashed)
- `agency_name`
- `business_name` ← **This was missing**
- `contact_name`
- `phone`
- `industry`
- `plan_id`
- `payment_method_id`
- `zipcodes` (array)

**Check your backend code** (likely in `super-admin-backend/controllers/mobileAuthController.js` or similar):

```javascript
// Should look something like this:
const { data, error } = await supabase
  .from('agencies')
  .insert({
    email: req.body.email,
    password: hashedPassword,
    agency_name: req.body.agency_name,
    business_name: req.body.business_name,  // ✅ Must be here
    contact_name: req.body.contact_name,
    phone: req.body.phone,
    industry: req.body.industry || 'Healthcare',
    plan_id: req.body.plan_id,
    payment_method_id: req.body.payment_method_id,
    zipcodes: req.body.zipcodes || []
  })
```

---

## Step 5: Test Backend Endpoint Directly

**Test the registration endpoint with curl:**

```bash
curl -X POST http://localhost:3000/api/mobile/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "test123456",
    "agency_name": "Test Agency",
    "business_name": "Test Business",
    "contact_name": "Test Contact",
    "phone": "1234567890"
  }'
```

**Check the response:**
- If it works: Returns `{"token":"...","agency_id":"..."}`
- If it fails: Shows the exact error

---

## Step 6: Check Backend Server Logs

**Look at your backend server terminal/console** for errors:

```
Error: column "..." does not exist
Error: relation "..." does not exist
Error: invalid input syntax
```

**Backend logs will show the exact database error.**

---

## 🔧 Quick Fixes to Try

### Fix 1: Restart Backend
```bash
cd super-admin-backend
# Stop server (Ctrl+C)
npm start
```

### Fix 2: Clear Supabase Schema Cache
- Go to Supabase Dashboard
- Database → Tables
- Click "Refresh" or restart Supabase

### Fix 3: Verify Column Exists
```sql
-- Check if column exists
SELECT * FROM information_schema.columns 
WHERE table_name = 'agencies' 
AND column_name = 'business_name';
```

### Fix 4: Check Column Name in Backend
- Open backend registration controller
- Verify it uses `business_name` (snake_case) not `businessName` (camelCase)
- Supabase uses snake_case by default

---

## 📋 What I Need From You

**Please share:**

1. **The complete error message** from Flutter console:
   ```
   ❌ Registration failed: [full error message]
   ❌ Status code: [code]
   ❌ Full error response: [response body]
   ```

2. **Backend server logs** (if available):
   - Any errors in the backend terminal

3. **Result of SQL query:**
   ```sql
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'agencies';
   ```
   - This shows all columns in the table

4. **Backend registration code:**
   - The file that handles `/api/mobile/auth/register`
   - The insert statement that creates the agency

---

## 🚀 Next Steps

1. **Check Flutter logs** - get the exact error message
2. **Check backend logs** - see what database error occurred
3. **Verify column exists** - run the SQL query
4. **Share the error details** - so I can provide the exact fix

The error message will tell us exactly what's wrong!

---

**Last Updated:** 2025-01-03  
**Status:** ⚠️ Need error details to diagnose

