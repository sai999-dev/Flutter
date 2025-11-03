# How to Run Flutter App

## 📁 Which Folder to Run?

### ✅ Run from: `flutter-frontend/`

**This is the Flutter app** - contains all the UI, screens, and platform builds.

```bash
cd flutter-frontend
flutter run
```

### ❌ Don't run from: `flutter-backend/`

**This is just a package** - it's a library that the frontend uses. You don't run it directly.

---

## 🚀 Quick Start

### 1. Navigate to Frontend Folder
```bash
cd flutter-frontend
```

### 2. Run the App
```bash
flutter run
```

### 3. Or Specify a Device
```bash
flutter run -d windows    # Windows desktop
flutter run -d chrome     # Web browser
flutter run -d android    # Android
```

---

## 📦 Folder Structure Explained

```
Flutter/
├── flutter-backend/     # ❌ DON'T RUN HERE
│   └── lib/            # This is just a package/library
│
└── flutter-frontend/   # ✅ RUN HERE
    ├── lib/            # This is the Flutter app
    ├── android/        # Platform builds
    ├── ios/            # Platform builds
    ├── web/            # Platform builds
    └── pubspec.yaml    # App configuration
```

---

## 🎯 Why flutter-frontend?

- ✅ Contains `main.dart` - the app entry point
- ✅ Has platform folders (android, ios, web, etc.)
- ✅ Has all UI code (screens, widgets)
- ✅ Can build and run as an app

**flutter-backend** is just a dependency package that provides services to the frontend.

---

## 📝 Summary

| Folder | Purpose | Run Flutter? |
|--------|---------|--------------|
| `flutter-backend/` | Package/library | ❌ No |
| `flutter-frontend/` | Flutter app | ✅ **YES** |

---

## 🚀 Command

```bash
cd flutter-frontend && flutter run
```

