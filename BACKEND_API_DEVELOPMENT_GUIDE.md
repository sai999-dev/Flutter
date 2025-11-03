# Backend API Development Guide - Middleware Layer

## Overview

This document provides comprehensive instructions for developing the **Backend API Middleware Layer** that serves as the intermediary between:
- **PostgreSQL Database** (Single Source of Truth)
- **Mobile App** (Flutter - Separate Repository) via `/api/mobile/*`
- **Super Admin Portal** (React/Vue - Separate Repository) via `/api/admin/*`
- **Public Portals** (Webhooks) via `/api/webhook/*`

## Architecture Context

```
┌─────────────────────────────────────────┐
│   PostgreSQL Database                   │
│   (Single Source of Truth)              │
│   - agencies                            │
│   - subscriptions                       │
│   - agency_territories                  │
│   - portals                             │
│   - users (admin)                       │
│   - transactions                        │
│   - leads                               │
│   - lead_assignments                    │
│   - round_robin_state                   │
│   - webhook_audit                       │
│   - agency_devices                      │
│   - notifications                       │
└──────────────────┬──────────────────────┘
                   │
                   │ SQL Queries ONLY
                   │ (This Backend API is
                   │  the ONLY system
                   │  that touches DB)
                   │
┌──────────────────▼──────────────────────┐
│   BACKEND API (Middleware Layer)       │
│   [THIS REPOSITORY]                     │
│                                          │
│   Exposes REST APIs:                    │
│   - /api/mobile/*    → Mobile App       │
│   - /api/admin/*     → Super Admin      │
│   - /api/webhook/*   → Public Portals   │
│                                          │
│   Responsibilities:                     │
│   ✓ Database Access (ONLY SQL)          │
│   ✓ Business Logic                      │
│   ✓ Authentication & Authorization       │
│   ✓ JWT Token Management                 │
│   ✓ Webhook Processing                  │
│   ✓ Push Notification Triggers           │
└──────────────────┬──────────────────────┘
                   │
       ┌───────────┴───────────┐
       │                         │
┌──────▼──────┐      ┌──────────▼─────────┐
│  MOBILE APP │      │ SUPER ADMIN PORTAL │
│  (Flutter)  │      │  (React/Vue)       │
│             │      │                    │
│ SEPARATE    │      │ SEPARATE           │
│ REPOSITORY  │      │ REPOSITORY         │
└─────────────┘      └────────────────────┘
```

## Critical Requirements

### 1. Database Access Control
- **THIS BACKEND API IS THE ONLY SYSTEM THAT TOUCHES THE DATABASE**
- No other application/service should have direct database access
- All database operations must go through this middleware layer
- Use **SQL queries ONLY** (no ORMs that generate uncontrolled queries)

### 2. Authentication & Authorization
- Implement JWT-based authentication
- Separate authentication for:
  - **Agency Users** (Mobile App) → `/api/mobile/*`
  - **Admin Users** (Super Admin Portal) → `/api/admin/*`
  - **Public Webhooks** → `/api/webhook/*` (may use API keys)

### 3. API Endpoint Structure
- **Mobile App APIs**: `/api/mobile/*`
- **Admin Portal APIs**: `/api/admin/*`
- **Webhook APIs**: `/api/webhook/*`
- **Health Check**: `/api/health`

---

## Technology Stack Recommendations

### Core Framework
Choose one based on your team's expertise:

**Node.js/Express:**
- Fast development
- Large ecosystem
- Good for REST APIs
- Popular choice for middleware layers

**Python/FastAPI or Django:**
- FastAPI: Modern, async, auto-docs
- Django: Mature, batteries-included
- Strong ORM support

**Go/Gin or Echo:**
- High performance
- Simple, clean code
- Excellent for microservices

**Java/Spring Boot:**
- Enterprise-grade
- Comprehensive framework
- Strong security features

### Database Access
- **PostgreSQL Driver**: Direct connection with connection pooling
- **Query Builder**: Knex.js (Node.js), SQLAlchemy Core (Python), jOOQ (Java)
- **Connection Pooling**: pgBouncer, built-in pool managers

### Authentication
- **JWT Library**: jsonwebtoken (Node.js), PyJWT (Python), etc.
- **Password Hashing**: bcrypt, Argon2
- **Token Storage**: In-memory or Redis (for token blacklisting)

### Additional Services
- **Push Notifications**: Firebase Cloud Messaging, OneSignal API
- **Email**: SendGrid, AWS SES, Nodemailer
- **File Storage**: AWS S3, Azure Blob Storage, or local filesystem
- **Logging**: Winston (Node.js), Loguru (Python), structured logging
- **Monitoring**: Prometheus, DataDog, or cloud-native solutions

---

## Database Schema Requirements

### Core Tables

#### 1. agencies
```sql
CREATE TABLE agencies (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    agency_name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    verification_code VARCHAR(10),
    verification_expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 2. subscriptions
```sql
CREATE TABLE subscriptions (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    plan_id VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'active', -- active, suspended, cancelled, expired
    start_date DATE NOT NULL,
    end_date DATE,
    monthly_price DECIMAL(10,2),
    is_recurring BOOLEAN DEFAULT TRUE,
    payment_method_id VARCHAR(255),
    cancelled_at TIMESTAMP,
    cancellation_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 3. subscription_plans
```sql
CREATE TABLE subscription_plans (
    id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    monthly_price DECIMAL(10,2) NOT NULL,
    features JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    max_territories INTEGER,
    max_leads_per_month INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 4. agency_territories
```sql
CREATE TABLE agency_territories (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    zipcode VARCHAR(10) NOT NULL,
    city VARCHAR(255),
    state VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(agency_id, zipcode)
);
```

#### 5. leads
```sql
CREATE TABLE leads (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(50),
    address TEXT,
    city VARCHAR(255),
    state VARCHAR(50),
    zipcode VARCHAR(10),
    status VARCHAR(50) DEFAULT 'new', -- new, contacted, qualified, converted, rejected
    source VARCHAR(100),
    assigned_to_agency_id INTEGER REFERENCES agencies(id),
    assigned_at TIMESTAMP,
    accepted_at TIMESTAMP,
    rejected_at TIMESTAMP,
    rejection_reason TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 6. lead_assignments
```sql
CREATE TABLE lead_assignments (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER REFERENCES leads(id) ON DELETE CASCADE,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'pending', -- pending, accepted, rejected
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP,
    rejected_at TIMESTAMP,
    UNIQUE(lead_id, agency_id)
);
```

#### 7. users (admin)
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'admin', -- admin, super_admin
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 8. transactions
```sql
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER REFERENCES agencies(id),
    subscription_id INTEGER REFERENCES subscriptions(id),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50), -- pending, completed, failed, refunded
    payment_method_id VARCHAR(255),
    invoice_number VARCHAR(100),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 9. agency_devices
```sql
CREATE TABLE agency_devices (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    device_token VARCHAR(500) NOT NULL,
    platform VARCHAR(50) NOT NULL, -- ios, android
    device_model VARCHAR(255),
    app_version VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(agency_id, device_token)
);
```

#### 10. notifications
```sql
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50), -- lead_assigned, subscription_expiring, payment_failed
    is_read BOOLEAN DEFAULT FALSE,
    related_lead_id INTEGER REFERENCES leads(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 11. notification_settings
```sql
CREATE TABLE notification_settings (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE UNIQUE,
    push_enabled BOOLEAN DEFAULT TRUE,
    email_enabled BOOLEAN DEFAULT TRUE,
    sms_enabled BOOLEAN DEFAULT FALSE,
    sound_enabled BOOLEAN DEFAULT TRUE,
    vibration_enabled BOOLEAN DEFAULT TRUE,
    quiet_hours JSONB, -- {"start": "22:00", "end": "08:00"}
    notification_types TEXT[] DEFAULT ARRAY['lead_assigned', 'subscription_expiring'],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 12. lead_notes (Optional but Recommended)
```sql
CREATE TABLE lead_notes (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER REFERENCES leads(id) ON DELETE CASCADE,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    note_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id INTEGER, -- if tracking individual users
    INDEX(lead_id, agency_id)
);
```

#### 13. lead_interactions (Optional but Recommended)
```sql
CREATE TABLE lead_interactions (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER REFERENCES leads(id) ON DELETE CASCADE,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    interaction_type VARCHAR(50) NOT NULL, -- phone_call, email, sms, note, status_change
    interaction_data JSONB, -- {"duration_seconds": 120, "outcome": "answered"}
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(lead_id, agency_id, interaction_type)
);
```

#### 14. lead_status_history (Optional but Recommended)
```sql
CREATE TABLE lead_status_history (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER REFERENCES leads(id) ON DELETE CASCADE,
    previous_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    changed_by_agency_id INTEGER REFERENCES agencies(id),
    notes TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(lead_id, changed_at)
);
```

#### 15. lead_views (Optional but Recommended)
```sql
CREATE TABLE lead_views (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER REFERENCES leads(id) ON DELETE CASCADE,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(lead_id, agency_id, viewed_at::DATE) -- One view per day
);
```

#### 16. password_reset_tokens (Recommended for Security)
```sql
CREATE TABLE password_reset_tokens (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    token VARCHAR(64) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(token, expires_at)
);
```

#### 17. verification_documents (Company Document Verification)
```sql
CREATE TABLE verification_documents (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL, -- business_license, certificate, tax_id, other
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL, -- Storage path (S3, local, etc.)
    file_size INTEGER NOT NULL, -- Size in bytes
    mime_type VARCHAR(100), -- application/pdf, image/png, image/jpeg
    description TEXT,
    verification_status VARCHAR(50) DEFAULT 'pending', -- pending, approved, rejected
    reviewed_by INTEGER REFERENCES users(id), -- Admin user who reviewed
    reviewed_at TIMESTAMP,
    rejection_reason TEXT, -- If rejected, why
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(agency_id, verification_status),
    INDEX(verification_status) -- For admin filtering
);
```

#### 11. portals
```sql
CREATE TABLE portals (
    id SERIAL PRIMARY KEY,
    portal_name VARCHAR(255) NOT NULL,
    api_key VARCHAR(255) UNIQUE NOT NULL,
    webhook_url VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 12. webhook_audit
```sql
CREATE TABLE webhook_audit (
    id SERIAL PRIMARY KEY,
    portal_id INTEGER REFERENCES portals(id),
    webhook_payload JSONB,
    response_status INTEGER,
    response_body TEXT,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    lead_created_id INTEGER REFERENCES leads(id)
);
```

#### 13. round_robin_state
```sql
CREATE TABLE round_robin_state (
    id SERIAL PRIMARY KEY,
    zipcode VARCHAR(10) NOT NULL,
    current_agency_index INTEGER DEFAULT 0,
    last_assigned_at TIMESTAMP,
    agency_count INTEGER DEFAULT 0,
    UNIQUE(zipcode)
);
```

---

## API Endpoints Implementation Guide

## Section 1: Mobile App APIs (`/api/mobile/*`)

### 1.1. Authentication Endpoints

#### POST `/api/mobile/auth/register`
**Purpose**: Register a new agency account

**Request Body:**
```json
{
  "email": "agency@example.com",
  "password": "securepassword",
  "agency_name": "Agency Name",
  "phone": "+1234567890" // optional
}
```

**Implementation Steps:**
1. Validate email format and password strength (min 8 chars)
2. Check if email already exists in `agencies` table
3. Hash password using bcrypt/Argon2
4. Generate verification code (6-digit random)
5. Set verification expiration (e.g., 24 hours)
6. Insert into `agencies` table:
   ```sql
   INSERT INTO agencies (email, password_hash, agency_name, phone, verification_code, verification_expires_at)
   VALUES ($1, $2, $3, $4, $5, $6)
   RETURNING id, email, agency_name;
   ```
7. Send verification email with code
8. Return success response (DO NOT return JWT yet)

**Response:**
```json
{
  "success": true,
  "message": "Registration successful. Please verify your email.",
  "data": {
    "agency_id": 123,
    "email": "agency@example.com"
  }
}
```

**Error Cases:**
- 400: Invalid email format, weak password
- 409: Email already registered
- 500: Database error, email service error

**Note**: After registration, agency should upload company verification document. The account remains `is_verified = FALSE` until:
1. Email is verified (via code)
2. Company document is reviewed and approved by admin

---

#### POST `/api/mobile/auth/upload-document`
**Purpose**: Upload company verification document (after registration)

**Authentication**: Required (JWT)

**Request**: Multipart Form Data
- `document` (file): PDF, PNG, JPG, JPEG (max 10MB)
- `document_type` (string, optional): `business_license`, `certificate`, `tax_id`, `other`
- `description` (string, optional): Additional notes about the document

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Validate file:
   - Check file size (max 10MB)
   - Validate file type (PDF, PNG, JPG, JPEG)
3. Save file to storage (S3, local filesystem, etc.):
   ```javascript
   // Example: Save to S3
   const fileName = `${agency_id}_${Date.now()}_${originalFileName}`;
   const filePath = `verification-documents/${fileName}`;
   await s3.upload({
     Bucket: process.env.S3_BUCKET,
     Key: filePath,
     Body: fileBuffer,
     ContentType: mimeType
   }).promise();
   ```
4. Insert document record:
   ```sql
   INSERT INTO verification_documents (
     agency_id, 
     document_type, 
     file_name, 
     file_path,
     file_size,
     mime_type,
     description,
     verification_status
   )
   VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending')
   RETURNING *;
   ```
5. Send notification to admin (if admin notification system exists)
6. Return success with document ID

**Response:**
```json
{
  "success": true,
  "message": "Document uploaded successfully. Awaiting admin review.",
  "data": {
    "document_id": 123,
    "verification_status": "pending",
    "uploaded_at": "2024-01-01T00:00:00Z"
  }
}
```

**Error Cases:**
- 400: File too large, invalid file type, missing file
- 401: Not authenticated
- 413: File size exceeds limit
- 500: Storage error, database error

---

#### GET `/api/mobile/auth/verification-status`
**Purpose**: Get current verification status (email + document)

**Authentication**: Required (JWT)

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Get agency verification status:
   ```sql
   SELECT 
     a.id,
     a.email,
     a.is_verified as email_verified,
     a.agency_name,
     COALESCE(MAX(vd.verification_status), 'no_document') as document_status,
     COUNT(vd.id) as document_count,
     MAX(vd.updated_at) as last_document_update
   FROM agencies a
   LEFT JOIN verification_documents vd ON a.id = vd.agency_id
   WHERE a.id = $1
   GROUP BY a.id, a.email, a.is_verified, a.agency_name;
   ```
3. Get latest document if exists:
   ```sql
   SELECT * FROM verification_documents
   WHERE agency_id = $1
   ORDER BY created_at DESC
   LIMIT 1;
   ```
4. Return combined status

**Response:**
```json
{
  "email_verified": true,
  "document_status": "pending", // no_document, pending, approved, rejected
  "overall_status": "pending_verification", // active, pending_verification, rejected
  "document": {
    "id": 123,
    "document_type": "business_license",
    "file_name": "license.pdf",
    "verification_status": "pending",
    "uploaded_at": "2024-01-01T00:00:00Z",
    "reviewed_at": null
  },
  "message": "Your document is pending admin review"
}
```

---

#### GET `/api/mobile/auth/documents`
**Purpose**: Get all uploaded documents for agency

**Authentication**: Required (JWT)

**Response:**
```json
{
  "documents": [
    {
      "id": 123,
      "document_type": "business_license",
      "file_name": "license.pdf",
      "verification_status": "pending",
      "uploaded_at": "2024-01-01T00:00:00Z",
      "description": "State business license"
    }
  ]
}
```

---

#### POST `/api/mobile/auth/verify-email`
**Purpose**: Verify agency email and activate account

**Request Body:**
```json
{
  "email": "agency@example.com",
  "verification_code": "123456"
}
```

**Implementation Steps:**
1. Find agency by email
2. Check if verification code matches
3. Check if verification code is not expired
4. Update agency:
   ```sql
   UPDATE agencies 
   SET is_verified = TRUE, verification_code = NULL, verification_expires_at = NULL
   WHERE email = $1 AND verification_code = $2 AND verification_expires_at > NOW()
   RETURNING id, email, agency_name;
   ```
5. Generate JWT token (include `agency_id`, `email`, `role: 'agency'`)
6. Return token and agency info

**Response:**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "message": "Email verified successfully",
  "data": {
    "agency_id": 123,
    "email": "agency@example.com",
    "agency_name": "Agency Name"
  }
}
```

**Error Cases:**
- 400: Invalid verification code
- 404: Email not found
- 410: Verification code expired
- 500: Database error

---

#### POST `/api/mobile/auth/login`
**Purpose**: Authenticate agency and return JWT token

**Request Body:**
```json
{
  "email": "agency@example.com",
  "password": "securepassword"
}
```

**Implementation Steps:**
1. Find agency by email
2. Verify password hash matches
3. Check if agency is verified (`is_verified = TRUE`)
4. Check if agency is active (`is_active = TRUE`)
5. Update `last_login` timestamp
6. Generate JWT token:
   ```javascript
   const payload = {
     agency_id: agency.id,
     email: agency.email,
     role: 'agency',
     iat: Math.floor(Date.now() / 1000),
     exp: Math.floor(Date.now() / 1000) + (24 * 60 * 60) // 24 hours
   };
   const token = jwt.sign(payload, process.env.JWT_SECRET);
   ```
7. Return token and agency profile

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "data": {
    "agency_id": 123,
    "email": "agency@example.com",
    "agency_name": "Agency Name",
    "is_verified": true
  }
}
```

**Error Cases:**
- 401: Invalid credentials
- 403: Email not verified or account inactive
- 404: Email not found
- 500: Database error

**JWT Token Structure:**
```json
{
  "agency_id": 123,
  "email": "agency@example.com",
  "role": "agency",
  "iat": 1234567890,
  "exp": 1234654290
}
```

---

### 1.2. Subscription Management - Self-Service

#### GET `/api/mobile/subscription/plans`
**Purpose**: Get all available subscription plans (public endpoint)

**Authentication**: Not required (public)

**Implementation Steps:**
1. Query active plans:
   ```sql
   SELECT id, name, description, monthly_price, features, max_territories, max_leads_per_month
   FROM subscription_plans
   WHERE is_active = TRUE
   ORDER BY monthly_price ASC;
   ```
2. Return plans list

**Response:**
```json
{
  "plans": [
    {
      "id": "plan_basic",
      "name": "Basic Plan",
      "description": "Perfect for small agencies",
      "monthly_price": 29.99,
      "features": {
        "max_territories": 5,
        "max_leads_per_month": 100
      },
      "max_territories": 5,
      "max_leads_per_month": 100
    }
  ]
}
```

---

#### POST `/api/mobile/subscription/subscribe`
**Purpose**: Subscribe agency to a plan

**Authentication**: Required (JWT with `role: 'agency'`)

**Request Body:**
```json
{
  "plan_id": "plan_basic",
  "payment_method_id": "pm_xxx" // optional, if using payment gateway
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT token
2. Validate plan exists and is active
3. Check if agency already has active subscription
4. Create subscription record:
   ```sql
   INSERT INTO subscriptions (agency_id, plan_id, status, start_date, end_date, monthly_price, payment_method_id)
   VALUES ($1, $2, 'active', CURRENT_DATE, CURRENT_DATE + INTERVAL '1 month', $3, $4)
   RETURNING *;
   ```
5. Create initial transaction record (if payment processed)
6. Update agency subscription status
7. Return subscription details

**Response:**
```json
{
  "success": true,
  "subscription": {
    "id": 456,
    "agency_id": 123,
    "plan_id": "plan_basic",
    "status": "active",
    "start_date": "2024-01-01",
    "end_date": "2024-02-01",
    "monthly_price": 29.99
  }
}
```

---

#### GET `/api/mobile/subscription`
**Purpose**: Get current agency subscription

**Authentication**: Required (JWT)

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Query current subscription:
   ```sql
   SELECT s.*, sp.name as plan_name, sp.features
   FROM subscriptions s
   JOIN subscription_plans sp ON s.plan_id = sp.id
   WHERE s.agency_id = $1 AND s.status = 'active'
   ORDER BY s.created_at DESC
   LIMIT 1;
   ```
3. Return subscription details

**Response:**
```json
{
  "subscription": {
    "id": 456,
    "agency_id": 123,
    "plan_id": "plan_basic",
    "plan_name": "Basic Plan",
    "status": "active",
    "start_date": "2024-01-01",
    "end_date": "2024-02-01",
    "monthly_price": 29.99,
    "features": {
      "max_territories": 5,
      "max_leads_per_month": 100
    }
  }
}
```

---

#### PUT `/api/mobile/subscription/upgrade`
**Purpose**: Upgrade to higher tier plan

**Authentication**: Required

**Request Body:**
```json
{
  "plan_id": "plan_premium",
  "prorated": true
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Get current subscription
3. Validate new plan exists and is higher tier
4. Calculate prorated amount if `prorated = true`
5. Update subscription:
   ```sql
   UPDATE subscriptions
   SET plan_id = $1, monthly_price = $2, updated_at = CURRENT_TIMESTAMP
   WHERE agency_id = $3 AND status = 'active'
   RETURNING *;
   ```
6. Create transaction for prorated difference
7. Return updated subscription

---

#### PUT `/api/mobile/subscription/downgrade`
**Purpose**: Downgrade to lower tier plan

**Authentication**: Required

**Request Body:**
```json
{
  "plan_id": "plan_basic",
  "immediate": false
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Get current subscription
3. Validate new plan is lower tier
4. If `immediate = false`: Schedule downgrade at end of billing period
5. If `immediate = true`: Downgrade immediately and prorate refund
6. Update subscription
7. Return updated subscription

---

#### POST `/api/mobile/subscription/cancel`
**Purpose**: Cancel subscription

**Authentication**: Required

**Request Body:**
```json
{
  "reason": "No longer needed", // optional
  "immediate": false
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Update subscription:
   ```sql
   UPDATE subscriptions
   SET status = 'cancelled', 
       cancelled_at = CURRENT_TIMESTAMP,
       cancellation_reason = $1
   WHERE agency_id = $2 AND status = 'active'
   RETURNING *;
   ```
3. If `immediate = true`: End access immediately
4. If `immediate = false`: Continue until end of billing period
5. Send cancellation confirmation email

---

#### GET `/api/mobile/subscription/invoices`
**Purpose**: Get billing history/invoices

**Authentication**: Required

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `limit` (optional): Results per page (default: 20)

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Query transactions with pagination:
   ```sql
   SELECT t.*, s.plan_id
   FROM transactions t
   LEFT JOIN subscriptions s ON t.subscription_id = s.id
   WHERE t.agency_id = $1
   ORDER BY t.transaction_date DESC
   LIMIT $2 OFFSET $3;
   ```
3. Return paginated results

**Response:**
```json
{
  "invoices": [
    {
      "id": 789,
      "amount": 29.99,
      "status": "completed",
      "transaction_date": "2024-01-01T00:00:00Z",
      "invoice_number": "INV-2024-001",
      "plan_id": "plan_basic"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 5
  }
}
```

---

#### PUT `/api/mobile/payment-method`
**Purpose**: Update payment method

**Authentication**: Required

**Request Body:**
```json
{
  "payment_method_id": "pm_xxx",
  "card_details": { ... } // optional
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Update subscription payment method:
   ```sql
   UPDATE subscriptions
   SET payment_method_id = $1, updated_at = CURRENT_TIMESTAMP
   WHERE agency_id = $2 AND status = 'active'
   RETURNING *;
   ```
3. Store card details securely (encrypted) if provided
4. Return success

---

### 1.3. Territory Management

#### GET `/api/mobile/territories`
**Purpose**: Get agency territories

**Authentication**: Required

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Query territories:
   ```sql
   SELECT id, zipcode, city, state, created_at
   FROM agency_territories
   WHERE agency_id = $1
   ORDER BY created_at DESC;
   ```
3. Return territories list

**Response:**
```json
{
  "territories": [
    {
      "id": 1,
      "zipcode": "75201",
      "city": "Dallas",
      "state": "TX"
    }
  ],
  "zipcodes": ["75201", "75202"] // legacy format support
}
```

---

#### POST `/api/mobile/territories`
**Purpose**: Add new territory

**Authentication**: Required

**Request Body:**
```json
{
  "zipcode": "75201",
  "city": "Dallas" // optional
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Get agency's current subscription to check territory limit
3. Check current territory count:
   ```sql
   SELECT COUNT(*) FROM agency_territories WHERE agency_id = $1;
   ```
4. Validate territory limit not exceeded
5. Insert territory:
   ```sql
   INSERT INTO agency_territories (agency_id, zipcode, city)
   VALUES ($1, $2, $3)
   ON CONFLICT (agency_id, zipcode) DO NOTHING
   RETURNING *;
   ```
6. Return created territory

**Error Cases:**
- 403: Territory limit exceeded
- 409: Territory already exists

---

#### PUT `/api/mobile/territories/:id`
**Purpose**: Update territory

**Authentication**: Required

**Request Body:**
```json
{
  "zipcode": "75201",
  "city": "Dallas"
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Verify territory belongs to agency:
   ```sql
   UPDATE agency_territories
   SET zipcode = $1, city = $2, updated_at = CURRENT_TIMESTAMP
   WHERE id = $3 AND agency_id = $4
   RETURNING *;
   ```
3. Return updated territory

**Error Cases:**
- 404: Territory not found or doesn't belong to agency

---

#### DELETE `/api/mobile/territories/:id`
**Purpose**: Remove territory

**Authentication**: Required

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Delete territory:
   ```sql
   DELETE FROM agency_territories
   WHERE id = $1 AND agency_id = $2
   RETURNING *;
   ```
3. Return success

---

### 1.4. Lead Management

#### GET `/api/mobile/leads`
**Purpose**: Get agency's assigned leads

**Authentication**: Required

**Query Parameters:**
- `status` (optional): Filter by status
- `from_date` (optional): ISO 8601 date
- `to_date` (optional): ISO 8601 date
- `limit` (optional): Max results

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Build query with filters:
   ```sql
   SELECT l.*, la.status as assignment_status, la.assigned_at
   FROM leads l
   JOIN lead_assignments la ON l.id = la.lead_id
   WHERE la.agency_id = $1
     AND ($2::VARCHAR IS NULL OR l.status = $2)
     AND ($3::TIMESTAMP IS NULL OR l.created_at >= $3)
     AND ($4::TIMESTAMP IS NULL OR l.created_at <= $4)
   ORDER BY la.assigned_at DESC
   LIMIT COALESCE($5, 50);
   ```
3. Return leads list

**Response:**
```json
{
  "leads": [
    {
      "id": 1001,
      "first_name": "John",
      "last_name": "Doe",
      "email": "john@example.com",
      "phone": "+1234567890",
      "status": "new",
      "assigned_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

---

#### PUT `/api/mobile/leads/:id/accept`
**Purpose**: Accept a lead assignment

**Authentication**: Required

**Request Body:**
```json
{
  "notes": "Interested customer" // optional
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Verify lead is assigned to agency:
   ```sql
   SELECT * FROM lead_assignments
   WHERE lead_id = $1 AND agency_id = $2 AND status = 'pending';
   ```
3. Update lead assignment:
   ```sql
   UPDATE lead_assignments
   SET status = 'accepted', accepted_at = CURRENT_TIMESTAMP
   WHERE lead_id = $1 AND agency_id = $2;
   ```
4. Update lead status:
   ```sql
   UPDATE leads
   SET status = 'contacted', notes = $1, updated_at = CURRENT_TIMESTAMP
   WHERE id = $2;
   ```
5. Create notification (optional)
6. Return success

---

#### PUT `/api/mobile/leads/:id/reject`
**Purpose**: Reject a lead assignment

**Authentication**: Required

**Request Body:**
```json
{
  "reason": "Not interested" // optional
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Verify lead is assigned to agency
3. Update lead assignment:
   ```sql
   UPDATE lead_assignments
   SET status = 'rejected', rejected_at = CURRENT_TIMESTAMP
   WHERE lead_id = $1 AND agency_id = $2;
   ```
4. Update lead:
   ```sql
   UPDATE leads
   SET status = 'rejected', rejection_reason = $1, rejected_at = CURRENT_TIMESTAMP
   WHERE id = $2;
   ```
5. **Round-Robin Logic**: Assign lead to next agency in the zipcode rotation
6. Return success

---

#### GET `/api/mobile/leads/:id`
**Purpose**: Get detailed information for a specific lead

**Authentication**: Required (JWT)

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Verify lead is assigned to agency:
   ```sql
   SELECT l.*, la.status as assignment_status, la.assigned_at, la.accepted_at
   FROM leads l
   JOIN lead_assignments la ON l.id = la.lead_id
   WHERE l.id = $1 AND la.agency_id = $2;
   ```
3. If lead not found or not assigned to agency, return 404
4. Return complete lead details

**Response:**
```json
{
  "id": 123,
  "first_name": "John",
  "last_name": "Doe",
  "email": "john@example.com",
  "phone": "+1234567890",
  "address": "123 Main St",
  "city": "Dallas",
  "state": "TX",
  "zipcode": "75201",
  "status": "new",
  "source": "portal_name",
  "notes": "Customer interested in services",
  "assigned_at": "2024-01-01T00:00:00Z",
  "accepted_at": null,
  "assignment_status": "pending",
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

**Error Cases:**
- 404: Lead not found or not assigned to agency
- 401: Invalid or missing token
- 500: Database error

---

#### PUT `/api/mobile/leads/:id/status`
**Purpose**: Update lead status (workflow management)

**Authentication**: Required (JWT)

**Request Body:**
```json
{
  "status": "contacted", // new, contacted, qualified, converted, rejected
  "notes": "Called customer, interested" // optional
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Verify lead is assigned to agency:
   ```sql
   SELECT * FROM lead_assignments
   WHERE lead_id = $1 AND agency_id = $2;
   ```
3. Validate status value (must be valid status)
4. Update lead status:
   ```sql
   UPDATE leads
   SET status = $1, 
       notes = COALESCE($2, notes),
       updated_at = CURRENT_TIMESTAMP
   WHERE id = $3
   RETURNING *;
   ```
5. Create status history entry (optional, if tracking status changes):
   ```sql
   INSERT INTO lead_status_history (lead_id, previous_status, new_status, changed_by_agency_id, notes, changed_at)
   VALUES ($1, (SELECT status FROM leads WHERE id = $1), $2, $3, $4, CURRENT_TIMESTAMP);
   ```
6. Return updated lead

**Status Workflow:**
- `new` → `contacted` → `qualified` → `converted`
- Can also transition to `rejected` from any state

**Error Cases:**
- 400: Invalid status value
- 404: Lead not found or not assigned to agency
- 403: Lead not assigned to this agency

---

#### PUT `/api/mobile/leads/:id/view`
**Purpose**: Mark lead as viewed (analytics tracking)

**Authentication**: Required (JWT)

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Verify lead is assigned to agency
3. Update lead assignment to track view:
   ```sql
   UPDATE lead_assignments
   SET last_viewed_at = CURRENT_TIMESTAMP,
       view_count = COALESCE(view_count, 0) + 1
   WHERE lead_id = $1 AND agency_id = $2
   RETURNING *;
   ```
4. If `last_viewed_at` column doesn't exist, you can track in a separate table:
   ```sql
   INSERT INTO lead_views (lead_id, agency_id, viewed_at)
   VALUES ($1, $2, CURRENT_TIMESTAMP)
   ON CONFLICT DO NOTHING;
   ```
5. Return success

**Use Case**: Track engagement analytics, identify hot leads (frequently viewed)

---

#### POST `/api/mobile/leads/:id/call`
**Purpose**: Track phone call made to lead (analytics)

**Authentication**: Required (JWT)

**Request Body:** (Optional - can be empty)
```json
{
  "duration_seconds": 120, // optional
  "call_outcome": "answered" // optional: answered, no_answer, voicemail, busy
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Verify lead is assigned to agency
3. Track call in database:
   ```sql
   INSERT INTO lead_interactions (
     lead_id, 
     agency_id, 
     interaction_type, 
     interaction_data, 
     created_at
   )
   VALUES ($1, $2, 'phone_call', jsonb_build_object(
     'duration_seconds', $3,
     'outcome', $4
   ), CURRENT_TIMESTAMP);
   ```
4. Update lead assignment call count:
   ```sql
   UPDATE lead_assignments
   SET call_count = COALESCE(call_count, 0) + 1,
       last_called_at = CURRENT_TIMESTAMP
   WHERE lead_id = $1 AND agency_id = $2;
   ```
5. Optionally update lead status to 'contacted' if still 'new':
   ```sql
   UPDATE leads
   SET status = 'contacted', updated_at = CURRENT_TIMESTAMP
   WHERE id = $1 AND status = 'new';
   ```
6. Return success

**Use Case**: Analytics on call engagement, ROI tracking, identify responsive leads

**Response:**
```json
{
  "success": true,
  "message": "Call tracked successfully",
  "lead_id": 123,
  "call_count": 1
}
```

---

#### POST `/api/mobile/leads/:id/notes`
**Purpose**: Add notes/comments to a lead

**Authentication**: Required (JWT)

**Request Body:**
```json
{
  "notes": "Customer interested in services. Follow up next week. Very responsive."
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Verify lead is assigned to agency
3. Get existing notes:
   ```sql
   SELECT notes FROM leads WHERE id = $1;
   ```
4. Append or replace notes (based on requirements):
   ```sql
   -- Option 1: Append to existing notes
   UPDATE leads
   SET notes = CONCAT(COALESCE(notes, ''), '\n', CURRENT_TIMESTAMP::TEXT, ': ', $1),
       updated_at = CURRENT_TIMESTAMP
   WHERE id = $2
   RETURNING *;
   
   -- Option 2: Store as separate notes entries (recommended for better tracking)
   INSERT INTO lead_notes (lead_id, agency_id, note_text, created_at)
   VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
   RETURNING *;
   ```
5. Return success

**Alternative Implementation (Better for History):**
Create a `lead_notes` table:
```sql
CREATE TABLE lead_notes (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER REFERENCES leads(id) ON DELETE CASCADE,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    note_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id INTEGER, -- if you track individual users
    INDEX(lead_id, agency_id)
);
```

**Response:**
```json
{
  "success": true,
  "message": "Notes added successfully",
  "note_id": 456,
  "lead_id": 123
}
```

**Get All Notes Endpoint (Optional Enhancement):**
```sql
SELECT * FROM lead_notes 
WHERE lead_id = $1 AND agency_id = $2 
ORDER BY created_at DESC;
```

---

## Section 2: Super Admin Portal APIs (`/api/admin/*`)

### 2.1. Admin Authentication

#### POST `/api/admin/auth/login`
**Purpose**: Admin login

**Request Body:**
```json
{
  "email": "admin@example.com",
  "password": "adminpassword"
}
```

**Implementation Steps:**
1. Find admin user by email in `users` table
2. Verify password hash
3. Check if user is active
4. Generate JWT token with `role: 'admin'` or `role: 'super_admin'`
5. Update `last_login` timestamp
6. Return token

**JWT Payload:**
```json
{
  "user_id": 1,
  "email": "admin@example.com",
  "role": "super_admin",
  "iat": 1234567890,
  "exp": 1234654290
}
```

---

### 2.2. View Subscriptions (Read-only)

#### GET `/api/admin/subscriptions`
**Purpose**: List all subscriptions

**Authentication**: Required (Admin JWT)

**Query Parameters:**
- `page`, `limit`, `status`, `agency_id`

**Implementation:**
```sql
SELECT s.*, a.email as agency_email, a.agency_name, sp.name as plan_name
FROM subscriptions s
JOIN agencies a ON s.agency_id = a.id
LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
WHERE ($1::INTEGER IS NULL OR s.agency_id = $1)
  AND ($2::VARCHAR IS NULL OR s.status = $2)
ORDER BY s.created_at DESC
LIMIT $3 OFFSET $4;
```

---

#### GET `/api/admin/agencies/:id/subscription`
**Purpose**: Get specific agency subscription

**Authentication**: Required (Admin JWT)

---

#### GET `/api/admin/subscriptions/analytics`
**Purpose**: Get subscription analytics

**Authentication**: Required (Admin JWT)

**Returns:**
- Total subscriptions
- Active vs Cancelled
- Revenue metrics
- Plan distribution

---

### 2.3. Support Actions (Limited)

#### PUT `/api/admin/agencies/:id/subscription/suspend`
**Purpose**: Suspend subscription (fraud, violations)

**Authentication**: Required (Super Admin only)

**Implementation:**
```sql
UPDATE subscriptions
SET status = 'suspended', updated_at = CURRENT_TIMESTAMP
WHERE agency_id = $1 AND status = 'active'
RETURNING *;
```

---

#### PUT `/api/admin/agencies/:id/subscription/reactivate`
**Purpose**: Reactivate suspended subscription

**Authentication**: Required (Super Admin only)

---

#### POST `/api/admin/agencies/:id/credits/add`
**Purpose**: Add bonus credits

**Authentication**: Required (Super Admin only)

**Implementation:**
```sql
INSERT INTO transactions (agency_id, amount, status, transaction_date, invoice_number)
VALUES ($1, $2, 'completed', CURRENT_TIMESTAMP, CONCAT('BONUS-', NOW()::TEXT));
```

---

#### POST `/api/admin/agencies/:id/credits/refund`
**Purpose**: Process refund

**Authentication**: Required (Super Admin only)

---

### 2.4. Agency Management

#### GET `/api/admin/agencies`
**Purpose**: List all agencies

**Authentication**: Required (Admin JWT)

**Query Parameters:** `page`, `limit`, `search`, `is_active`, `is_verified`

---

#### GET `/api/admin/agencies/:id`
**Purpose**: Get agency details

**Authentication**: Required (Admin JWT)

---

#### PUT `/api/admin/agencies/:id/verify`
**Purpose**: Verify/approve agency

**Authentication**: Required (Super Admin only)

**Implementation:**
```sql
UPDATE agencies
SET is_verified = TRUE, updated_at = CURRENT_TIMESTAMP
WHERE id = $1
RETURNING *;
```

---

#### DELETE `/api/admin/agencies/:id`
**Purpose**: Delete agency (if necessary)

**Authentication**: Required (Super Admin only)

**Note**: Implement soft delete or cascade deletion based on requirements

---

## Section 3: Webhook APIs (`/api/webhook/*`)

### POST `/api/webhook/leads`
**Purpose**: Receive lead data from public portals

**Authentication**: API Key (from `portals` table)

**Request Headers:**
```
X-API-Key: portal_api_key_here
```

**Request Body:**
```json
{
  "first_name": "John",
  "last_name": "Doe",
  "email": "john@example.com",
  "phone": "+1234567890",
  "zipcode": "75201",
  "source": "portal_name"
}
```

**Implementation Steps:**
1. Validate API key:
   ```sql
   SELECT * FROM portals WHERE api_key = $1 AND is_active = TRUE;
   ```
2. Create lead record:
   ```sql
   INSERT INTO leads (first_name, last_name, email, phone, zipcode, source, status)
   VALUES ($1, $2, $3, $4, $5, $6, 'new')
   RETURNING *;
   ```
3. **Round-Robin Assignment**: Assign lead to next agency in zipcode rotation
4. Audit webhook:
   ```sql
   INSERT INTO webhook_audit (portal_id, webhook_payload, lead_created_id, processed_at)
   VALUES ($1, $2, $3, CURRENT_TIMESTAMP);
   ```
5. Trigger push notifications to assigned agency devices
6. Return success

**Round-Robin Logic:**
```sql
-- Get current state for zipcode
SELECT * FROM round_robin_state WHERE zipcode = $1;

-- Get agencies with this zipcode in their territories
SELECT agency_id FROM agency_territories WHERE zipcode = $1;

-- Select next agency (round-robin)
-- Update round_robin_state
UPDATE round_robin_state
SET current_agency_index = (current_agency_index + 1) % agency_count,
    last_assigned_at = CURRENT_TIMESTAMP
WHERE zipcode = $1;

-- Create lead assignment
INSERT INTO lead_assignments (lead_id, agency_id, status)
VALUES ($1, $2, 'pending');
```

---

## Section 4: Device & Notification Management

### POST `/api/mobile/auth/register-device`
**Purpose**: Register device for push notifications

**Authentication**: Required (JWT)

**Request Body:**
```json
{
  "device_token": "fcm_token_or_apns_token",
  "platform": "ios", // or "android"
  "device_model": "iPhone 14",
  "app_version": "1.0.0"
}
```

**Implementation:**
```sql
INSERT INTO agency_devices (agency_id, device_token, platform, device_model, app_version)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (agency_id, device_token) 
DO UPDATE SET last_seen = CURRENT_TIMESTAMP, is_active = TRUE
RETURNING *;
```

---

### PUT `/api/mobile/auth/update-device`
**Purpose**: Update device token when it changes (e.g., FCM token refresh)

**Authentication**: Required (JWT)

**Request Body:**
```json
{
  "device_token": "new_fcm_token_or_apns_token",
  "app_version": "1.0.1", // optional
  "last_seen": "2024-01-01T00:00:00Z" // optional, auto-set
}
```

**Implementation:**
```sql
UPDATE agency_devices
SET device_token = $1,
    app_version = COALESCE($2, app_version),
    last_seen = CURRENT_TIMESTAMP,
    is_active = TRUE
WHERE agency_id = $3 AND device_token = $4
RETURNING *;
```

**Note**: If device_token doesn't exist, create new record:
```sql
INSERT INTO agency_devices (agency_id, device_token, platform, app_version, last_seen, is_active)
VALUES ($1, $2, (SELECT platform FROM agency_devices WHERE agency_id = $1 LIMIT 1), $3, CURRENT_TIMESTAMP, TRUE)
ON CONFLICT (agency_id, device_token) 
DO UPDATE SET 
    last_seen = CURRENT_TIMESTAMP,
    app_version = EXCLUDED.app_version,
    is_active = TRUE
RETURNING *;
```

---

### DELETE `/api/mobile/auth/unregister-device`
**Purpose**: Unregister device on logout

**Authentication**: Required (JWT)

**Implementation:**
```sql
UPDATE agency_devices
SET is_active = FALSE,
    last_seen = CURRENT_TIMESTAMP
WHERE agency_id = $1 AND device_token = $2;
```

**Alternative** (if you want to fully delete):
```sql
DELETE FROM agency_devices
WHERE agency_id = $1 AND device_token = $2;
```

**Note**: It's recommended to soft-delete (set `is_active = FALSE`) to maintain history for analytics.

---

## Section 5: Notification Management (`/api/mobile/notifications/*`)

### GET `/api/mobile/notifications/settings`
**Purpose**: Get user's notification preferences

**Authentication**: Required (JWT)

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Query notification settings:
   ```sql
   SELECT * FROM notification_settings
   WHERE agency_id = $1;
   ```
3. If no settings exist, return defaults:
   ```json
   {
     "push_enabled": true,
     "email_enabled": true,
     "sms_enabled": false,
     "sound_enabled": true,
     "vibration_enabled": true,
     "quiet_hours": null,
     "notification_types": ["lead_assigned", "subscription_expiring"]
   }
   ```
4. Return settings

**Database Schema Addition:**
```sql
CREATE TABLE notification_settings (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE UNIQUE,
    push_enabled BOOLEAN DEFAULT TRUE,
    email_enabled BOOLEAN DEFAULT TRUE,
    sms_enabled BOOLEAN DEFAULT FALSE,
    sound_enabled BOOLEAN DEFAULT TRUE,
    vibration_enabled BOOLEAN DEFAULT TRUE,
    quiet_hours JSONB, -- {"start": "22:00", "end": "08:00"}
    notification_types TEXT[] DEFAULT ARRAY['lead_assigned', 'subscription_expiring'],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Response:**
```json
{
  "push_enabled": true,
  "email_enabled": true,
  "sms_enabled": false,
  "sound_enabled": true,
  "vibration_enabled": true,
  "quiet_hours": {
    "start": "22:00",
    "end": "08:00"
  },
  "notification_types": ["lead_assigned", "subscription_expiring"]
}
```

---

### PUT `/api/mobile/notifications/settings`
**Purpose**: Update notification preferences

**Authentication**: Required (JWT)

**Request Body:**
```json
{
  "push_enabled": true,
  "email_enabled": false,
  "sms_enabled": false,
  "sound_enabled": true,
  "vibration_enabled": true,
  "quiet_hours": {
    "start": "22:00",
    "end": "08:00"
  },
  "notification_types": ["lead_assigned"]
}
```

**Implementation Steps:**
1. Extract `agency_id` from JWT
2. Upsert notification settings:
   ```sql
   INSERT INTO notification_settings (
     agency_id, 
     push_enabled, 
     email_enabled, 
     sms_enabled,
     sound_enabled,
     vibration_enabled,
     quiet_hours,
     notification_types,
     updated_at
   )
   VALUES ($1, $2, $3, $4, $5, $6, $7::JSONB, $8, CURRENT_TIMESTAMP)
   ON CONFLICT (agency_id)
   DO UPDATE SET
     push_enabled = EXCLUDED.push_enabled,
     email_enabled = EXCLUDED.email_enabled,
     sms_enabled = EXCLUDED.sms_enabled,
     sound_enabled = EXCLUDED.sound_enabled,
     vibration_enabled = EXCLUDED.vibration_enabled,
     quiet_hours = EXCLUDED.quiet_hours,
     notification_types = EXCLUDED.notification_types,
     updated_at = CURRENT_TIMESTAMP
   RETURNING *;
   ```
3. Return updated settings

**Partial Update Support:**
If only some fields are provided, update only those:
```sql
UPDATE notification_settings
SET 
  push_enabled = COALESCE($1, push_enabled),
  email_enabled = COALESCE($2, email_enabled),
  sms_enabled = COALESCE($3, sms_enabled),
  sound_enabled = COALESCE($4, sound_enabled),
  vibration_enabled = COALESCE($5, vibration_enabled),
  quiet_hours = COALESCE($6::JSONB, quiet_hours),
  notification_types = COALESCE($7, notification_types),
  updated_at = CURRENT_TIMESTAMP
WHERE agency_id = $8
RETURNING *;
```

---

## Section 6: Password Reset (`/api/mobile/auth/forgot-password`)

### POST `/api/mobile/auth/forgot-password`
**Purpose**: Request password reset email

**Authentication**: Not required (public endpoint)

**Request Body:**
```json
{
  "email": "agency@example.com"
}
```

**Implementation Steps:**
1. Find agency by email:
   ```sql
   SELECT id, email, agency_name FROM agencies WHERE email = $1 AND is_active = TRUE;
   ```
2. If agency not found, still return success (security best practice - don't reveal if email exists)
3. Generate password reset token (secure random string, 32+ characters):
   ```javascript
   const resetToken = crypto.randomBytes(32).toString('hex');
   const resetTokenExpiry = new Date(Date.now() + 3600000); // 1 hour
   ```
4. Store reset token in database:
   ```sql
   UPDATE agencies
   SET password_reset_token = $1,
       password_reset_expires = $2,
       updated_at = CURRENT_TIMESTAMP
   WHERE email = $3
   RETURNING *;
   ```
   
   **Alternative**: Use separate table for reset tokens:
   ```sql
   CREATE TABLE password_reset_tokens (
       id SERIAL PRIMARY KEY,
       agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
       token VARCHAR(64) UNIQUE NOT NULL,
       expires_at TIMESTAMP NOT NULL,
       used_at TIMESTAMP,
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   
   INSERT INTO password_reset_tokens (agency_id, token, expires_at)
   VALUES ($1, $2, $3);
   ```
5. Send password reset email with link:
   ```
   https://yourdomain.com/reset-password?token={resetToken}
   ```
   Or use mobile deep link:
   ```
   yourapp://reset-password?token={resetToken}
   ```
6. Return success (generic message for security)

**Response:**
```json
{
  "success": true,
  "message": "If an account with that email exists, a password reset link has been sent."
}
```

**Error Handling:**
- Always return success (200) to prevent email enumeration attacks
- Log attempts for security monitoring
- Rate limit: Max 3 requests per email per hour

**Rate Limiting Implementation:**
```sql
-- Check recent reset requests
SELECT COUNT(*) FROM password_reset_tokens
WHERE agency_id = $1 
  AND created_at > NOW() - INTERVAL '1 hour';
```

If count >= 3, return error:
```json
{
  "success": false,
  "message": "Too many reset attempts. Please try again later."
}
```

---

## Security Implementation

### 1. JWT Token Management

**Token Generation:**
```javascript
const jwt = require('jsonwebtoken');

function generateToken(payload) {
  return jwt.sign(
    payload,
    process.env.JWT_SECRET,
    { expiresIn: '24h' }
  );
}
```

**Token Validation Middleware:**
```javascript
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, decoded) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = decoded; // Attach user info to request
    next();
  });
}
```

**Role-Based Authorization:**
```javascript
function requireRole(allowedRoles) {
  return (req, res, next) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
}

// Usage:
app.put('/api/admin/agencies/:id', 
  authenticateToken, 
  requireRole(['super_admin']), 
  updateAgencyHandler
);
```

### 2. Password Hashing

**Hashing on Registration:**
```javascript
const bcrypt = require('bcrypt');

async function hashPassword(password) {
  const saltRounds = 10;
  return await bcrypt.hash(password, saltRounds);
}

// Store: password_hash = await hashPassword(password);
```

**Verification on Login:**
```javascript
async function verifyPassword(password, hash) {
  return await bcrypt.compare(password, hash);
}
```

### 3. Input Validation

**Use validation libraries:**
- Node.js: `joi`, `express-validator`
- Python: `pydantic`, `marshmallow`
- Java: Bean Validation (JSR 303)

**Example (Node.js with Joi):**
```javascript
const Joi = require('joi');

const registerSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(8).required(),
  agency_name: Joi.string().min(3).required(),
  phone: Joi.string().optional()
});

function validateRegister(req, res, next) {
  const { error } = registerSchema.validate(req.body);
  if (error) {
    return res.status(400).json({ error: error.details[0].message });
  }
  next();
}
```

### 4. SQL Injection Prevention

**ALWAYS use parameterized queries:**
```javascript
// ❌ BAD - SQL Injection vulnerability
const query = `SELECT * FROM agencies WHERE email = '${email}'`;

// ✅ GOOD - Parameterized query
const query = 'SELECT * FROM agencies WHERE email = $1';
await db.query(query, [email]);
```

### 5. Rate Limiting

**Implement rate limiting:**
```javascript
const rateLimit = require('express-rate-limit');

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/api/', apiLimiter);
```

---

## Error Handling

### Standard Error Response Format

```json
{
  "success": false,
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": { ... } // optional
}
```

### HTTP Status Codes

- `200`: Success
- `201`: Created
- `400`: Bad Request (validation errors)
- `401`: Unauthorized (missing/invalid token)
- `403`: Forbidden (insufficient permissions)
- `404`: Not Found
- `409`: Conflict (duplicate resource)
- `410`: Gone (expired resource)
- `422`: Unprocessable Entity
- `500`: Internal Server Error

### Error Handling Example

```javascript
app.use((err, req, res, next) => {
  console.error('Error:', err);
  
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      success: false,
      error: err.message,
      code: 'VALIDATION_ERROR'
    });
  }
  
  if (err.name === 'UnauthorizedError') {
    return res.status(401).json({
      success: false,
      error: 'Authentication required',
      code: 'UNAUTHORIZED'
    });
  }
  
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    code: 'INTERNAL_ERROR'
  });
});
```

---

## Database Connection Management

### Connection Pooling

**Node.js (pg):**
```javascript
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 20, // Maximum pool size
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

module.exports = pool;
```

**Python (psycopg2):**
```python
import psycopg2.pool

connection_pool = psycopg2.pool.ThreadedConnectionPool(
    minconn=1,
    maxconn=20,
    host=os.getenv('DB_HOST'),
    port=os.getenv('DB_PORT'),
    database=os.getenv('DB_NAME'),
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD')
)
```

### Query Helper Functions

```javascript
async function query(text, params) {
  const start = Date.now();
  try {
    const res = await pool.query(text, params);
    const duration = Date.now() - start;
    console.log('Executed query', { text, duration, rows: res.rowCount });
    return res;
  } catch (error) {
    console.error('Query error', { text, error: error.message });
    throw error;
  }
}
```

---

## Push Notification Integration

### Firebase Cloud Messaging (FCM)

```javascript
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function sendPushNotification(deviceTokens, title, message, data = {}) {
  const message = {
    notification: {
      title: title,
      body: message,
    },
    data: data,
    tokens: deviceTokens, // Array of FCM tokens
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log('Successfully sent messages:', response.successCount);
    return response;
  } catch (error) {
    console.error('Error sending messages:', error);
    throw error;
  }
}

// Usage in lead assignment:
async function assignLeadToAgency(leadId, agencyId) {
  // ... create lead assignment ...
  
  // Get agency devices
  const devices = await query(
    'SELECT device_token FROM agency_devices WHERE agency_id = $1 AND is_active = TRUE',
    [agencyId]
  );
  
  if (devices.rows.length > 0) {
    const tokens = devices.rows.map(r => r.device_token);
    await sendPushNotification(
      tokens,
      'New Lead Assigned',
      'You have a new lead assignment',
      { lead_id: leadId, type: 'lead_assigned' }
    );
    
    // Create in-app notification
    await query(
      'INSERT INTO notifications (agency_id, title, message, type, related_lead_id) VALUES ($1, $2, $3, $4, $5)',
      [agencyId, 'New Lead Assigned', 'You have a new lead assignment', 'lead_assigned', leadId]
    );
  }
}
```

---

## Round-Robin Lead Assignment Algorithm

### Implementation

```sql
-- Function to get next agency for round-robin assignment
CREATE OR REPLACE FUNCTION get_next_agency_for_zipcode(p_zipcode VARCHAR)
RETURNS INTEGER AS $$
DECLARE
  v_agency_id INTEGER;
  v_current_index INTEGER;
  v_agency_count INTEGER;
  v_agencies INTEGER[];
BEGIN
  -- Get or create round-robin state
  INSERT INTO round_robin_state (zipcode, current_agency_index, agency_count)
  VALUES (p_zipcode, 0, 0)
  ON CONFLICT (zipcode) DO NOTHING;
  
  -- Get agencies with this zipcode
  SELECT ARRAY_AGG(agency_id ORDER BY agency_id), COUNT(*)
  INTO v_agencies, v_agency_count
  FROM agency_territories
  WHERE zipcode = p_zipcode
    AND agency_id IN (
      SELECT id FROM agencies WHERE is_active = TRUE AND is_verified = TRUE
    );
  
  IF v_agency_count = 0 THEN
    RETURN NULL; -- No agencies for this zipcode
  END IF;
  
  -- Get current index and update
  SELECT current_agency_index INTO v_current_index
  FROM round_robin_state
  WHERE zipcode = p_zipcode;
  
  -- Calculate next agency
  v_agency_id := v_agencies[(v_current_index % v_agency_count) + 1];
  
  -- Update state
  UPDATE round_robin_state
  SET current_agency_index = (current_agency_index + 1) % v_agency_count,
      agency_count = v_agency_count,
      last_assigned_at = CURRENT_TIMESTAMP
  WHERE zipcode = p_zipcode;
  
  RETURN v_agency_id;
END;
$$ LANGUAGE plpgsql;
```

---

## Testing Strategy

### 1. Unit Tests
- Test individual functions/methods
- Mock database calls
- Test validation logic

### 2. Integration Tests
- Test API endpoints with test database
- Test authentication flows
- Test database transactions

### 3. End-to-End Tests
- Test complete user flows
- Test webhook processing
- Test round-robin assignment

### Example Test (Node.js with Jest):

```javascript
describe('POST /api/mobile/auth/register', () => {
  test('should register new agency', async () => {
    const response = await request(app)
      .post('/api/mobile/auth/register')
      .send({
        email: 'test@example.com',
        password: 'password123',
        agency_name: 'Test Agency'
      });
    
    expect(response.status).toBe(201);
    expect(response.body.success).toBe(true);
    expect(response.body.data.email).toBe('test@example.com');
  });
  
  test('should reject duplicate email', async () => {
    // ... test duplicate registration
  });
});
```

---

## Environment Configuration

### Environment Variables

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=lead_marketplace
DB_USER=postgres
DB_PASSWORD=secure_password

# JWT
JWT_SECRET=your_super_secret_jwt_key_here
JWT_EXPIRY=24h

# Server
PORT=3002
NODE_ENV=production

# Email Service
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=your_sendgrid_api_key

# Push Notifications
FCM_SERVER_KEY=your_fcm_server_key

# CORS
ALLOWED_ORIGINS=https://mobileapp.example.com,https://admin.example.com

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
```

---

## Deployment Checklist

### Pre-Deployment
- [ ] All environment variables configured
- [ ] Database migrations run
- [ ] SSL/TLS certificates installed
- [ ] Database backups configured
- [ ] Monitoring/logging setup
- [ ] Rate limiting configured
- [ ] CORS properly configured
- [ ] Error handling tested
- [ ] Security audit completed

### Post-Deployment
- [ ] Health check endpoint responding
- [ ] Database connections working
- [ ] JWT authentication working
- [ ] API endpoints responding correctly
- [ ] Push notifications working
- [ ] Webhook processing working
- [ ] Round-robin assignment working
- [ ] Logs being captured
- [ ] Performance metrics being tracked

---

## Monitoring & Logging

### Structured Logging

```javascript
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
  ],
});

// Log API requests
app.use((req, res, next) => {
  logger.info('API Request', {
    method: req.method,
    path: req.path,
    ip: req.ip,
    timestamp: new Date().toISOString()
  });
  next();
});
```

### Health Check Endpoint

```javascript
app.get('/api/health', async (req, res) => {
  try {
    // Check database connection
    await pool.query('SELECT 1');
    
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      database: 'connected',
      uptime: process.uptime()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      database: 'disconnected',
      error: error.message
    });
  }
});
```

---

## API Documentation

Generate API documentation using:
- **Swagger/OpenAPI**: Auto-generate docs from code
- **Postman Collection**: Export for testing
- **API Blueprint**: Markdown-based docs

### Swagger Example (Node.js):

```javascript
const swaggerJsdoc = require('swagger-jsdoc');

const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Lead Marketplace API',
      version: '1.0.0',
      description: 'Middleware API for Lead Marketplace',
    },
    servers: [
      {
        url: 'http://localhost:3002',
        description: 'Development server',
      },
    ],
  },
  apis: ['./routes/**/*.js'], // Path to API files
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
```

---

## Performance Optimization

### 1. Database Indexing

```sql
-- Critical indexes
CREATE INDEX idx_agencies_email ON agencies(email);
CREATE INDEX idx_leads_agency_id ON leads(assigned_to_agency_id);
CREATE INDEX idx_lead_assignments_agency ON lead_assignments(agency_id, status);
CREATE INDEX idx_agency_territories_zipcode ON agency_territories(zipcode);
CREATE INDEX idx_subscriptions_agency_status ON subscriptions(agency_id, status);
```

### 2. Query Optimization

- Use `EXPLAIN ANALYZE` to optimize slow queries
- Avoid N+1 queries (use JOINs)
- Use pagination for large result sets
- Cache frequently accessed data (Redis optional)

### 3. Connection Pooling

- Configure appropriate pool size
- Monitor connection usage
- Handle connection timeouts gracefully

---

## Complete Endpoint Summary

### Mobile App APIs - 28 Endpoints Total ✅

**Registration & Onboarding (3)**
1. POST `/api/mobile/auth/register`
2. POST `/api/mobile/auth/verify-email`
3. POST `/api/mobile/auth/login`

**Subscription Management (8)**
4. GET `/api/mobile/subscription/plans`
5. POST `/api/mobile/subscription/subscribe`
6. GET `/api/mobile/subscription`
7. PUT `/api/mobile/subscription/upgrade`
8. PUT `/api/mobile/subscription/downgrade`
9. POST `/api/mobile/subscription/cancel`
10. GET `/api/mobile/subscription/invoices`
11. PUT `/api/mobile/payment-method`

**Territory Management (4)**
12. GET `/api/mobile/territories`
13. POST `/api/mobile/territories`
14. PUT `/api/mobile/territories/:id`
15. DELETE `/api/mobile/territories/:id`

**Lead Management - Basic (3)**
16. GET `/api/mobile/leads`
17. PUT `/api/mobile/leads/:id/accept`
18. PUT `/api/mobile/leads/:id/reject`

**Lead Management - Extended (5)** ⭐ **CRITICAL**
19. GET `/api/mobile/leads/:id` - Get lead detail
20. PUT `/api/mobile/leads/:id/status` - Update status
21. PUT `/api/mobile/leads/:id/view` - Mark as viewed
22. POST `/api/mobile/leads/:id/call` - Track call
23. POST `/api/mobile/leads/:id/notes` - Add notes

**Notification Management (2)**
24. GET `/api/mobile/notifications/settings`
25. PUT `/api/mobile/notifications/settings`

**Device Management (3)** ⭐ **CRITICAL**
26. POST `/api/mobile/auth/register-device`
27. PUT `/api/mobile/auth/update-device`
28. DELETE `/api/mobile/auth/unregister-device`

**Password Reset (1)**
29. POST `/api/mobile/auth/forgot-password`

**Total: 29 endpoints** (includes forgot-password)

---

## Additional Database Tables Required

For full functionality, create these additional tables:

**Required Tables:**
- `notification_settings` - Notification preferences (Section 5)
- `password_reset_tokens` - Secure password reset (Section 6)

**Recommended Tables (for better tracking):**
- `lead_notes` - Lead notes history
- `lead_interactions` - Call/email tracking
- `lead_status_history` - Status change audit trail
- `lead_views` - View tracking analytics

All table schemas are provided in the Database Schema Requirements section above.

---

## Implementation Priority

### Phase 1: Critical (Must Implement First) ⭐
- **Device Management (3)**: Push notifications won't work without these
- **Lead Management Extended (5)**: Core features broken without these

**Total**: 8 critical endpoints

### Phase 2: Essential
- **Notification Management (2)**: Settings incomplete
- **Password Reset (1)**: User experience issue

**Total**: 3 essential endpoints

### Phase 3: Core (Already Documented)
- **Registration & Onboarding (3)**
- **Subscription Management (8)**
- **Territory Management (4)**
- **Lead Management Basic (3)**

**Total**: 18 core endpoints

---

## Conclusion

This guide provides a comprehensive foundation for developing the backend API middleware layer. Key takeaways:

1. **This API is the ONLY system that touches the database**
2. **Implement all 28 mobile endpoints** (not just 18) + admin endpoints + webhooks
3. **Use JWT authentication with role-based authorization**
4. **Implement round-robin lead assignment**
5. **Handle push notifications**
6. **Follow security best practices**
7. **Implement comprehensive error handling**
8. **Set up monitoring and logging**

### Critical Implementation Notes:

- **10 additional endpoints** beyond the original 18 are required for full functionality
- **5 lead management extensions** are critical for core features
- **3 device management endpoints** are critical for push notifications
- All endpoints are fully documented with SQL queries, request/response formats, and error handling

For detailed implementation of each endpoint, refer to the sections above. For questions or clarifications, refer to:
- Architecture diagram (beginning of this document)
- Mobile app API documentation (`MOBILE_API_ENDPOINTS.md`)
- Endpoint analysis report (`ENDPOINT_ANALYSIS_REPORT.md`)
- Implementation checklist (`COMPLETE_API_IMPLEMENTATION_CHECKLIST.md`)

---

**Last Updated**: Development Guide v2.0 - Complete 28 Endpoint Implementation  
**Total Endpoints**: 28 Mobile + 11 Admin + Webhooks  
**Backend Repository**: Separate repository  
**Mobile App Repository**: Separate repository (ready to connect)  
**Super Admin Portal**: Separate repository

