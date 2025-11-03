# Healthcare Leads Mobile App

Flutter mobile app split into separate backend package and frontend app.

## 🚀 Quick Start

```bash
# Setup backend package
cd flutter-backend
flutter pub get

# Setup and run frontend app
cd ../flutter-frontend
flutter pub get
flutter run
```

## 📁 Structure

```
Flutter/
├── flutter-backend/      # Backend package (services, API client)
└── flutter-frontend/     # Frontend app (UI, screens, widgets)
```

## ⚠️ Separate Deployment Configuration

### 1. Update Dependency Path

In `flutter-frontend/pubspec.yaml`, change from local path to Git dependency:

```yaml
# Comment out local path:
# flutter_backend:
#   path: ../flutter-backend

# Uncomment and update Git dependency:
flutter_backend:
  git:
    url: https://github.com/your-org/flutter-backend.git
    ref: main
```

### 2. Set Production API URL

In `flutter-backend/lib/services/api_client.dart`, set production URL:

```dart
static const String? productionApiUrl = 'https://your-production-api.com';
```

For development, leave it as `null` to use localhost URLs.

## 🏗️ Build

**Android:**
```bash
cd flutter-frontend
flutter build appbundle --release
```

**iOS:**
```bash
cd flutter-frontend
flutter build ios --release
```

**Web:**
```bash
cd flutter-frontend
flutter build web --release
```
