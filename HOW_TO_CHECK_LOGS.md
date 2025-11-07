# 📋 How to Check Flutter App Logs

## Where to Find Logs

### 1. **Terminal/Command Line (Recommended)**

When you run the Flutter app, logs appear in the terminal where you executed `flutter run`.

**Steps:**
1. Open terminal/command prompt
2. Navigate to your Flutter project:
   ```bash
   cd flutter-frontend
   ```
3. Run the app:
   ```bash
   flutter run
   ```
4. **Logs will appear in this same terminal window**

**What you'll see:**
```
Launching lib/main.dart on [device]...
✅ API client initialized successfully
✅ Test mode disabled - Using live backend
📤 POST http://localhost:3000/api/mobile/auth/register
📤 Request body: {...}
📤 Request headers: {...}
📥 Response status: 200
✅ Registration successful
```

---

### 2. **VS Code / Android Studio / IntelliJ IDEA**

If you're using an IDE, logs appear in the **Debug Console** or **Run** panel.

**VS Code:**
- Open **View** → **Output**
- Select **Flutter** or **Debug Console** from the dropdown
- Logs appear here when app runs

**Android Studio / IntelliJ:**
- Look at the **Run** tab at the bottom
- Or **View** → **Tool Windows** → **Run**
- Logs appear in the console panel

---

### 3. **Flutter DevTools (Advanced)**

For more detailed logs and debugging:

1. Run app with verbose logging:
   ```bash
   flutter run --verbose
   ```

2. Open Flutter DevTools:
   ```bash
   flutter pub global activate devtools
   flutter pub global run devtools
   ```

3. Connect to running app and view logs in DevTools

---

## 🔍 What to Look For

### Registration Request Logs

When you try to register, look for these log messages:

**✅ Good Signs:**
```
📤 POST http://localhost:3000/api/mobile/auth/register
📤 Request body: {"email":"...","password":"...","agency_name":"..."}
📤 Request headers: {Content-Type: application/json}
📤 requireAuth: false, includeAuth: false
📤 JWT token present: false
📥 Response status: 200
✅ Registration successful
```

**❌ Error Signs:**
```
❌ No backend server available
❌ Registration failed: [error message]
❌ Status code: 400/409/500
📥 Response body: {"error":"..."}
```

---

## 📱 Platform-Specific Logs

### Android

**Option 1: Flutter Console**
```bash
flutter run
# Logs appear in terminal
```

**Option 2: Android Logcat**
```bash
flutter run
# In another terminal:
adb logcat | grep flutter
```

**Option 3: Android Studio**
- Open **Logcat** tab
- Filter by "flutter" or "Dart"

---

### iOS

**Option 1: Flutter Console**
```bash
flutter run
# Logs appear in terminal
```

**Option 2: Xcode Console**
- Open Xcode
- Run app from Xcode
- View logs in **Debug Console**

**Option 3: Console.app (macOS)**
- Open **Console.app**
- Filter by your app name

---

### Web

**Option 1: Browser Console**
1. Run: `flutter run -d chrome`
2. Open browser DevTools (F12)
3. Go to **Console** tab
4. Flutter logs appear here

**Option 2: Terminal**
```bash
flutter run -d chrome
# Logs also appear in terminal
```

---

## 🔧 Filtering Logs

### Search for Specific Logs

**In Terminal (Linux/Mac):**
```bash
flutter run | grep "Registration\|POST\|Response\|Error"
```

**In PowerShell (Windows):**
```powershell
flutter run | Select-String "Registration|POST|Response|Error"
```

**In VS Code:**
- Use **Ctrl+F** (or **Cmd+F** on Mac) in the Output panel
- Search for keywords like "Registration", "POST", "Error"

---

## 📝 Key Log Messages to Watch

### Registration Flow Logs

1. **App Startup:**
   ```
   ✅ API client initialized successfully
   ✅ Test mode disabled - Using live backend
   ```

2. **Backend Connection:**
   ```
   ✅ Connected to backend: http://127.0.0.1:3000
   ```

3. **Registration Request:**
   ```
   📤 POST http://localhost:3000/api/mobile/auth/register
   📤 Request body: {...}
   📤 Request headers: {...}
   📤 requireAuth: false, includeAuth: false
   📤 JWT token present: false
   ```

4. **Registration Response:**
   ```
   📥 Response status: 200
   📥 Response body: {...}
   ✅ Registration successful
   ```

5. **Error Logs:**
   ```
   ❌ Registration error: [error]
   ❌ Status code: [code]
   ❌ Full error response: [response]
   ```

---

## 🚀 Quick Start Guide

### Step 1: Open Terminal
- **Windows:** PowerShell or Command Prompt
- **Mac/Linux:** Terminal

### Step 2: Navigate to Project
```bash
cd flutter-frontend
```

### Step 3: Run App
```bash
flutter run
```

### Step 4: Watch Logs
- Logs appear in the same terminal
- Scroll up to see previous logs
- Look for messages starting with:
  - `📤` (Request)
  - `📥` (Response)
  - `✅` (Success)
  - `❌` (Error)

### Step 5: Try Registration
- Fill registration form
- Submit
- **Watch terminal for logs**

---

## 💡 Tips

1. **Keep Terminal Open:** Don't close the terminal where you ran `flutter run` - that's where logs appear

2. **Scroll Up:** If you miss a log, scroll up in the terminal to see previous messages

3. **Copy Logs:** Select and copy log messages to share for debugging

4. **Clear Screen:** 
   - **Windows:** `cls`
   - **Mac/Linux:** `clear`
   - Or **Ctrl+L** / **Cmd+K**

5. **Save Logs to File:**
   ```bash
   flutter run > logs.txt 2>&1
   ```
   Then open `logs.txt` to view all logs

---

## 🐛 Common Issues

### "I don't see any logs"

**Solution:**
- Make sure you're looking at the terminal where you ran `flutter run`
- Check if app is actually running
- Try running with verbose flag: `flutter run --verbose`

### "Logs are too long/scrolling too fast"

**Solution:**
- Use filtering (see above)
- Save to file: `flutter run > logs.txt 2>&1`
- Use IDE console which has better scrolling/search

### "I see logs but not the registration ones"

**Solution:**
- Make sure you're actually submitting the registration form
- Check if logs are being filtered
- Try searching for "POST" or "Registration" in logs

---

## 📞 Need Help?

If registration is still failing:

1. **Copy the error logs** from terminal
2. **Look for these specific messages:**
   - `📤 POST` (shows what's being sent)
   - `📥 Response status` (shows backend response)
   - `❌ Registration failed` (shows the error)

3. **Share the logs** - they contain all the information needed to diagnose the issue

---

**Last Updated:** 2025-01-03  
**Status:** ✅ Complete guide for checking logs

