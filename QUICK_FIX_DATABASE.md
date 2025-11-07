# ✅ Quick Fix: Add Missing Column to Agencies Table

## Problem
The `agencies` table exists but is missing the `business_name` column, causing registration to fail with:
```
Error: Could not find business_name column
Status: 500
```

## ✅ Solution: Add Missing Column

Since the table already exists, you just need to **add the missing column**.

### Option 1: Using SQL Query

Run this SQL in your database (Supabase SQL Editor or PostgreSQL):

```sql
ALTER TABLE agencies 
ADD COLUMN IF NOT EXISTS business_name VARCHAR(255);
```

### Option 2: Using Supabase Dashboard

1. Go to Supabase Dashboard
2. Navigate to **Database** → **Tables**
3. Click on **agencies** table
4. Click **Add Column**
5. Set:
   - **Name:** `business_name`
   - **Type:** `varchar` or `text`
   - **Length:** `255` (optional)
   - **Nullable:** ✅ Yes (optional)
6. Click **Save**

### Option 3: Using psql (Command Line)

```bash
psql -h [your-host] -U [your-user] -d [your-database]
```

Then run:
```sql
ALTER TABLE agencies 
ADD COLUMN IF NOT EXISTS business_name VARCHAR(255);
```

---

## 🔍 Verify Column Was Added

### Check in Supabase:
1. Go to **Database** → **Tables** → **agencies**
2. Look for `business_name` column in the list

### Check with SQL:
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'agencies' AND column_name = 'business_name';
```

Should return:
```
column_name   | data_type
--------------|----------
business_name | character varying
```

---

## 🔄 After Adding Column

1. **Restart Backend Server:**
   ```bash
   cd super-admin-backend
   npm start
   ```

2. **Clear Schema Cache (if needed):**
   - Supabase: Refresh the schema cache
   - Or restart Supabase local instance

3. **Try Registration Again:**
   - The registration should now work
   - Check logs - should see `✅ Registration successful` instead of 500 error

---

## 📋 Complete Table Schema (Reference)

If you want to verify all required columns exist:

```sql
-- Check all columns in agencies table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'agencies'
ORDER BY ordinal_position;
```

**Required columns for registration:**
- ✅ `id` (primary key)
- ✅ `email` (unique, not null)
- ✅ `password` (not null)
- ✅ `agency_name` (not null)
- ✅ `business_name` (nullable) ← **This was missing!**
- ✅ `contact_name` (nullable)
- ✅ `phone` (nullable)
- ✅ `industry` (nullable)
- ✅ `plan_id` (nullable)
- ✅ `payment_method_id` (nullable)
- ✅ `zipcodes` (array, nullable)
- ✅ `created_at` (timestamp)
- ✅ `updated_at` (timestamp)

---

## ✅ Quick Test

After adding the column:

1. **Restart backend:**
   ```bash
   cd super-admin-backend
   npm start
   ```

2. **Try registration in Flutter app**

3. **Check logs** - should see:
   ```
   ✅ Registration successful
   📥 Response status: 200
   ```

---

## 🐛 If Still Failing

If registration still fails after adding the column:

1. **Check backend logs** for other missing columns
2. **Verify column name** matches what backend expects
3. **Check backend code** to see what columns it's trying to insert
4. **Restart backend** to clear any cached schema

---

**Last Updated:** 2025-01-03  
**Status:** ✅ Quick fix - Add missing column

