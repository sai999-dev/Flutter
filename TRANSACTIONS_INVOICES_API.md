# Transactions and Invoices API Documentation

## Overview
This document describes the API endpoint and code used to create transaction and invoice records in the database when an agency registers.

## API Endpoint

### Register Agency (Creates Transaction & Invoice)
**Endpoint:** `POST /api/mobile/auth/register`

**Base URL:** `http://127.0.0.1:3000` (development)

**Full URL:** `http://127.0.0.1:3000/api/mobile/auth/register`

**Authentication:** Public (no authentication required)

**Request Body:**
```json
{
  "email": "agency@example.com",
  "password": "securepassword123",
  "business_name": "My Agency Name",
  "plan_id": "677ca043-3d63-48c5-a20c-9e6510960ef6",
  "zipcodes": ["75001", "75002"],
  "contact_name": "John Doe",
  "phone": "+1234567890",
  "industry": "real_estate"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Agency registered successfully",
  "data": {
    "agency_id": "uuid-here",
    "token": "jwt-token-here"
  }
}
```

---

## Code Implementation

### File Location
`/routes/mobileAuthRoutes.js`

### Transaction Creation Code

```javascript
// Get agency name for agency field
const agencyName = createdAgencyRow?.agency_name || business_name;

// Insert transaction with actual table columns
const transactionInsert = {
  agency_id: normalizedNewAgency.id,
  transaction_type: 'subscription_payment',
  amount: planPrice,
  status: payment_method_id ? 'completed' : 'pending',
  currency: 'USD',
  gateway: payment_method_id ? 'stripe' : null,
  agency: agencyName, // Store only the agency name as a string
  metadata: {
    subscription_id: subscription.id,
    plan_id: selectedPlanId,
    payment_method_id: payment_method_id || null,
    plan_name: planInfo?.name || 'Unknown'
  }
};

const { data: transactionData, error: transactionError } = await supabase
  .from('transactions')
  .insert([transactionInsert])
  .select()
  .single();
```

**Transaction Table Fields:**
- `agency_id` (UUID) - Reference to agency
- `transaction_type` (String) - 'subscription_payment'
- `amount` (Decimal) - Plan price from subscription_plans table
- `status` (String) - 'completed' or 'pending' (based on payment_method_id)
- `currency` (String) - 'USD'
- `gateway` (String) - 'stripe' or null
- `agency` (String) - Agency name as plain string
- `metadata` (JSONB) - Additional transaction details

---

### Invoice Creation Code

```javascript
// Prepare agency data for agency field - store only the agency name as a string
const agencyName = createdAgencyRow?.agency_name || business_name;

const invoiceInsertData = {
  agency_id: normalizedNewAgency.id,
  stripe_invoice_id: null, // Set to null as requested
  currency: 'USD',
  status: payment_method_id ? 'paid' : 'pending',
  due_date: nextBilling.toISOString(),
  created_date: now.toISOString().split('T')[0], // Date format YYYY-MM-DD
  amount: planPrice, // Use actual plan price
  agency: agencyName, // Store only the agency name as a string
};

const { data: invoiceData, error: invoiceError } = await supabase
  .from('invoices')
  .insert([invoiceInsertData])
  .select()
  .single();
```

**Invoice Table Fields:**
- `agency_id` (UUID) - Reference to agency
- `stripe_invoice_id` (String) - Set to `null`
- `currency` (String) - 'USD'
- `status` (String) - 'paid' or 'pending' (based on payment_method_id)
- `due_date` (Timestamp) - Next billing date (30 days from registration)
- `created_date` (Date) - Current date in YYYY-MM-DD format
- `amount` (Decimal) - Plan price from subscription_plans table
- `agency` (String) - Agency name as plain string

---

## Data Flow

1. **Agency Registration** → `POST /api/mobile/auth/register`
2. **Plan Price Retrieval** → Fetch `price_per_unit` from `subscription_plans` table
3. **Subscription Creation** → Create subscription record
4. **Transaction Creation** → Insert into `transactions` table
5. **Invoice Creation** → Insert into `invoices` table

---

## Key Points

- **Plan Price:** Retrieved from `subscription_plans.price_per_unit` before creating transaction/invoice
- **Agency Name:** Stored as plain string in both `transactions.agency` and `invoices.agency` fields
- **Stripe Invoice ID:** Always set to `null` in invoices table
- **Status:** Determined by presence of `payment_method_id`:
  - With payment method: `status = 'completed'` (transaction) / `'paid'` (invoice)
  - Without payment method: `status = 'pending'` (both)
- **Error Handling:** Transaction/invoice creation errors are logged but don't fail registration

---

## Database Tables

### Transactions Table
- Primary Key: `id` (UUID)
- Foreign Key: `agency_id` → `agencies.id`
- Indexed: `agency_id`, `transaction_type`, `status`

### Invoices Table
- Primary Key: `id` (UUID)
- Foreign Key: `agency_id` → `agencies.id`
- Indexed: `agency_id`, `status`, `created_date`

