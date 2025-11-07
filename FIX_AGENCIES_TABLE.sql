-- Fix agencies table: Add missing business_name column
-- This fixes the registration error: "Could not find business_name column"

-- Step 1: Add the missing business_name column
ALTER TABLE agencies 
ADD COLUMN IF NOT EXISTS business_name VARCHAR(255);

-- Step 2: Verify the column was added (optional - check in your database)
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'agencies' AND column_name = 'business_name';

-- Step 3: If you need to update existing records (optional)
-- UPDATE agencies 
-- SET business_name = agency_name 
-- WHERE business_name IS NULL;

