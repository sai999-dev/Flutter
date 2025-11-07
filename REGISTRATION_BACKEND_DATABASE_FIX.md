# 🔧 Registration Backend Database Fix

## ❌ Error Identified

From the logs, I can see:

```
❌ Registration failed: Failed to create agency
❌ Status code: 500
❌ Response body: {"success":false,"message":"Failed to create agency","error":"Could not find t...
```

**Error:** `Could not find t...` (truncated, likely "Could not find table" or "Could not find column")

**Also mentioned:** `business_name' column of 'agencies' in the schema cache`

---

## 🔍 Problem Analysis

This is a **backend database schema issue**, not a Flutter app issue.

### Root Cause:
The backend is trying to insert data into the `agencies` table, but:
1. The `agencies` table might not exist in the database
2. OR the `business_name` column is missing from the `agencies` table
3. OR there's a schema cache issue

---

## ✅ Solution: Fix Backend Database

### Step 1: Check Database Schema

**Go to your backend project:**
```bash
cd super-admin-backend
```

**Check if `agencies` table exists:**
- If using Supabase: Check Supabase dashboard → Table Editor
- If using PostgreSQL directly: Run SQL query:
  ```sql
  SELECT * FROM information_schema.tables 
  WHERE table_name = 'agencies';
  ```

### Step 2: Create/Update `agencies` Table

**Required columns for registration:**

```sql
CREATE TABLE IF NOT EXISTS agencies (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  agency_name VARCHAR(255) NOT NULL,
  business_name VARCHAR(255),  -- ✅ This column is required!
  contact_name VARCHAR(255),
  phone VARCHAR(50),
  industry VARCHAR(100) DEFAULT 'Healthcare',
  plan_id VARCHAR(100),
  payment_method_id VARCHAR(255),
  zipcodes TEXT[],  -- Array of zipcodes
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_active BOOLEAN DEFAULT true,
  is_verified BOOLEAN DEFAULT false
);
```

**Or if table exists, add missing column:**
```sql
ALTER TABLE agencies 
ADD COLUMN IF NOT EXISTS business_name VARCHAR(255);
```

### Step 3: Clear Schema Cache

**If using Supabase:**
1. Go to Supabase Dashboard
2. Database → Tables
3. Refresh schema cache
4. Or restart Supabase local instance

**If using direct PostgreSQL:**
```sql
-- Clear any cached schema information
-- Restart backend server
```

### Step 4: Verify Backend Registration Endpoint

**Check backend registration controller:**
- File: `super-admin-backend/controllers/mobileAuthController.js` (or similar)
- Verify it's using correct table name: `agencies`
- Verify it's using correct column names

**Expected backend code should look like:**
```javascript
const { data, error } = await supabase
  .from('agencies')
  .insert({
    email: req.body.email,
    password: hashedPassword,
    agency_name: req.body.agency_name,
    business_name: req.body.business_name,  // ✅ Must exist!
    contact_name: req.body.contact_name,
    phone: req.body.phone,
    industry: req.body.industry || 'Healthcare',
    plan_id: req.body.plan_id,
    payment_method_id: req.body.payment_method_id,
    zipcodes: req.body.zipcodes || []
  })
  .select();
```

---

## 🚀 Quick Fix Steps

### Option 1: Add Missing Column (If Table Exists)

```sql
ALTER TABLE agencies 
ADD COLUMN IF NOT EXISTS business_name VARCHAR(255);
```

### Option 2: Recreate Table (If Table Missing)

```sql
DROP TABLE IF EXISTS agencies CASCADE;

CREATE TABLE agencies (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  agency_name VARCHAR(255) NOT NULL,
  business_name VARCHAR(255),
  contact_name VARCHAR(255),
  phone VARCHAR(50),
  industry VARCHAR(100) DEFAULT 'Healthcare',
  plan_id VARCHAR(100),
  payment_method_id VARCHAR(255),
  zipcodes TEXT[],
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_active BOOLEAN DEFAULT true,
  is_verified BOOLEAN DEFAULT false
);
```

### Option 3: Check Backend Code

**Verify backend is using correct table/column names:**
1. Open backend registration controller
2. Check table name: should be `agencies`
3. Check column names match database schema
4. Fix any mismatches

---

## 🔍 Verification

### After Fixing Database:

1. **Restart backend server:**
   ```bash
   cd super-admin-backend
   npm start
   ```

2. **Test registration endpoint directly:**
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

3. **Try registration in Flutter app again**

---

## 📋 Required Database Columns

Based on the Flutter app's registration request, the `agencies` table needs:

| Column | Type | Required | Notes |
|--------|------|----------|-------|
| `id` | SERIAL/INTEGER | Yes | Primary key |
| `email` | VARCHAR(255) | Yes | Unique |
| `password` | VARCHAR(255) | Yes | Hashed |
| `agency_name` | VARCHAR(255) | Yes | |
| `business_name` | VARCHAR(255) | No | **This is missing!** |
| `contact_name` | VARCHAR(255) | No | |
| `phone` | VARCHAR(50) | No | |
| `industry` | VARCHAR(100) | No | Default: 'Healthcare' |
| `plan_id` | VARCHAR(100) | No | |
| `payment_method_id` | VARCHAR(255) | No | |
| `zipcodes` | TEXT[] | No | Array of zipcodes |
| `created_at` | TIMESTAMP | No | Auto |
| `updated_at` | TIMESTAMP | No | Auto |

---

## 🐛 Common Issues

### Issue 1: "Could not find table 'agencies'"

**Solution:**
- Create the `agencies` table (see SQL above)
- Verify table name matches backend code

### Issue 2: "Could not find column 'business_name'"

**Solution:**
```sql
ALTER TABLE agencies 
ADD COLUMN business_name VARCHAR(255);
```

### Issue 3: Schema Cache Issue

**Solution:**
- Restart backend server
- Clear Supabase schema cache
- Refresh database connection

---

## ✅ Next Steps

1. **Fix database schema** (add missing `business_name` column or create table)
2. **Restart backend server**
3. **Try registration again in Flutter app**
4. **Check logs** - should see success instead of 500 error

---

**Last Updated:** 2025-01-03  
**Status:** ⚠️ Backend database schema issue - needs fixing

