# 🚀 Deployment Checklist

## ✅ Pre-Deployment Checks

### Flutter Frontend

#### 1. Production API URL
- [ ] Update `flutter-backend/lib/services/api_client.dart`
  ```dart
  static const String? productionApiUrl = 'https://your-production-api.com';
  ```

#### 2. Android Release Configuration
- [ ] Create release keystore
- [ ] Update `android/app/build.gradle` with production signing config
- [ ] Remove `usesCleartextTraffic="true"` from AndroidManifest (✅ Done)
- [ ] Test release build: `flutter build appbundle --release`

#### 3. iOS Release Configuration
- [ ] Configure App Store signing in Xcode
- [ ] Update bundle identifier
- [ ] Test release build: `flutter build ios --release`

#### 4. Code Cleanup
- [ ] Remove debug print statements
- [ ] Remove unused code (✅ Fixed analyzer warnings)
- [ ] Remove test/dummy data

#### 5. Dependencies
- [ ] For separate deployment, update `pubspec.yaml` to use Git dependency:
  ```yaml
  flutter_backend:
    git:
      url: https://github.com/your-org/flutter-backend.git
      ref: main
  ```

### Backend Server (super-admin-backend)

#### 1. Environment Variables
- [ ] Set `NODE_ENV=production`
- [ ] Configure production database URL
- [ ] Set JWT secret key
- [ ] Configure CORS for production domain
- [ ] Set up SSL/HTTPS

#### 2. Database
- [ ] Verify all migrations applied
- [ ] Backup production database
- [ ] Verify RLS (Row-Level Security) enabled
- [ ] Test database connections

#### 3. Security
- [ ] Enable HTTPS
- [ ] Configure rate limiting
- [ ] Review CORS settings
- [ ] Check authentication middleware
- [ ] Verify API key management

#### 4. Monitoring
- [ ] Set up error logging (Sentry, etc.)
- [ ] Configure health check endpoints
- [ ] Set up uptime monitoring

## 🔧 Current Status

### ✅ Fixed Issues
1. Flutter analyzer warnings (unused code)
2. AndroidManifest cleartext traffic disabled
3. Backend plan zipcode counts corrected based on price
4. Plan features updated to show zipcodes instead of service areas
5. Zipcode add functionality removed (admin-managed only)

### ⚠️ Required Before Deployment

1. **Android Signing** - Configure release keystore
2. **Production API URL** - Set in `api_client.dart`
3. **Backend HTTPS** - Deploy with SSL certificate
4. **Environment Variables** - Configure production values
5. **Database Migration** - Ensure all migrations applied

## 📝 Deployment Steps

### Flutter App Deployment

#### Android (Google Play)
```bash
cd flutter-frontend
flutter build appbundle --release
# Upload app-release.aab to Google Play Console
```

#### iOS (App Store)
```bash
cd flutter-frontend
flutter build ios --release
# Open Xcode, archive and upload to App Store Connect
```

### Backend Deployment

```bash
cd super-admin-backend
npm install --production
NODE_ENV=production npm start
# Or use PM2: pm2 start server.js --name api-server
```

## 🔐 Security Checklist

- [ ] All API endpoints use HTTPS
- [ ] JWT tokens stored securely (✅ Using flutter_secure_storage)
- [ ] No hardcoded secrets in code
- [ ] Environment variables for sensitive data
- [ ] Database credentials secured
- [ ] CORS configured for production domain only
- [ ] Rate limiting enabled
- [ ] Input validation on all endpoints

## 🧪 Testing Checklist

- [ ] Test app login flow
- [ ] Test subscription plan display (verify zipcode counts)
- [ ] Test zipcode fetching (admin-assigned)
- [ ] Test lead fetching and filtering
- [ ] Test offline functionality
- [ ] Test on Android devices
- [ ] Test on iOS devices
- [ ] Test API endpoints with production database

## 📊 Monitoring Setup

- [ ] Error tracking (Sentry, etc.)
- [ ] Analytics (Firebase Analytics, etc.)
- [ ] Crash reporting
- [ ] Performance monitoring
- [ ] API usage metrics
- [ ] User activity tracking

## 🚨 Post-Deployment

- [ ] Monitor error logs
- [ ] Check API response times
- [ ] Verify all features working
- [ ] Test user registration flow
- [ ] Test payment/subscription flow
- [ ] Monitor database performance
- [ ] Set up alerts for critical errors

