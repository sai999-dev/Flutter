# How to Run Flutter App

## 🚀 Quick Start Guide

Since the project is now split into `flutter-backend/` and `flutter-frontend/`, here's how to run it:

---

## Step 1: Setup Backend Package

The frontend app depends on the backend package, so set it up first:

```bash
cd flutter-backend
flutter pub get
```

**Expected output**: Packages will be installed and `.dart_tool/` folder will be created.

---

## Step 2: Setup Frontend App

Now set up the frontend app (it will link to the backend package):

```bash
cd ../flutter-frontend
flutter pub get
```

**Expected output**: 
- Packages will be installed
- Backend package will be linked from `../flutter-backend`
- `.dart_tool/` folder will be created

---

## Step 3: Run the App

### Option A: Run on Connected Device/Emulator

```bash
# Make sure you're in flutter-frontend folder
cd flutter-frontend

# List available devices
flutter devices

# Run on default device
flutter run

# Or specify a device
flutter run -d <device-id>
```

### Option B: Run on Specific Platform

**Android:**
```bash
cd flutter-frontend
flutter run -d android
```

**iOS:**
```bash
cd flutter-frontend
flutter run -d ios
```

**Web:**
```bash
cd flutter-frontend
flutter run -d web
```

**Windows:**
```bash
cd flutter-frontend
flutter run -d windows
```

---

## 📱 Full Commands

### Complete Setup (First Time)

```bash
# 1. Setup backend package
cd flutter-backend
flutter pub get
cd ..

# 2. Setup frontend app
cd flutter-frontend
flutter pub get

# 3. Run app
flutter run
```

### Quick Run (After First Setup)

```bash
cd flutter-frontend
flutter run
```

---

## 🔧 Troubleshooting

### Error: "Package flutter_backend not found"

**Solution**: Make sure backend package is set up first:
```bash
cd flutter-backend
flutter pub get
cd ../flutter-frontend
flutter pub get
```

### Error: "Cannot find module"

**Solution**: Clean and rebuild:
```bash
cd flutter-frontend
flutter clean
flutter pub get
flutter run
```

### Error: "No devices found"

**Solution**: 
- For Android: Start an Android emulator or connect a device
- For iOS: Start an iOS simulator or connect a device
- For Web: Use `flutter run -d web` (no device needed)

---

## 🎯 Platform-Specific Requirements

### Android
- Android Studio installed
- Android SDK configured
- Emulator running or device connected via USB

### iOS (macOS only)
- Xcode installed
- iOS Simulator or device connected

### Web
- Chrome browser (for testing)

### Windows/Linux/macOS Desktop
- Flutter desktop support enabled

---

## ✅ Verify Setup

Check if everything is ready:

```bash
# Check Flutter installation
flutter doctor

# Check devices
flutter devices

# Verify backend package
cd flutter-backend
flutter pub get

# Verify frontend app
cd ../flutter-frontend
flutter pub get
```

---

## 📝 Quick Reference

| Task | Command |
|------|---------|
| Setup backend | `cd flutter-backend && flutter pub get` |
| Setup frontend | `cd flutter-frontend && flutter pub get` |
| Run app | `cd flutter-frontend && flutter run` |
| List devices | `flutter devices` |
| Run on Android | `flutter run -d android` |
| Run on iOS | `flutter run -d ios` |
| Run on Web | `flutter run -d web` |
| Clean build | `flutter clean && flutter pub get` |

---

## 🚀 Happy Coding!

Your Flutter app is now ready to run! The backend package will be automatically used by the frontend app.

