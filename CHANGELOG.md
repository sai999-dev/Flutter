# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-XX

### Added
- Flutter mobile app for Healthcare Leads marketplace
- Separate backend package (`flutter-backend`) for API services
- Frontend app (`flutter-frontend`) with complete UI
- Authentication service with JWT token management
- Subscription plans with zipcode-based pricing
- Lead management and filtering
- Document verification functionality
- Settings page with notification preferences
- Admin-managed zipcode territories (read-only in app)
- Secure storage for sensitive data
- API client with automatic token refresh

### Changed
- Project restructured for separate frontend/backend deployment
- Zipcode management moved to admin-only (removed user-facing add/remove)
- Subscription plans show zipcode counts instead of service areas
- Backend API returns correct zipcode counts based on plan price

### Fixed
- Fixed analyzer warnings and errors
- Fixed subscription plan zipcode count display (99$=3, 199$=7, 299$=10, 399$=15)
- Fixed Android cleartext traffic security issue
- Fixed syntax errors in Settings page dialog

### Security
- Disabled cleartext HTTP traffic for Android (production-ready)
- Added secure storage for JWT tokens
- Added ProGuard rules for Android release builds

## [Unreleased]

### Planned
- Unit tests and integration tests
- CI/CD pipeline setup
- Performance optimization
- Additional platform support improvements
- Enhanced error handling and retry logic


