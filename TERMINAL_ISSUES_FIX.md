# 🔧 Terminal Issues Fix Guide

## Common Terminal Issues & Solutions

### Issue 1: PowerShell Command Syntax

**Problem:** Using bash syntax (`&&`) in PowerShell

**Error:**
```
The token '&&' is not a valid statement separator in this version.
```

**Solution:** Use PowerShell syntax instead:

**❌ Wrong (Bash syntax):**
```bash
cd flutter-frontend && flutter run
```

**✅ Correct (PowerShell syntax):**
```powershell
cd flutter-frontend; flutter run
```

**Or use separate commands:**
```powershell
cd flutter-frontend
flutter run
```

---

### Issue 2: Wrong Directory

**Problem:** Running Flutter commands from wrong folder

**Error:**
```
pubspec.yaml not found
```

**Solution:**
```powershell
# Always navigate to flutter-frontend first
cd "C:\Users\kvina\Downloads\Flutter\flutter-frontend"

# Verify you're in the right place
Get-Location
# Should show: C:\Users\kvina\Downloads\Flutter\flutter-frontend

# Verify file exists
Test-Path pubspec.yaml
# Should return: True
```

---

### Issue 3: Flutter Not in PATH

**Problem:** Flutter command not recognized

**Error:**
```
flutter: command not found
```

**Solution:**
1. Add Flutter to PATH:
   - Open System Properties → Environment Variables
   - Add Flutter bin directory to PATH:
     ```
     C:\src\flutter\bin
     ```
2. Restart terminal/PowerShell
3. Verify:
   ```powershell
   flutter --version
   ```

---

### Issue 4: Backend Connection Errors

**Problem:** Terminal shows backend connection errors

**Error:**
```
❌ No backend server available
⚠️ No backend available - Auto-enabling test mode
```

**Solution:**

**Option 1: Start Backend (if needed)**
```powershell
cd super-admin-backend
npm start
```

**Option 2: Use Test Mode (no backend needed)**
- The app automatically enables test mode
- Or click "Use Test Credentials" button in app
- App works with mock data

---

### Issue 5: Build Errors

**Problem:** Flutter build fails

**Error:**
```
Error: Could not find or load main class
```

**Solution:**
```powershell
# Clean build
cd flutter-frontend
flutter clean
flutter pub get
flutter run
```

---

### Issue 6: Port Already in Use

**Problem:** Backend port already in use

**Error:**
```
Error: listen EADDRINUSE: address already in use :::3000
```

**Solution:**
```powershell
# Find process using port 3000
netstat -ano | findstr :3000

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F

# Or use different port in backend config
```

---

## ✅ Correct PowerShell Commands

### Running Flutter App

```powershell
# Navigate to frontend
cd "C:\Users\kvina\Downloads\Flutter\flutter-frontend"

# Get dependencies
flutter pub get

# Run app
flutter run

# Or specify device
flutter run -d chrome
flutter run -d windows
flutter run -d android
```

### Running Backend (if needed)

```powershell
# Navigate to backend
cd "C:\Users\kvina\Downloads\Flutter\super-admin-backend"

# Install dependencies (first time)
npm install

# Start server
npm start
```

### Checking Status

```powershell
# Check Flutter version
flutter --version

# Check current directory
Get-Location

# List files
Get-ChildItem

# Check if pubspec.yaml exists
Test-Path pubspec.yaml

# Check Flutter doctor
flutter doctor
```

---

## 🐛 Common Error Messages

### "pubspec.yaml not found"
- **Fix:** Navigate to `flutter-frontend` folder first

### "No backend server available"
- **Fix:** Start backend OR use test mode (app auto-enables)

### "Command not found"
- **Fix:** Add Flutter to PATH or use full path

### "Port already in use"
- **Fix:** Kill process using the port or change port

### "Package not found"
- **Fix:** Run `flutter pub get` in `flutter-frontend` folder

---

## 📝 Quick Reference

### Always Run From:
```
C:\Users\kvina\Downloads\Flutter\flutter-frontend
```

### PowerShell Syntax:
```powershell
# Use semicolon (;) not && for chaining commands
cd flutter-frontend; flutter run

# Or separate commands
cd flutter-frontend
flutter run
```

### Verify Setup:
```powershell
# Check directory
Get-Location

# Check Flutter
flutter --version

# Check file
Test-Path pubspec.yaml
```

---

## 🎯 Quick Fix Checklist

- [ ] Navigate to `flutter-frontend` folder
- [ ] Use PowerShell syntax (`;` not `&&`)
- [ ] Run `flutter pub get` first
- [ ] Check `flutter doctor` for issues
- [ ] Backend optional (test mode works without it)

---

**Last Updated:** 2025-01-03  
**Status:** ✅ Terminal Issues Documented

