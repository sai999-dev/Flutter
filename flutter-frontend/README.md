# Flutter Frontend App

Frontend mobile application - UI, screens, and widgets.

## Structure

```
lib/
├── main.dart              # App entry point
├── screens/              # All screen files
│   ├── auth/           # Authentication screens
│   ├── dashboard/      # Dashboard screens
│   ├── leads/          # Lead management
│   ├── subscriptions/  # Subscription screens
│   └── settings/       # Settings screens
├── widgets/            # Reusable UI components
└── theme/              # Theme configuration
```

## Backend Dependency

This app depends on `flutter_backend` package:
- Local path: `../flutter-backend`
- Or Git/Published package

## Deployment

- **Android**: `flutter build appbundle --release`
- **iOS**: `flutter build ios --release`
- **Web**: `flutter build web --release`

