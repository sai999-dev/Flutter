# Mobile App (Flutter) - Separate Deployment Guide

## Overview

Deploy the **Flutter Mobile App** separately from the backend API.

**Mobile App Location**: This repository (`Flutter`)

---

## Pre-Deployment Checklist

- [ ] Backend API deployed and accessible
- [ ] Update `api_client.dart` with production backend URL
- [ ] Remove localhost URLs from code
- [ ] Test app with production backend
- [ ] Build release versions
- [ ] Configure app signing

---

## Step 1: Configure Production Backend URL

### Update API Client

**File**: `lib/backend/services/api_client.dart`

```dart
class ApiClient {
  // Production Backend API URL
  static const List<String> baseUrls = [
    'https://your-backend-api.onrender.com',  // Your deployed backend
    // REMOVE localhost URLs for production:
    // 'http://127.0.0.1:3002',  // ❌ Remove this
    // 'http://localhost:3002',   // ❌ Remove this
  ];
  
  // ... rest of code stays the same
}
```

**Important**: Replace `your-backend-api.onrender.com` with your actual deployed backend URL.

---

## Step 2: Test with Production Backend

### Test Locally First

```bash
# 1. Update api_client.dart with production URL
# 2. Run app
flutter run

# 3. Test:
# - Login
# - Fetch leads
# - Check subscription plans
# - Verify all API calls work
```

---

## Step 3: Choose Deployment Method

### Option A: Mobile Apps (iOS/Android) - Recommended

Deploy native mobile apps to App Store and Play Store.

---

## Android Deployment

### 3.1 Configure Android App

**File**: `android/app/build.gradle`

```gradle
android {
    defaultConfig {
        applicationId "com.starboyanalytica.app"
        minSdk 21
        targetSdk 34
        versionCode 1  // Increment for each release
        versionName "1.0.0"  // Update for each release
    }
    
    buildTypes {
        release {
            // ⚠️ IMPORTANT: Create production signing config
            signingConfig signingConfigs.release  // Not debug!
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

### 3.2 Create Production Signing Key

```bash
cd android/app

# Generate keystore
keytool -genkey -v -keystore release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias release

# Follow prompts to set password and details
```

### 3.3 Configure Signing

**File**: `android/key.properties`
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=release
storeFile=../app/release-key.jks
```

**File**: `android/app/build.gradle`
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
}
```

### 3.4 Build Release APK

```bash
# Build APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### 3.5 Build App Bundle (For Play Store)

```bash
# Build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### 3.6 Upload to Google Play Store

1. **Create App in Play Console**
   - Go to https://play.google.com/console
   - Create new app
   - Fill app details

2. **Upload App Bundle**
   - Production → Create new release
   - Upload `app-release.aab`
   - Add release notes
   - Review and publish

3. **Complete Store Listing**
   - App details
   - Screenshots
   - Graphics
   - Privacy policy

---

## iOS Deployment

### 4.1 Configure iOS App

**File**: `ios/Runner.xcodeproj`

- Set Bundle Identifier (unique)
- Set Version and Build Number
- Configure Signing & Capabilities

### 4.2 Build iOS App

```bash
# Build iOS app
flutter build ios --release

# This creates build/ios/ folder
```

### 4.3 Archive in Xcode

1. **Open Project**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Select Device**
   - Product → Destination → Any iOS Device

3. **Archive**
   - Product → Archive
   - Wait for archive to complete

4. **Distribute**
   - Window → Organizer
   - Select archive
   - Distribute App
   - App Store Connect
   - Follow prompts

### 4.4 Submit to App Store

1. **App Store Connect**
   - Go to https://appstoreconnect.apple.com
   - My Apps → Your App

2. **Upload Build**
   - TestFlight or App Store
   - Upload build from Xcode

3. **Submit for Review**
   - Complete app information
   - Submit for review

---

## Option B: Web App Deployment (Optional)

Deploy Flutter as web application.

### 5.1 Build Web App

```bash
# Build for web
flutter build web --release

# Output: build/web/
```

### 5.2 Deploy to Firebase Hosting

```bash
# 1. Install Firebase CLI
npm install -g firebase-tools

# 2. Login
firebase login

# 3. Initialize (in Flutter project root)
firebase init hosting
# - Public directory: build/web
# - Single-page app: Yes
# - GitHub deployment: Optional

# 4. Build and Deploy
flutter build web --release
firebase deploy

# Your app: https://your-project.web.app
```

### 5.3 Deploy to Vercel

```bash
# 1. Install Vercel CLI
npm install -g vercel

# 2. Build
flutter build web --release

# 3. Deploy
cd build/web
vercel --prod

# Your app: https://your-app.vercel.app
```

### 5.4 Deploy to Netlify

```bash
# 1. Install Netlify CLI
npm install -g netlify-cli

# 2. Build
flutter build web --release

# 3. Deploy
netlify deploy --prod --dir=build/web

# Your app: https://your-app.netlify.app
```

### 5.5 Update Backend CORS

After deploying web app, update backend CORS:

**Backend**: `super-admin-backend/server.js` or `config.env`

```env
FRONTEND_URL=https://your-web-app.firebaseapp.com
ALLOWED_ORIGINS=https://your-web-app.firebaseapp.com,https://your-web-app.vercel.app
```

---

## Deployment Summary

### Mobile App Deployment

| Platform | Command | Output |
|----------|---------|--------|
| **Android APK** | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| **Android Bundle** | `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` |
| **iOS** | `flutter build ios --release` | Archive in Xcode |
| **Web** | `flutter build web --release` | `build/web/` |

### Web App Deployment

| Platform | Command | Result |
|----------|---------|--------|
| **Firebase** | `firebase deploy` | `https://your-app.web.app` |
| **Vercel** | `vercel --prod` | `https://your-app.vercel.app` |
| **Netlify** | `netlify deploy --prod` | `https://your-app.netlify.app` |

---

## Post-Deployment Checklist

### Mobile App ✅
- [ ] App published to App Store / Play Store
- [ ] Test on physical devices
- [ ] Verify connection to production backend
- [ ] Test all features
- [ ] Monitor crash reports
- [ ] Collect user feedback

### Web App ✅
- [ ] Web app deployed
- [ ] Test in multiple browsers
- [ ] Verify backend connection
- [ ] Test all features
- [ ] Configure custom domain (optional)

---

## Configuration Files

### Mobile App Config

**`lib/backend/services/api_client.dart`**
```dart
static const List<String> baseUrls = [
  'https://your-production-backend-url.com',  // Production
];
```

### Web App - Update Backend CORS

**Backend `config.env`**
```env
FRONTEND_URL=https://your-web-app.firebaseapp.com
ALLOWED_ORIGINS=https://your-web-app.firebaseapp.com
```

---

## Troubleshooting

### Mobile App Can't Connect to Backend
- ✅ Verify backend URL in `api_client.dart`
- ✅ Check backend is running and accessible
- ✅ Test backend URL in browser: `https://your-backend.com/api/health`

### Web App - CORS Errors
- ✅ Add web app URL to backend `ALLOWED_ORIGINS`
- ✅ Verify CORS configuration in backend

### Build Errors
- ✅ Check Flutter SDK version: `flutter --version`
- ✅ Update dependencies: `flutter pub get`
- ✅ Clean build: `flutter clean && flutter pub get`

---

## Quick Deploy Commands

```bash
# Android
flutter build appbundle --release
# Upload app-release.aab to Play Store

# iOS
flutter build ios --release
# Archive in Xcode → Submit to App Store

# Web
flutter build web --release
firebase deploy  # or vercel/netlify
```

---

**Status**: ✅ **MOBILE APP DEPLOYMENT READY**

Deploy separately from backend - they're independent!

