# Backend API - Separate Deployment Guide

## Overview

Deploy the **Backend API Server** separately from the mobile app.

**Backend Location**: `super-admin-backend` (separate repository)

---

## Pre-Deployment Checklist

- [ ] Set production environment variables
- [ ] Set strong JWT_SECRET (32+ characters)
- [ ] Verify Supabase credentials
- [ ] Test backend locally
- [ ] Configure CORS for mobile app domain

---

## Step 1: Prepare Backend Code

### 1.1 Update Environment Variables

**File**: `super-admin-backend/config.env`
```env
# Production Configuration
NODE_ENV=production
PORT=3000

# Database (Supabase)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_production_service_key

# Security (CRITICAL - Change these!)
JWT_SECRET=your-very-strong-random-secret-32-chars-minimum
JWT_ADMIN_SECRET=your-admin-secret-32-chars-minimum

# CORS Configuration
FRONTEND_URL=https://your-mobile-app-domain.com
ALLOWED_ORIGINS=https://your-mobile-app-domain.com

# Optional: Email & Push Notifications
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

### 1.2 Generate Strong Secrets

```bash
# Generate JWT_SECRET (32+ characters)
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Use the output as JWT_SECRET
```

### 1.3 Test Locally

```bash
cd super-admin-backend
npm install
npm start

# Test endpoints
curl http://localhost:3000/api/health
curl http://localhost:3000/api/mobile/subscription/plans
```

---

## Step 2: Choose Deployment Platform

### Option A: Render.com (Recommended - Free Tier)

#### Setup
1. **Create Render Account**
   - Go to https://render.com
   - Sign up with GitHub

2. **Connect Repository**
   - Connect `super-admin-backend` GitHub repo

3. **Create Web Service**
   - New → Web Service
   - Select repository
   - Settings:
     - **Name**: `super-admin-backend`
     - **Region**: Choose closest to users
     - **Branch**: `main`
     - **Root Directory**: `/` (root)
     - **Environment**: `Node`
     - **Build Command**: `npm install`
     - **Start Command**: `npm start`
     - **Instance Type**: Free (or paid for production)

4. **Set Environment Variables**
   - Go to Environment tab
   - Add all variables from `config.env`:
     ```
     NODE_ENV=production
     PORT=3000
     SUPABASE_URL=...
     SUPABASE_SERVICE_ROLE_KEY=...
     JWT_SECRET=...
     FRONTEND_URL=...
     ```

5. **Deploy**
   - Click "Create Web Service"
   - Render will build and deploy
   - Get your URL: `https://super-admin-backend-xxx.onrender.com`

#### Post-Deployment
```bash
# Test health endpoint
curl https://your-app.onrender.com/api/health

# Test mobile endpoint
curl https://your-app.onrender.com/api/mobile/subscription/plans
```

---

### Option B: Heroku

#### Setup
```bash
# 1. Install Heroku CLI
# Download from heroku.com

# 2. Login
heroku login

# 3. Create app
cd super-admin-backend
heroku create your-backend-app-name

# 4. Set environment variables
heroku config:set NODE_ENV=production
heroku config:set SUPABASE_URL=your_url
heroku config:set SUPABASE_SERVICE_ROLE_KEY=your_key
heroku config:set JWT_SECRET=your_secret
heroku config:set PORT=3000

# 5. Deploy
git push heroku main

# 6. Open app
heroku open
```

#### Verify
```bash
# Test endpoints
curl https://your-app.herokuapp.com/api/health
```

---

### Option C: AWS (Elastic Beanstalk)

1. **Prepare for AWS**
   ```bash
   # Create .ebextensions folder
   mkdir .ebextensions
   ```

2. **Create `.ebextensions/nodecommand.config`**
   ```yaml
   option_settings:
     aws:elasticbeanstalk:container:nodejs:
       NodeCommand: "npm start"
   ```

3. **Deploy via EB CLI**
   ```bash
   # Install EB CLI
   pip install awsebcli
   
   # Initialize
   eb init -p node.js
   
   # Create environment
   eb create production-env
   
   # Set environment variables
   eb setenv NODE_ENV=production SUPABASE_URL=... JWT_SECRET=...
   
   # Deploy
   eb deploy
   ```

---

### Option D: DigitalOcean App Platform

1. **Create App**
   - Go to DigitalOcean → Apps
   - Create from GitHub
   - Select `super-admin-backend` repo

2. **Configure**
   - Build Command: `npm install`
   - Run Command: `npm start`
   - Environment Variables: Add all from `config.env`

3. **Deploy**
   - Click Deploy
   - Get URL: `https://your-app.ondigitalocean.app`

---

## Step 3: Configure CORS for Mobile App

After deploying backend, ensure CORS allows your mobile app:

**Backend**: `super-admin-backend/server.js`

CORS is already configured, but verify:
```javascript
// Should allow your mobile app domain (if web)
// For mobile apps (iOS/Android), CORS doesn't apply (they're native)
```

---

## Step 4: Verify Deployment

### Test Endpoints

```bash
# 1. Health Check
curl https://your-backend-url.com/api/health
# Expected: {"ok": true, ...}

# 2. Mobile Endpoints
curl https://your-backend-url.com/api/mobile/subscription/plans
# Expected: List of plans

# 3. Admin Endpoints (if testing)
curl -X POST https://your-backend-url.com/api/admin/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test","password":"test"}'
```

### Check Logs

- **Render**: Dashboard → Logs tab
- **Heroku**: `heroku logs --tail`
- **AWS**: CloudWatch Logs

---

## Step 5: Update Mobile App Configuration

After backend is deployed, update mobile app:

**File**: `lib/backend/services/api_client.dart`
```dart
class ApiClient {
  // Production Backend URL
  static const List<String> baseUrls = [
    'https://your-backend-api.onrender.com',  // Your deployed backend URL
    // Remove localhost URLs for production
  ];
  
  // ... rest of code
}
```

---

## Production Best Practices

### 1. Security
- ✅ Use HTTPS only
- ✅ Strong JWT_SECRET (32+ characters, random)
- ✅ Enable rate limiting
- ✅ Monitor API usage
- ✅ Regular security updates

### 2. Performance
- ✅ Enable compression
- ✅ Use connection pooling
- ✅ Monitor response times
- ✅ Set up caching (Redis - optional)

### 3. Monitoring
- ✅ Set up error tracking (Sentry)
- ✅ Monitor uptime
- ✅ Log all API calls
- ✅ Set up alerts

### 4. Backup
- ✅ Database backups (Supabase handles this)
- ✅ Code version control (Git)
- ✅ Environment variables backup

---

## Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `NODE_ENV` | Yes | Set to `production` |
| `PORT` | Yes | Server port (3000 default) |
| `SUPABASE_URL` | Yes | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Supabase service key |
| `JWT_SECRET` | **Critical** | Strong random secret (32+ chars) |
| `FRONTEND_URL` | Optional | Mobile/web app URL for CORS |
| `SMTP_HOST` | Optional | Email service (for emails) |

---

## Troubleshooting

### Issue: CORS Errors
**Solution**: Add mobile app domain to `ALLOWED_ORIGINS`

### Issue: Database Connection Fails
**Solution**: Verify `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`

### Issue: Authentication Fails
**Solution**: Check `JWT_SECRET` is set correctly

### Issue: Backend Crashes on Startup
**Solution**: Check logs, verify all environment variables are set

---

## Backend Deployment Status

✅ **Ready for Deployment**

**Next Steps**:
1. Set environment variables
2. Deploy to chosen platform
3. Get backend URL
4. Update mobile app with backend URL
5. Deploy mobile app

---

**Backend URL**: Save this after deployment
```
https://your-backend-api.onrender.com
```

Use this URL in mobile app `api_client.dart` configuration.

