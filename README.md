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

## ⚠️ Separate Deployment Note

For separate deployment, update `flutter-frontend/pubspec.yaml`:

**Change from:**
```yaml
flutter_backend:
  path: ../flutter-backend
```

**To Git dependency:**
```yaml
flutter_backend:
  git:
    url: https://github.com/your-org/flutter-backend.git
    ref: main
```

Or publish backend package and use:
```yaml
flutter_backend: ^1.0.0
```

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
