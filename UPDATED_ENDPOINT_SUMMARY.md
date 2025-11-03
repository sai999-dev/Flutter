# Updated API Endpoint Summary

## Total Endpoints: 28 (Not 18)

After comprehensive analysis of the mobile app codebase, the app requires **28 API endpoints** for full functionality, not the originally documented 18.

---

## Endpoint Breakdown

### ✅ Core 18 Endpoints (Originally Documented)

**Registration & Onboarding (3)**
1. `POST /api/mobile/auth/register`
2. `POST /api/mobile/auth/verify-email`
3. `POST /api/mobile/auth/login`

**Subscription Management (8)**
4. `GET /api/mobile/subscription/plans`
5. `POST /api/mobile/subscription/subscribe`
6. `GET /api/mobile/subscription`
7. `PUT /api/mobile/subscription/upgrade`
8. `PUT /api/mobile/subscription/downgrade`
9. `POST /api/mobile/subscription/cancel`
10. `GET /api/mobile/subscription/invoices`
11. `PUT /api/mobile/payment-method`

**Territory Management (4)**
12. `GET /api/mobile/territories`
13. `POST /api/mobile/territories`
14. `PUT /api/mobile/territories/:id`
15. `DELETE /api/mobile/territories/:id`

**Lead Management - Basic (3)**
16. `GET /api/mobile/leads`
17. `PUT /api/mobile/leads/:id/accept`
18. `PUT /api/mobile/leads/:id/reject`

---

### ❌ Missing 10 Endpoints (Now Documented)

**Lead Management - Extended (5)**
19. `GET /api/mobile/leads/:id` - Get lead detail ⭐ **CRITICAL**
20. `PUT /api/mobile/leads/:id/status` - Update lead status ⭐ **CRITICAL**
21. `PUT /api/mobile/leads/:id/view` - Mark as viewed
22. `POST /api/mobile/leads/:id/call` - Track phone call ⭐ **HIGH**
23. `POST /api/mobile/leads/:id/notes` - Add notes ⭐ **CRITICAL**

**Notification Management (2)**
24. `GET /api/mobile/notifications/settings` - Get preferences
25. `PUT /api/mobile/notifications/settings` - Update preferences

**Device Management (3)**
26. `POST /api/mobile/auth/register-device` - Register for push ⭐ **CRITICAL**
27. `PUT /api/mobile/auth/update-device` - Update device token ⭐ **CRITICAL**
28. `DELETE /api/mobile/auth/unregister-device` - Unregister device

**Password Reset (1)**
29. `POST /api/mobile/auth/forgot-password` - Password reset (path fixed)

---

## Critical Missing Endpoints

### ⚠️ **HIGH PRIORITY** - Core Features Won't Work

1. **`GET /api/mobile/leads/:id`** - Lead detail viewing
   - **Impact**: Users can't see complete lead information
   - **Used In**: Lead detail screens, modals

2. **`PUT /api/mobile/leads/:id/status`** - Status workflow
   - **Impact**: Status management broken (new → contacted → qualified → converted)
   - **Used In**: Lead status updates throughout app

3. **`POST /api/mobile/leads/:id/notes`** - Notes feature
   - **Impact**: Can't add notes to leads (listed in README as core feature)
   - **Used In**: Lead management, interaction tracking

4. **`POST /api/mobile/auth/register-device`** - Push notifications
   - **Impact**: Push notifications won't work
   - **Used In**: Automatic on login/app start

5. **`PUT /api/mobile/auth/update-device`** - Device token updates
   - **Impact**: Push notifications will stop working after token refresh
   - **Used In**: FCM token refresh cycle

---

## Files Updated

1. ✅ `MOBILE_API_ENDPOINTS.md` - Added 10 missing endpoints
2. ✅ `lib/core/services/auth_service.dart` - Fixed forgot-password endpoint path
3. ✅ `ENDPOINT_ANALYSIS_REPORT.md` - Comprehensive analysis report

---

## Backend Requirements

The backend API must implement **all 28 endpoints** for the mobile app to function fully. The missing endpoints are:

### Lead Management Extensions
- `GET /api/mobile/leads/:id`
- `PUT /api/mobile/leads/:id/status`
- `PUT /api/mobile/leads/:id/view`
- `POST /api/mobile/leads/:id/call`
- `POST /api/mobile/leads/:id/notes`

### Notification Management
- `GET /api/mobile/notifications/settings`
- `PUT /api/mobile/notifications/settings`

### Device Management
- `POST /api/mobile/auth/register-device`
- `PUT /api/mobile/auth/update-device`
- `DELETE /api/mobile/auth/unregister-device`

### Password Reset
- `POST /api/mobile/auth/forgot-password`

---

## Status Summary

| Category | Required | Documented | Missing |
|----------|----------|------------|---------|
| Authentication | 5 | 3 | 2 (device mgmt + forgot password) |
| Subscription | 8 | 8 | 0 ✅ |
| Territory | 4 | 4 | 0 ✅ |
| Lead Management | 8 | 3 | 5 ❌ |
| Notifications | 2 | 0 | 2 ❌ |
| Device Management | 3 | 0 | 3 ❌ |
| **TOTAL** | **30** | **18** | **12** |

*Note: Password reset counted separately, device management counted under auth*

---

**Next Steps**: 
1. Backend team must implement the 10 missing endpoints
2. Test all 28 endpoints for full functionality
3. Update backend API documentation

