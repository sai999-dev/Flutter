# Backend API Endpoint Quick Reference - All 28 Endpoints

## Complete Endpoint List with Implementation Status

### Mobile App APIs - 28 Endpoints

#### Registration & Onboarding (3)
1. ✅ `POST /api/mobile/auth/register` - Register new agency
2. ✅ `POST /api/mobile/auth/verify-email` - Verify email with code
3. ✅ `POST /api/mobile/auth/login` - Agency login

#### Subscription Management - Self-Service (8)
4. ✅ `GET /api/mobile/subscription/plans` - Get available plans (public)
5. ✅ `POST /api/mobile/subscription/subscribe` - Subscribe to plan
6. ✅ `GET /api/mobile/subscription` - Get current subscription
7. ✅ `PUT /api/mobile/subscription/upgrade` - Upgrade plan
8. ✅ `PUT /api/mobile/subscription/downgrade` - Downgrade plan
9. ✅ `POST /api/mobile/subscription/cancel` - Cancel subscription
10. ✅ `GET /api/mobile/subscription/invoices` - Get billing history
11. ✅ `PUT /api/mobile/payment-method` - Update payment method

#### Territory Management (4)
12. ✅ `GET /api/mobile/territories` - Get agency territories
13. ✅ `POST /api/mobile/territories` - Add territory
14. ✅ `PUT /api/mobile/territories/:id` - Update territory
15. ✅ `DELETE /api/mobile/territories/:id` - Remove territory

#### Lead Management - Basic (3)
16. ✅ `GET /api/mobile/leads` - Get assigned leads
17. ✅ `PUT /api/mobile/leads/:id/accept` - Accept lead
18. ✅ `PUT /api/mobile/leads/:id/reject` - Reject lead

#### Lead Management - Extended (5) ⭐ **CRITICAL**
19. ⭐ `GET /api/mobile/leads/:id` - Get lead detail
20. ⭐ `PUT /api/mobile/leads/:id/status` - Update lead status
21. ⭐ `PUT /api/mobile/leads/:id/view` - Mark lead as viewed
22. ⭐ `POST /api/mobile/leads/:id/call` - Track phone call
23. ⭐ `POST /api/mobile/leads/:id/notes` - Add notes to lead

#### Notification Management (2)
24. `GET /api/mobile/notifications/settings` - Get notification preferences
25. `PUT /api/mobile/notifications/settings` - Update notification preferences

#### Device Management (3) ⭐ **CRITICAL**
26. ⭐ `POST /api/mobile/auth/register-device` - Register device for push
27. ⭐ `PUT /api/mobile/auth/update-device` - Update device token
28. ⭐ `DELETE /api/mobile/auth/unregister-device` - Unregister device

#### Password Reset (1)
29. `POST /api/mobile/auth/forgot-password` - Request password reset

---

## Implementation Priority

### Phase 1: Critical Endpoints (Must Implement First)
- Device management (3 endpoints) - Push notifications won't work
- Lead management extended (5 endpoints) - Core features broken

### Phase 2: Essential Endpoints
- Notification management (2 endpoints) - Settings incomplete
- Password reset (1 endpoint) - User experience

### Phase 3: Already Documented (18 endpoints)
- All basic functionality endpoints

---

## Quick SQL Reference

### Common Queries Used Across Endpoints

**Get Agency from JWT:**
```sql
SELECT * FROM agencies WHERE id = $1 AND is_active = TRUE;
```

**Verify Lead Assignment:**
```sql
SELECT * FROM lead_assignments 
WHERE lead_id = $1 AND agency_id = $2;
```

**Check Subscription Status:**
```sql
SELECT * FROM subscriptions 
WHERE agency_id = $1 AND status = 'active' 
ORDER BY created_at DESC LIMIT 1;
```

**Get Territory Count:**
```sql
SELECT COUNT(*) FROM agency_territories WHERE agency_id = $1;
```

---

## Response Format Standards

**Success Response:**
```json
{
  "success": true,
  "data": { ... },
  "message": "Operation successful"
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "Error message",
  "code": "ERROR_CODE"
}
```

---

**All detailed implementations in**: `BACKEND_API_DEVELOPMENT_GUIDE.md`

