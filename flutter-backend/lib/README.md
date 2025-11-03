# Backend Layer - Business Logic & Services

This directory contains all backend-related code for the Flutter mobile app:
- API services
- Business logic
- Data models
- Storage services
- Utilities

## Structure

```
backend/
├── services/          # API service layer
│   ├── api_client.dart              # HTTP client & JWT management
│   ├── auth_service.dart            # Authentication
│   ├── lead_service.dart            # Lead management
│   ├── subscription_service.dart    # Subscriptions
│   ├── territory_service.dart       # Territories
│   ├── notification_service.dart    # Push notifications
│   └── document_verification_service.dart
│
├── storage/           # Storage services
│   ├── secure_storage_service.dart  # Encrypted storage (JWT tokens)
│   └── cache_service.dart           # API response caching
│
├── utils/             # Backend utilities
│   └── zipcode_lookup_service.dart  # Zipcode utilities
│
└── models/            # Data models (to be implemented)
```

## Services

All services communicate with the backend API at `/api/mobile/*` endpoints.

### ApiClient
- Centralized HTTP client
- JWT token management
- Base URL discovery
- Error handling

### AuthService
- Agency registration
- Email verification
- Login/logout
- Token management

### LeadService
- Fetch leads
- Accept/reject leads
- Lead caching

### SubscriptionService
- View plans
- Subscribe/upgrade/downgrade
- Cancel subscriptions
- Payment management

### TerritoryService
- CRUD operations
- Offline caching

---

**Note**: Backend API is in separate repository (middleware layer)

