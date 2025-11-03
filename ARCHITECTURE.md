# Mobile App Architecture - Production Grade

## Overview

This is the **Flutter Mobile App** repository for the Lead Marketplace platform. It is a **separate repository** from the backend API middleware layer and super admin portal.

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│     PostgreSQL Database                          │
│     (Single Source of Truth)                     │
│     - agencies                                   │
│     - subscriptions                             │
│     - agency_territories                        │
│     - leads                                     │
│     - lead_assignments                          │
│     - users (admin)                             │
│     - transactions                              │
│     - notifications                             │
│     - webhook_audit                             │
│     - agency_devices                            │
└──────────────────┬──────────────────────────────┘
                   │
                   │ SQL Queries ONLY
                   │
┌──────────────────▼──────────────────────────────┐
│     BACKEND API (Middleware Layer)               │
│     [SEPARATE REPOSITORY]                        │
│                                                    │
│     Exposes REST APIs:                           │
│     - /api/mobile/* → Mobile App                 │
│     - /api/admin/* → Super Admin Portal          │
│     - /api/webhook/* → Public Portals           │
└──────────────────┬──────────────────────────────┘
                   │
       ┌───────────┴───────────┐
       │                       │
┌──────▼──────┐      ┌─────────▼──────────┐
│  MOBILE APP │      │ SUPER ADMIN PORTAL│
│  (Flutter)  │      │  (React/Vue)      │
│             │      │  [SEPARATE REPO]  │
│ iOS/Android │      │                   │
│             │      │                   │
│ THIS REPO   │      │  SEPARATE REPO   │
└─────────────┘      └──────────────────┘
```

## Repository Structure

### This Repository (Mobile App)

**Purpose**: Agency self-service mobile application (iOS/Android)

**Technology**: Flutter (Dart)

**Contents**:
- Mobile app UI and business logic
- Service layer for API communication
- Authentication (JWT-based)
- Local caching and offline support
- Push notification handling

**Does NOT contain**:
- ❌ Backend API code (separate repository)
- ❌ Super Admin Portal code (separate repository)
- ❌ Database schemas or migrations
- ❌ Server-side business logic

### Separate Repositories

1. **Backend API Repository** (Middleware Layer)
   - Database access (PostgreSQL)
   - Business logic
   - REST API endpoints (`/api/mobile/*`, `/api/admin/*`, `/api/webhook/*`)
   - Authentication server
   - Webhook processing

2. **Super Admin Portal Repository**
   - Admin dashboard (React/Vue)
   - Admin-specific API endpoints (`/api/admin/*`)
   - Agency management interface

## Mobile App API Endpoints

The mobile app consumes **18 endpoints** from the backend API:

### 1. Registration & Onboarding (3)
- `POST /api/mobile/auth/register`
- `POST /api/mobile/auth/verify-email`
- `POST /api/mobile/auth/login`

### 2. Subscription Management - Self-Service (8)
- `GET /api/mobile/subscription/plans`
- `POST /api/mobile/subscription/subscribe`
- `GET /api/mobile/subscription`
- `PUT /api/mobile/subscription/upgrade`
- `PUT /api/mobile/subscription/downgrade`
- `POST /api/mobile/subscription/cancel`
- `GET /api/mobile/subscription/invoices`
- `PUT /api/mobile/payment-method`

### 3. Territory Setup (4)
- `GET /api/mobile/territories`
- `POST /api/mobile/territories`
- `PUT /api/mobile/territories/:id`
- `DELETE /api/mobile/territories/:id`

### 4. Lead Management (3)
- `GET /api/mobile/leads`
- `PUT /api/mobile/leads/:id/accept`
- `PUT /api/mobile/leads/:id/reject`

See `MOBILE_API_ENDPOINTS.md` for detailed documentation.

## Project Structure

```
lib/
├── core/
│   ├── services/
│   │   ├── api_client.dart          # HTTP client with JWT management
│   │   ├── auth_service.dart        # Authentication endpoints
│   │   ├── subscription_service.dart # Subscription self-service
│   │   ├── territory_service.dart    # Territory management
│   │   ├── lead_service.dart        # Lead management
│   │   ├── notification_service.dart # Push notifications
│   │   ├── cache_service.dart        # Local caching
│   │   └── zipcode_lookup_service.dart
│   └── models/                       # Data models
├── features/
│   ├── auth/                         # Login, registration screens
│   ├── dashboard/                    # Agency dashboard
│   ├── leads/                        # Lead management screens
│   ├── subscriptions/                # Subscription screens
│   └── territories/                  # Territory management screens
├── widgets/                          # Reusable UI components
└── main.dart                         # App entry point
```

## Key Services

### ApiClient
- Centralized HTTP client
- JWT token management
- Automatic token attachment to requests
- Base URL discovery and caching
- Error handling and timeout management

### AuthService
- Agency registration
- Email verification
- Login/logout
- Device registration for push notifications

### SubscriptionService
- View available plans
- Subscribe/upgrade/downgrade/cancel
- View invoices
- Update payment methods

### TerritoryService
- CRUD operations for territories
- Local caching for offline access

### LeadService
- Fetch assigned leads
- Accept/reject leads
- Lead caching for performance

## Authentication Flow

1. **Registration**: Agency registers → receives verification code
2. **Email Verification**: Verify email with code → receives JWT token
3. **Login**: Authenticate with credentials → receives JWT token
4. **Token Storage**: JWT stored securely in `SharedPreferences`
5. **Authenticated Requests**: Token automatically attached to requests
6. **Logout**: Token cleared, device unregistered

## Security

- **JWT Tokens**: Stored securely using `SharedPreferences`
- **HTTPS**: All API communication over HTTPS (production)
- **Token Management**: Automatic token attachment, refresh handling
- **Secure Storage**: Sensitive data stored using `flutter_secure_storage`

## Caching Strategy

- **Leads**: Cached for 2 minutes (frequently changing)
- **Territories**: Cached locally for offline access
- **Plans**: Cached for session duration
- **Cache Invalidation**: Automatic on mutations (accept/reject leads, add/remove territories)

## Error Handling

- Network errors handled gracefully
- User-friendly error messages
- Automatic fallback to cached data when available
- Retry logic for transient failures
- Comprehensive logging for debugging

## Development Setup

1. **Prerequisites**:
   ```bash
   flutter --version  # Ensure Flutter SDK is installed
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Backend URL**:
   - Update `baseUrls` in `lib/core/services/api_client.dart`
   - For production, set production API URL

4. **Run the App**:
   ```bash
   flutter run
   ```

## Production Deployment

### Build Commands

**iOS**:
```bash
flutter build ios --release
```

**Android**:
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### Environment Configuration

Create environment-specific configuration:
- Development: Local backend URL
- Staging: Staging backend URL
- Production: Production backend URL

### CI/CD Pipeline

Recommended steps:
1. Run tests: `flutter test`
2. Analyze code: `flutter analyze`
3. Build release: `flutter build <platform> --release`
4. Deploy to App Store/Play Store

## Testing

- Unit tests for services
- Widget tests for UI components
- Integration tests for API communication
- Mock API responses for offline testing

## Monitoring & Analytics

Recommended integrations:
- **Crash Reporting**: Firebase Crashlytics, Sentry
- **Analytics**: Firebase Analytics, Mixpanel
- **Performance**: Firebase Performance Monitoring
- **Push Notifications**: OneSignal, Firebase Cloud Messaging

## Dependencies

Key packages:
- `http`: API communication
- `shared_preferences`: Local storage
- `flutter_secure_storage`: Secure token storage
- `go_router`: Navigation
- `provider`: State management
- `flutter_local_notifications`: Local notifications
- `onesignal_flutter`: Push notifications

See `pubspec.yaml` for complete list.

## Backend API Requirements

The backend API (separate repository) must implement:

1. **All 18 mobile endpoints** as documented
2. **JWT authentication** with token validation
3. **CORS** configuration for mobile apps
4. **Rate limiting** to prevent abuse
5. **Error handling** with proper HTTP status codes
6. **Webhook processing** for lead assignments
7. **Push notification service** integration

## Notes

- Mobile app is **stateless** - all data comes from backend API
- No direct database access from mobile app
- Backend API is the **single source of truth**
- Mobile app handles offline caching for better UX
- Super Admin Portal uses separate endpoints (`/api/admin/*`)

---

**Last Updated**: Based on architecture requirements  
**Mobile App Repository**: This repository  
**Backend API**: Separate repository  
**Super Admin Portal**: Separate repository

