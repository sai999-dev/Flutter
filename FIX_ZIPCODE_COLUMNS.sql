-- ===============================================
-- FIX AGENCIES TABLE ZIPCODE COLUMNS
-- ===============================================
-- Problem: Database has multiple zipcode columns with wrong types
-- Mobile app sends: zipcodes (array of strings)
-- Database has: zipcodes (VARCHAR), territories (JSONB), primary_zipcodes (TEXT[])
-- Solution: Standardize on TEXT[] array type
-- ===============================================

-- Step 1: Check current table structure
SELECT 
    column_name, 
    data_type, 
    udt_name
FROM information_schema.columns
WHERE table_name = 'agencies'
AND column_name IN ('zipcodes', 'territories', 'primary_zipcodes', 'territory_count', 'territory_limit', 'preferred_territory_type')
ORDER BY ordinal_position;

-- Step 2: Drop incorrect columns if they exist
ALTER TABLE agencies DROP COLUMN IF EXISTS zipcodes CASCADE;
ALTER TABLE agencies DROP COLUMN IF EXISTS territories CASCADE;

-- Step 3: Rename primary_zipcodes to zipcodes (standard name)
ALTER TABLE agencies RENAME COLUMN IF EXISTS primary_zipcodes TO zipcodes;

-- Step 4: Ensure zipcodes column exists with correct type
ALTER TABLE agencies 
ADD COLUMN IF NOT EXISTS zipcodes TEXT[] DEFAULT ARRAY[]::TEXT[];

-- Step 5: Add index for faster zipcode queries
CREATE INDEX IF NOT EXISTS idx_agencies_zipcodes 
ON agencies USING GIN (zipcodes);

-- Step 6: Add territory-related helper columns
ALTER TABLE agencies 
ADD COLUMN IF NOT EXISTS territory_count INT DEFAULT 0;

ALTER TABLE agencies 
ADD COLUMN IF NOT EXISTS territory_limit INT DEFAULT 0;

-- Step 7: Update territory_count based on zipcodes array length
UPDATE agencies 
SET territory_count = COALESCE(array_length(zipcodes, 1), 0)
WHERE territory_count = 0;

-- Step 8: Verify the fix
SELECT 
    id,
    email,
    agency_name,
    zipcodes,
    territory_count,
    territory_limit
FROM agencies
ORDER BY created_at DESC
LIMIT 5;

-- ===============================================
-- VERIFICATION QUERIES
-- ===============================================

-- Check if zipcodes column has correct type
SELECT 
    column_name,
    data_type,
    udt_name as array_type
FROM information_schema.columns
WHERE table_name = 'agencies'
AND column_name = 'zipcodes';
-- Expected: data_type = 'ARRAY', udt_name = '_text'

-- Test inserting zipcodes array
-- This is what the mobile app sends during registration
INSERT INTO agencies (
    email,
    password,
    agency_name,
    business_name,
    contact_name,
    phone,
    industry,
    zipcodes
) VALUES (
    'test_zipcode@example.com',
    'hashed_password_here',
    'Test Agency',
    'Test Business',
    'Test Contact',
    '555-1234',
    'Insurance',
    ARRAY['75001', '75002', '75003']::TEXT[]
) 
ON CONFLICT (email) DO UPDATE 
SET zipcodes = EXCLUDED.zipcodes;

-- Verify the test insert
SELECT 
    email,
    zipcodes,
    array_length(zipcodes, 1) as zipcode_count
FROM agencies
WHERE email = 'test_zipcode@example.com';

-- Clean up test data
DELETE FROM agencies WHERE email = 'test_zipcode@example.com';

-- ===============================================
-- FINAL SCHEMA VERIFICATION
-- ===============================================
-- Run this to confirm all columns are correct:

SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'agencies'
ORDER BY ordinal_position;

-- Expected zipcodes column:
-- column_name: zipcodes
-- data_type: ARRAY
-- column_default: '{}'::text[] or ARRAY[]::text[]
-- is_nullable: YES
