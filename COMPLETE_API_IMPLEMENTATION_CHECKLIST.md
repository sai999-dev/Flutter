# Complete API Implementation Checklist - All 28 Endpoints

## Backend Implementation Status

This checklist ensures all **28 mobile API endpoints** are properly implemented in the backend API middleware layer.

---

## ✅ Endpoint Implementation Checklist

### 1. Registration & Onboarding (3 Endpoints)

- [ ] **POST `/api/mobile/auth/register`**
  - [ ] Validate email format
  - [ ] Check email uniqueness
  - [ ] Hash password with bcrypt/Argon2
  - [ ] Generate 6-digit verification code
  - [ ] Set verification expiration (24 hours)
  - [ ] Insert into `agencies` table
  - [ ] Send verification email
  - [ ] Return success response (no JWT yet)

- [ ] **POST `/api/mobile/auth/verify-email`**
  - [ ] Validate verification code
  - [ ] Check code expiration
  - [ ] Update `is_verified = TRUE`
  - [ ] Generate JWT token
  - [ ] Return token and agency data

- [ ] **POST `/api/mobile/auth/login`**
  - [ ] Find agency by email
  - [ ] Verify password hash
  - [ ] Check `is_verified = TRUE`
  - [ ] Check `is_active = TRUE`
  - [ ] Update `last_login`
  - [ ] Generate JWT token (24h expiry)
  - [ ] Return token and profile

---

### 2. Subscription Management - Self-Service (8 Endpoints)

- [ ] **GET `/api/mobile/subscription/plans`**
  - [ ] Query active plans from `subscription_plans` table
  - [ ] Filter by `is_active = TRUE`
  - [ ] Return plans array (public endpoint)

- [ ] **POST `/api/mobile/subscription/subscribe`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Validate plan exists and is active
  - [ ] Check for existing active subscription
  - [ ] Create subscription record
  - [ ] Create initial transaction
  - [ ] Return subscription details

- [ ] **GET `/api/mobile/subscription`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Query current active subscription
  - [ ] Join with `subscription_plans` for plan details
  - [ ] Return subscription with plan info

- [ ] **PUT `/api/mobile/subscription/upgrade`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Validate new plan is higher tier
  - [ ] Calculate prorated amount if requested
  - [ ] Update subscription
  - [ ] Create transaction for difference
  - [ ] Return updated subscription

- [ ] **PUT `/api/mobile/subscription/downgrade`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Validate new plan is lower tier
  - [ ] Handle immediate vs end-of-period
  - [ ] Update subscription
  - [ ] Return updated subscription

- [ ] **POST `/api/mobile/subscription/cancel`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Update subscription status to 'cancelled'
  - [ ] Store cancellation reason
  - [ ] Handle immediate vs delayed cancellation
  - [ ] Send confirmation email
  - [ ] Return success

- [ ] **GET `/api/mobile/subscription/invoices`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Query `transactions` table with pagination
  - [ ] Join with subscriptions for plan info
  - [ ] Return paginated invoices list

- [ ] **PUT `/api/mobile/payment-method`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Update subscription `payment_method_id`
  - [ ] Store card details securely (encrypted)
  - [ ] Return success

---

### 3. Territory Management (4 Endpoints)

- [ ] **GET `/api/mobile/territories`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Query `agency_territories` for agency
  - [ ] Return territories list
  - [ ] Also return `zipcodes` array for backward compatibility

- [ ] **POST `/api/mobile/territories`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Get subscription to check territory limit
  - [ ] Check current territory count
  - [ ] Validate limit not exceeded
  - [ ] Insert territory (ON CONFLICT DO NOTHING)
  - [ ] Return created territory

- [ ] **PUT `/api/mobile/territories/:id`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Verify territory belongs to agency
  - [ ] Update territory fields
  - [ ] Return updated territory

- [ ] **DELETE `/api/mobile/territories/:id`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Verify territory belongs to agency
  - [ ] Delete territory
  - [ ] Return success

---

### 4. Lead Management - Basic (3 Endpoints)

- [ ] **GET `/api/mobile/leads`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Build query with filters (status, dates, limit)
  - [ ] Join `leads` with `lead_assignments`
  - [ ] Filter by `agency_id`
  - [ ] Apply query parameters
  - [ ] Return leads array

- [ ] **PUT `/api/mobile/leads/:id/accept`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Verify lead assigned to agency
  - [ ] Update `lead_assignments` status to 'accepted'
  - [ ] Update lead status to 'contacted'
  - [ ] Create notification
  - [ ] Return success

- [ ] **PUT `/api/mobile/leads/:id/reject`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Verify lead assigned to agency
  - [ ] Update `lead_assignments` status to 'rejected'
  - [ ] Update lead with rejection reason
  - [ ] **Round-robin**: Assign to next agency
  - [ ] Return success

---

### 5. Lead Management - Extended (5 Endpoints) ⭐ **CRITICAL**

- [ ] **GET `/api/mobile/leads/:id`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Verify lead assigned to agency
  - [ ] Join with `lead_assignments` for assignment status
  - [ ] Return complete lead details
  - [ ] Return 404 if not assigned to agency

- [ ] **PUT `/api/mobile/leads/:id/status`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Verify lead assigned to agency
  - [ ] Validate status value
  - [ ] Update lead status
  - [ ] Update notes if provided
  - [ ] (Optional) Create status history entry
  - [ ] Return updated lead

- [ ] **PUT `/api/mobile/leads/:id/view`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Verify lead assigned to agency
  - [ ] Update `lead_assignments` view tracking
  - [ ] Increment view count
  - [ ] (Optional) Insert into `lead_views` table
  - [ ] Return success

- [ ] **POST `/api/mobile/leads/:id/call`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Verify lead assigned to agency
  - [ ] Insert into `lead_interactions` table
  - [ ] Update `lead_assignments` call count
  - [ ] Update `last_called_at`
  - [ ] (Optional) Update lead status to 'contacted' if 'new'
  - [ ] Return success with call count

- [ ] **POST `/api/mobile/leads/:id/notes`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Verify lead assigned to agency
  - [ ] (Recommended) Insert into `lead_notes` table
  - [ ] (Alternative) Append to `leads.notes` field
  - [ ] Return success with note_id

---

### 6. Notification Management (2 Endpoints)

- [ ] **GET `/api/mobile/notifications/settings`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Query `notification_settings` table
  - [ ] Return defaults if not found
  - [ ] Return settings object

- [ ] **PUT `/api/mobile/notifications/settings`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Upsert into `notification_settings`
  - [ ] Support partial updates (only provided fields)
  - [ ] Return updated settings

---

### 7. Device Management (3 Endpoints) ⭐ **CRITICAL**

- [ ] **POST `/api/mobile/auth/register-device`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Insert or update `agency_devices` table
  - [ ] ON CONFLICT update `last_seen` and `is_active`
  - [ ] Store platform, device_model, app_version
  - [ ] Return success

- [ ] **PUT `/api/mobile/auth/update-device`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Update device token
  - [ ] Update `last_seen` timestamp
  - [ ] Handle case where device doesn't exist (create)
  - [ ] Return success

- [ ] **DELETE `/api/mobile/auth/unregister-device`**
  - [ ] Extract `agency_id` from JWT
  - [ ] Get device_token from request (or from JWT payload)
  - [ ] Soft delete: Set `is_active = FALSE`
  - [ ] (Alternative) Hard delete from table
  - [ ] Return success

---

### 8. Password Reset (1 Endpoint)

- [ ] **POST `/api/mobile/auth/forgot-password`**
  - [ ] Find agency by email (do not reveal if exists)
  - [ ] Generate secure reset token (32+ chars)
  - [ ] Set expiration (1 hour)
  - [ ] Store in `password_reset_tokens` table
  - [ ] Implement rate limiting (max 3/hour)
  - [ ] Send reset email with token
  - [ ] Always return success (prevent email enumeration)

---

## Database Tables Required

### Core Tables (Already Documented)
- [x] agencies
- [x] subscriptions
- [x] subscription_plans
- [x] agency_territories
- [x] leads
- [x] lead_assignments
- [x] users (admin)
- [x] transactions
- [x] agency_devices
- [x] notifications
- [x] portals
- [x] webhook_audit
- [x] round_robin_state

### Additional Tables Needed for Extended Features
- [ ] **notification_settings** - For notification preferences
- [ ] **lead_notes** - For lead notes history (recommended)
- [ ] **lead_interactions** - For call/email tracking (recommended)
- [ ] **lead_status_history** - For status change tracking (optional)
- [ ] **lead_views** - For view tracking (optional)
- [ ] **password_reset_tokens** - For password reset (recommended)

---

## Security Implementation Checklist

- [ ] JWT token generation and validation
- [ ] Password hashing (bcrypt/Argon2)
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention (parameterized queries only)
- [ ] Rate limiting on sensitive endpoints
- [ ] CORS configuration
- [ ] HTTPS enforcement (production)
- [ ] Error message sanitization (don't leak internal details)

---

## Error Handling Checklist

- [ ] Standard error response format
- [ ] Proper HTTP status codes (200, 400, 401, 403, 404, 500)
- [ ] User-friendly error messages
- [ ] Comprehensive error logging
- [ ] Error monitoring/alerting setup

---

## Testing Checklist

### Unit Tests
- [ ] Test each endpoint with valid inputs
- [ ] Test authentication failures
- [ ] Test authorization failures (wrong agency_id)
- [ ] Test validation errors
- [ ] Test database errors

### Integration Tests
- [ ] Test complete user flows
- [ ] Test round-robin assignment
- [ ] Test subscription lifecycle
- [ ] Test lead workflow (accept/reject/status updates)

### Security Tests
- [ ] Test SQL injection prevention
- [ ] Test JWT token validation
- [ ] Test rate limiting
- [ ] Test CORS configuration

---

## Performance Optimization

- [ ] Database indexes created:
  - [ ] `idx_agencies_email`
  - [ ] `idx_leads_agency_id`
  - [ ] `idx_lead_assignments_agency`
  - [ ] `idx_agency_territories_zipcode`
  - [ ] `idx_subscriptions_agency_status`
  - [ ] `idx_notification_settings_agency`
  - [ ] `idx_agency_devices_agency_token`

- [ ] Connection pooling configured
- [ ] Query optimization (EXPLAIN ANALYZE)
- [ ] Caching strategy for frequently accessed data

---

## Documentation

- [ ] API documentation generated (Swagger/OpenAPI)
- [ ] Postman collection created
- [ ] Endpoint examples provided
- [ ] Error codes documented
- [ ] Authentication flow documented

---

## Deployment Checklist

- [ ] Environment variables configured
- [ ] Database migrations run
- [ ] SSL/TLS certificates installed
- [ ] Health check endpoint working (`/api/health`)
- [ ] Monitoring/logging configured
- [ ] Backup strategy in place

---

## Summary

**Total Endpoints to Implement**: **28**

**Status**:
- ✅ **18 endpoints**: Core functionality (registration, subscription, territory, basic leads)
- ❌ **10 endpoints**: Extended functionality (lead details, status, notes, calls, notifications, devices)

**Priority**:
- **CRITICAL**: Lead management extensions (5), Device management (3)
- **MEDIUM**: Notification management (2)

**All endpoints are documented in**: `BACKEND_API_DEVELOPMENT_GUIDE.md`

---

**Last Updated**: Complete implementation guide  
**Backend Repository**: Separate repository  
**Mobile App**: Ready to connect once all 28 endpoints are implemented

