# 🔧 Backend Running Guide

## Do You Need to Run the Backend?

### ✅ **You DON'T need backend for:**
- **Development/Testing**: The app has test mode that works without backend
- **UI Testing**: All screens and widgets work with mock data
- **Quick Development**: Test credentials bypass authentication

### ⚠️ **You DO need backend for:**
- **Real Authentication**: Actual login/registration with database
- **Real Data**: Fetching real leads, plans, and user data
- **Production Testing**: Testing end-to-end with real API
- **Full Features**: All features working with actual backend

---

## 🚀 How to Run the Backend

### Step 1: Navigate to Backend Directory

```bash
cd super-admin-backend
```

**Note:** If `super-admin-backend` folder doesn't exist in this directory, it's in a separate location. Check your project structure.

### Step 2: Install Dependencies (First Time Only)

```bash
npm install
```

### Step 3: Start the Backend Server

```bash
npm start
```

**Expected Output:**
```
Server running on port 3000
Database connected
✅ Backend ready
```

### Step 4: Verify Backend is Running

**Test Health Endpoint:**
```bash
# In browser or terminal:
http://localhost:3000/api/health
```

**Should return:**
```json
{"status": "ok"}
```

---

## 🔍 Backend Ports

The app automatically checks these ports:
- `http://localhost:3000` (default)
- `http://localhost:3001` (fallback)
- `http://localhost:3002` (fallback)

The app will automatically find the working port.

---

## 🧪 Test Mode (No Backend Required)

### How Test Mode Works:

1. **Automatic Activation:**
   - If backend is unavailable, app auto-enables test mode (debug builds only)
   - Shows dialog: "Backend unavailable. Use test mode?"

2. **Test Credentials Button:**
   - Click "Use Test Credentials (DEBUG)" button
   - Bypasses authentication completely
   - Uses mock data for all features

3. **Features in Test Mode:**
   - ✅ Login/Registration (mock)
   - ✅ Subscription Plans (dummy data)
   - ✅ Leads (dummy data)
   - ✅ Zipcodes (mock data)
   - ✅ All UI screens work

---

## 📊 Comparison: With vs Without Backend

| Feature | Without Backend (Test Mode) | With Backend |
|---------|----------------------------|--------------|
| **Authentication** | Mock/test credentials | Real JWT tokens |
| **Registration** | Simulated | Real database |
| **Subscription Plans** | Dummy data | Real from database |
| **Leads** | Mock leads | Real leads from API |
| **Zipcodes** | Mock data | Real from database |
| **User Profile** | Mock data | Real user data |
| **Payment** | Mock payment IDs | Real Stripe integration |

---

## 🐛 Troubleshooting

### Issue: "No backend server available"

**Solution 1: Start Backend**
```bash
cd super-admin-backend
npm start
```

**Solution 2: Use Test Mode**
- Click "Use Test Credentials" button
- Or accept the "Use test mode?" dialog

### Issue: Backend won't start

**Check:**
1. Node.js installed? `node --version`
2. Dependencies installed? `npm install`
3. Port 3000 available? (Check if another app is using it)
4. Database configured? (Check backend config)

### Issue: App can't find backend

**Solutions:**
1. Restart Flutter app (clears cached URL)
2. Check backend is running on port 3000, 3001, or 3002
3. For Android emulator: Backend should be on `10.0.2.2:3000` (not localhost)

---

## 🎯 Quick Decision Guide

### **Use Test Mode (No Backend) When:**
- ✅ Developing UI/UX
- ✅ Testing app flow
- ✅ Quick prototyping
- ✅ Backend is down
- ✅ Offline development

### **Use Real Backend When:**
- ✅ Testing real authentication
- ✅ Testing with real data
- ✅ Production testing
- ✅ Integration testing
- ✅ Testing payment flows

---

## 📝 Summary

**For Development:**
- **Backend Optional**: App works with test mode
- **Backend Recommended**: For full feature testing

**For Production:**
- **Backend Required**: Must have backend running
- **Backend URL**: Set production URL in `api_client.dart`

**Current Status:**
- ✅ App works without backend (test mode)
- ✅ App works with backend (real mode)
- ✅ Automatic fallback to test mode if backend unavailable

---

## 🔗 Related Documentation

- `END_TO_END_FIXES.md` - Test mode implementation
- `AUTHENTICATION_TROUBLESHOOTING.md` - Auth issues
- `QUICK_FIX_AUTHENTICATION.md` - Quick fixes

