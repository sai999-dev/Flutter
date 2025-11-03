# Flutter Mobile App - Separate Backend & Frontend Deployment Guide

## Overview

This guide shows how to deploy the **Flutter Mobile App** and **Backend API** as separate services.

---

## Architecture

```
┌─────────────────────────────────────────┐
│   Mobile App (Flutter)                   │
│   - iOS/Android Native App              │
│   - OR Web App (optional)                │
│   Deployment: App Store / Play Store    │
│   OR: Web Hosting (Firebase, Vercel)     │
└──────────────┬──────────────────────────┘
               │
               │ HTTPS API Calls
               │
┌──────────────▼──────────────────────────┐
│   Backend API Server                     │
│   - Node.js/Express                      │
│   - Deployment: Render, Heroku, AWS     │
│   - Endpoints: /api/mobile/*            │
└─────────────────────────────────────────┘
```

---

## Part 1: Backend API Deployment

The backend API is in **separate repository** (`super-admin-backend`).

### Step 1: Prepare Backend for Production

1. **Set Environment Variables**
   ```env
   NODE_ENV=production
   PORT=3000
   SUPABASE_URL=your_production_supabase_url
   SUPABASE_SERVICE_ROLE_KEY=your_production_key
   JWT_SECRET=your_strong_random_secret_min_32_chars
   FRONTEND_URL=https://your-mobile-app-domain.com
   ```

2. **Test Locally**
   ```bash
   cd super-admin-backend
   npm install
   npm start
   # Test: http://localhost:3000/api/health
   ```

### Step 2: Deploy Backend API

#### Option A: Render.com (Recommended)
```bash
# 1. Push to GitHub
git add .
git commit -m "Prepare for production"
git push origin main

# 2. Create Render Service
# - Go to render.com
# - New → Web Service
# - Connect GitHub repo (super-admin-backend)
# - Settings:
#   - Build Command: npm install
#   - Start Command: npm start
#   - Environment Variables: Add all from config.env

# 3. Deploy
# - Render will auto-deploy on push
# - Get your API URL: https://your-app.onrender.com
```

#### Option B: Heroku
```bash
# 1. Install Heroku CLI
# 2. Login
heroku login

# 3. Create app
heroku create your-backend-app

# 4. Set environment variables
heroku config:set NODE_ENV=production
heroku config:set SUPABASE_URL=your_url
heroku config:set JWT_SECRET=your_secret
# ... add all vars

# 5. Deploy
git push heroku main
```

#### Option C: AWS/Google Cloud/Azure
- Follow platform-specific Node.js deployment guides
- Use services like:
  - AWS Elastic Beanstalk
  - Google Cloud Run
  - Azure App Service

### Step 3: Verify Backend Deployment

```bash
# Test health endpoint
curl https://your-backend-url.com/api/health

# Test mobile endpoint
curl https://your-backend-url.com/api/mobile/subscription/plans
```

**Backend URL**: Save this for mobile app configuration
```
https://your-backend-api.onrender.com
```

---

## Part 2: Flutter Mobile App Deployment

### Option A: Mobile App (iOS/Android) - Recommended

#### Android Deployment

1. **Configure Production API URL**
   ```dart
   // lib/backend/services/api_client.dart
   static const List<String> baseUrls = [
     'https://your-backend-api.onrender.com',  // Production URL
     // Remove localhost URLs for production
   ];
   ```

2. **Build Release APK**
   ```bash
   flutter build apk --release
   # Output: build/app/outputs/flutter-apk/app-release.apk
   ```

3. **Or Build App Bundle (for Play Store)**
   ```bash
   flutter build appbundle --release
   # Output: build/app/outputs/bundle/release/app-release.aab
   ```

4. **Upload to Google Play Store**
   - Go to Google Play Console
   - Create new app
   - Upload `.aab` file
   - Complete store listing
   - Submit for review

#### iOS Deployment

1. **Configure Production API URL** (same as Android)

2. **Build iOS App**
   ```bash
   flutter build ios --release
   ```

3. **Archive in Xcode**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Product → Archive
   - Distribute App → App Store Connect

4. **Submit to App Store**
   - Use App Store Connect
   - Upload and submit for review

---

### Option B: Web App Deployment (Optional)

Deploy Flutter as web app (separate from mobile):

1. **Configure Production API**
   ```dart
   // lib/backend/services/api_client.dart
   static const List<String> baseUrls = [
     'https://your-backend-api.onrender.com',  // Production
   ];
   ```

2. **Build Web App**
   ```bash
   flutter build web --release
   # Output: build/web/
   ```

3. **Deploy Web App**

   **Option 1: Firebase Hosting**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools
   
   # Initialize
   firebase init hosting
   # - Public directory: build/web
   # - Single-page app: Yes
   
   # Deploy
   flutter build web --release
   firebase deploy
   ```

   **Option 2: Vercel**
   ```bash
   # Install Vercel CLI
   npm install -g vercel
   
   # Build
   flutter build web --release
   
   # Deploy
   cd build/web
   vercel --prod
   ```

   **Option 3: Netlify**
   ```bash
   # Install Netlify CLI
   npm install -g netlify-cli
   
   # Build
   flutter build web --release
   
   # Deploy
   netlify deploy --prod --dir=build/web
   ```

---

## Configuration for Separate Deployment

### Backend Configuration

**File**: `super-admin-backend/config.env`
```env
# Production Settings
NODE_ENV=production
PORT=3000

# Database
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_key

# Security
JWT_SECRET=your-strong-secret-32-chars-minimum

# CORS - Allow your Flutter app domains
FRONTEND_URL=https://your-app.firebaseapp.com
ALLOWED_ORIGINS=https://your-app.firebaseapp.com,https://your-app.vercel.app
```

### Mobile App Configuration

**File**: `lib/backend/services/api_client.dart`
```dart
class ApiClient {
  // Production API URL
  static const List<String> baseUrls = [
    'https://your-backend-api.onrender.com',  // Production backend
    // Remove localhost URLs in production
  ];
  
  // ... rest of code
}
```

**For Web App**: Also configure CORS on backend to allow web domain.

---

## Deployment Checklist

### Backend Deployment ✅
- [ ] Set all production environment variables
- [ ] Set strong JWT_SECRET (32+ characters)
- [ ] Configure CORS for mobile/web app domains
- [ ] Test backend API endpoints
- [ ] Deploy to hosting platform
- [ ] Verify `/api/health` endpoint
- [ ] Test `/api/mobile/*` endpoints
- [ ] Monitor logs and errors

### Mobile App Deployment ✅
- [ ] Update `api_client.dart` with production backend URL
- [ ] Remove localhost URLs from `baseUrls`
- [ ] Build release version
- [ ] Test on physical device
- [ ] Upload to App Store / Play Store
- [ ] Configure app signing (Android)
- [ ] Configure app signing (iOS)

### Web App Deployment (Optional) ✅
- [ ] Update API URL in code
- [ ] Build web version
- [ ] Deploy to hosting (Firebase/Vercel/Netlify)
- [ ] Configure CORS on backend
- [ ] Test web app functionality

---

## Separate Deployment Architecture

```
┌─────────────────────────────────────────┐
│   DEPLOYMENT #1: Backend API            │
│   - Host: Render/Heroku/AWS             │
│   - URL: https://api.yourdomain.com     │
│   - Port: 3000 (or configured)          │
│   - Endpoints: /api/mobile/*            │
└──────────────┬──────────────────────────┘
               │
               │ HTTPS (Production)
               │
┌──────────────▼──────────────────────────┐
│   DEPLOYMENT #2: Mobile App              │
│   - iOS: App Store                       │
│   - Android: Play Store                  │
│   - OR Web: Firebase/Vercel              │
│   - Connects to: Backend API URL         │
└─────────────────────────────────────────┘
```

---

## Environment-Specific URLs

### Development
- Backend: `http://localhost:3000`
- Mobile App: Local development

### Production
- Backend: `https://your-backend-api.onrender.com`
- Mobile App: Published to stores
- Web App: `https://your-app.firebaseapp.com`

---

## Testing After Deployment

### 1. Test Backend
```bash
# Health check
curl https://your-backend.onrender.com/api/health

# Mobile endpoint
curl https://your-backend.onrender.com/api/mobile/subscription/plans
```

### 2. Test Mobile App
- Install on physical device
- Test login
- Test API calls
- Verify connection to production backend

### 3. Test Web App (if deployed)
- Open web app URL
- Test all features
- Check browser console for errors

---

## Troubleshooting

### Backend Issues
- **CORS errors**: Add mobile/web app domain to `ALLOWED_ORIGINS`
- **Database connection**: Verify Supabase credentials
- **Authentication fails**: Check JWT_SECRET is set

### Mobile App Issues
- **API connection fails**: Verify backend URL in `api_client.dart`
- **Build errors**: Check Flutter SDK version
- **Signing errors**: Configure app signing properly

---

## Quick Deployment Commands

### Backend
```bash
cd super-admin-backend
# Set environment variables
# Push to GitHub
git push origin main
# Deploy via Render/Heroku (auto-deploy on push)
```

### Mobile App
```bash
cd Flutter

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

**Status**: ✅ **SEPARATE DEPLOYMENT READY**

Both backend and frontend can now be deployed independently!

