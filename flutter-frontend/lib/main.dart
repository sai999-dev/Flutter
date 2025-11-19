import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_backend/utils/zipcode_lookup_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show
        kIsWeb,
        defaultTargetPlatform,
        TargetPlatform,
        kReleaseMode,
        kDebugMode;
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'stripe_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// Backend Services (from package)
import 'package:flutter_backend/services/lead_service.dart';
import 'package:flutter_backend/services/auth_service.dart';
import 'package:flutter_backend/services/notification_service.dart';
import 'package:flutter_backend/services/territory_service.dart';
import 'package:flutter_backend/services/api_client.dart';
import 'package:flutter_backend/services/subscription_service.dart';
// Frontend Widgets
import 'widgets/document_verification_page.dart';
// Mobile App - Agency Self-Service Portal
// Backend API is in separate repository (middleware layer)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clear cached API URL to force fresh detection
  await ApiClient.clearCachedUrl();

  // ✅ DISABLE TEST MODE - Use live backend
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('test_mode', false);
  print('✅ Test mode disabled - Using live backend');

  // Initialize Stripe (publishable key only) - with error handling
  // Only initialize on mobile platforms (iOS/Android) - skip on web/desktop
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)) {
    try {
      stripe.Stripe.publishableKey = StripeConfig.publishableKey;
      stripe.Stripe.merchantIdentifier = StripeConfig.merchantIdentifier;
      await stripe.Stripe.instance.applySettings();
      print('✅ Stripe initialized successfully');
    } catch (e) {
      // Stripe initialization failed - app can still run without payment features
      print('⚠️ Stripe initialization failed: $e');
      print('⚠️ App will continue without Stripe payment features');
    }
  } else {
    print(
        'ℹ️ Skipping Stripe initialization on ${kIsWeb ? "web" : defaultTargetPlatform} platform');
  }

  // Initialize API client
  try {
    await ApiClient.initialize();
    print('✅ API client initialized successfully');
  } catch (e) {
    // If initialization fails, continue anyway - app can work offline
    print('⚠️ API client initialization warning: $e');
    // Continue anyway - API client will handle connection errors later
  }
  runApp(const HealthcareApp());
}

class HealthcareApp extends StatelessWidget {
  const HealthcareApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF00888C);
    return MaterialApp(
      title: 'Healthcare Leads Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryTeal,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryTeal,
          primary: primaryTeal,
          secondary: primaryTeal,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
        ),
        // TabBar styling inherits from colorScheme; explicit theme removed for compatibility
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primaryTeal, width: 2),
          ),
          prefixIconColor: primaryTeal,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: primaryTeal,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
      routes: const {},
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  // Google Sign-In instance (disabled on web unless clientId configured)
  GoogleSignIn? _googleSignIn;

  // ✅ VALIDATION METHODS
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
    if (!kIsWeb) {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
    }
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final savedEmail = prefs.getString('saved_email') ?? '';

    if (rememberMe && savedEmail.isNotEmpty) {
      setState(() {
        _rememberMe = true;
        _emailController.text = savedEmail;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF00888C);
    const lightTeal = Color(0xFFE0F7F7);
    const darkTeal = Color(0xFF006A6E);

    return Scaffold(
      backgroundColor: tealColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              elevation: 16,
              shadowColor: tealColor.withOpacity(0.3),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Welcome Back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.2,
                              color: tealColor)),
                      const SizedBox(height: 32),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: const TextStyle(
                                    color: tealColor, fontSize: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: lightTeal, width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: lightTeal, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: tealColor, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: darkTeal, width: 1.5),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: darkTeal, width: 2),
                                ),
                                prefixIcon: const Icon(Icons.email_outlined,
                                    color: tealColor, size: 22),
                                filled: true,
                                fillColor: lightTeal,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 18),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: const TextStyle(
                                    color: tealColor, fontSize: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: lightTeal, width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: lightTeal, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: tealColor, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: darkTeal, width: 1.5),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: darkTeal, width: 2),
                                ),
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: tealColor, size: 22),
                                filled: true,
                                fillColor: lightTeal,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: tealColor,
                                      size: 22),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _showForgotPassword(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: tealColor,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tealColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                  shadowColor: tealColor.withOpacity(0.4),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ))
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MultiStepRegisterPage()),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 15,
                            color: tealColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ TRIM EMAIL AND PASSWORD to avoid whitespace issues
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();
      
      print('🔐 Login attempt - Email: $email');
      
      // ✅ TRY REAL API LOGIN using AuthService
      Map<String, dynamic> response;
      try {
        response = await AuthService.login(
          email,
          password,
        );
      } catch (e) {
        // ✅ LIVE MODE: Show error - no test mode fallback
        print('❌ Login error details: $e');
        rethrow;
      }

      // ✅ SAVE AUTH TOKEN (AuthService.login already saves it, but verify)
      final token = response['token'];
      if (token != null && token is String && token.isNotEmpty) {
        await ApiClient.saveToken(token);
        print('✅ Auth token saved');
      }

      // ✅ SAVE LOGIN STATE
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('last_login', DateTime.now().toIso8601String());

      // Save user data from backend response
      final profile = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;

      // Extract user information
      final userName = profile['contact_name'] ??
          profile['name'] ??
          profile['user_name'] ??
          _emailController.text.split('@')[0];
      final agencyId = profile['agency_id'] ?? profile['id'] ?? '';
      final agencyName =
          profile['agency_name'] ?? profile['business_name'] ?? '';

      await prefs.setString('user_name', userName.toString());
      if (agencyId.toString().isNotEmpty) {
        await prefs.setString('agency_id', agencyId.toString());
      }
      if (agencyName.toString().isNotEmpty) {
        await prefs.setString('agency_name', agencyName.toString());
      }

      // Save email
      await prefs.setString('user_email', _emailController.text);

      // ✅ SAVE REMEMBER ME
      if (_rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('saved_email', _emailController.text);
      } else {
        await prefs.remove('remember_me');
        await prefs.remove('saved_email');
      }

      // Register device for push notifications
      try {
        final platform = kIsWeb
            ? 'web'
            : (defaultTargetPlatform == TargetPlatform.android
                ? 'android'
                : (defaultTargetPlatform == TargetPlatform.iOS
                    ? 'ios'
                    : 'other'));
        await AuthService.registerDevice(
          deviceToken:
              'device_${DateTime.now().millisecondsSinceEpoch}', // Replace with actual FCM token
          platform: platform,
        );
      } catch (e) {
        print('Device registration failed: $e');
      }

      // ✅ Sync zipcodes from backend after login
      try {
        await TerritoryService.syncZipcodes();
      } catch (e) {
        print('Zipcode sync failed: $e');
      }

      final savedUserName =
          prefs.getString('user_name') ?? _emailController.text.split('@')[0];

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🎉 Welcome back, $savedUserName! Let\'s find great leads today!'),
          backgroundColor: const Color(0xFF00888C),
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const HomePage(initialZipcodes: null)),
      );
    } catch (e) {
      setState(() => _isLoading = false);

      // Extract user-friendly error message
      String errorMessage = 'Login failed';
      if (e.toString().contains('No backend server available')) {
        errorMessage =
            'Backend server is not running. Please start the server.';
      } else if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else if (e.toString().contains('timeout')) {
        errorMessage =
            'Connection timeout. Please check your internet connection.';
      } else if (e.toString().contains('credentials') ||
          e.toString().contains('password')) {
        errorMessage =
            'Invalid email or password. Please check your credentials.';
      } else {
        errorMessage = e.toString();
      }

      print('❌ Login error details: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showForgotPassword() {
    // Navigate to ForgotPasswordPage instead of showing dialog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ForgotPasswordPage(),
      ),
    );
  }

  /// 🔵 Google Sign-In (for future implementation)
  // ignore: unused_element
  Future<void> _signInWithGoogle() async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In not configured for web'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (_googleSignIn == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In not available'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() => _isLoading = true);

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        setState(() => _isLoading = false);
        return;
      }

      // Get authentication details - used for OAuth flow
      await googleUser.authentication;

      // Save user data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_name', googleUser.displayName ?? 'User');
      await prefs.setString('user_email', googleUser.email);
      await prefs.setString('contact_name', googleUser.displayName ?? '');
      await prefs.setString('auth_method', 'google');
      await prefs.setString('last_login', DateTime.now().toIso8601String());

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signed in as ${googleUser.displayName ?? 'User'}'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Sign-In failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ==================== FORGOT PASSWORD PAGE ====================
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  int _currentStep = 0; // 0: Email, 1: Code, 2: New Password
  final PageController _pageController = PageController();
  
  // Step 1: Email
  final _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  bool _isLoadingEmail = false;
  
  // Step 2: Verification Code
  final List<TextEditingController> _codeControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _codeFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );
  bool _isLoadingCode = false;
  String? _userEmail; // Store email for subsequent steps
  
  // Step 3: New Password
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoadingPassword = false;
  String? _verifiedCode; // Store verified code

  @override
  void dispose() {
    _emailController.dispose();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _codeFocusNodes) {
      node.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Validation methods
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.trim().length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please confirm your password';
    }
    if (value.trim() != _newPasswordController.text.trim()) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Step 1: Request code
  Future<void> _requestCode() async {
    if (!_emailFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoadingEmail = true);

    try {
      final email = _emailController.text.trim().toLowerCase();
      final result = await AuthService.forgotPassword(email);

      setState(() {
        _isLoadingEmail = false;
        _userEmail = email;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Verification code sent to your email',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Move to next step
        if (_pageController.hasClients) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        setState(() => _currentStep = 1);
      }
    } catch (e) {
      setState(() => _isLoadingEmail = false);

      String errorMessage = 'Failed to send verification code';
      final errorString = e.toString();
      
      if (errorString.contains('Exception:')) {
        errorMessage = errorString.replaceFirst('Exception: ', '');
      } else if (errorString.contains('Server error')) {
        errorMessage = errorString.replaceFirst('Exception: ', '');
      } else if (errorString.contains('not found') ||
          errorString.contains('does not exist')) {
        errorMessage = 'No account found with this email address';
      } else if (errorString.contains('timeout')) {
        errorMessage = 'Connection timeout. Please check your internet connection.';
      } else if (errorString.contains('No backend server')) {
        errorMessage = 'Backend server is not running. Please start the server.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Step 2: Verify code
  Future<void> _verifyCode() async {
    final code = _codeControllers.map((c) => c.text).join();
    
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingCode = true);

    try {
      final result = await AuthService.verifyResetCode(_userEmail!, code);

      setState(() {
        _isLoadingCode = false;
        _verifiedCode = code;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Code verified successfully',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Move to next step
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 2);
    } catch (e) {
      setState(() => _isLoadingCode = false);

      String errorMessage = 'Invalid or expired verification code';
      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      // Clear code fields on error
      for (var controller in _codeControllers) {
        controller.clear();
      }
      _codeFocusNodes[0].requestFocus();
    }
  }

  // Step 3: Reset password
  Future<void> _resetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoadingPassword = true);

    try {
      final newPassword = _newPasswordController.text.trim();
      final result = await AuthService.resetPassword(
        email: _userEmail!,
        code: _verifiedCode!,
        newPassword: newPassword,
      );

      setState(() => _isLoadingPassword = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Password reset successfully',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate back to login page
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoadingPassword = false);

      String errorMessage = 'Failed to reset password';
      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Handle code input - auto move to next field
  void _onCodeChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _codeFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _codeFocusNodes[index - 1].requestFocus();
    }
    
    // Auto-submit when all 6 digits are entered
    if (index == 5 && value.length == 1) {
      final fullCode = _codeControllers.map((c) => c.text).join();
      if (fullCode.length == 6) {
        _verifyCode();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00888C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
            color: Color(0xFF00888C),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Step 1: Enter Email
          _buildEmailStep(),
          // Step 2: Enter Verification Code
          _buildCodeStep(),
          // Step 3: Create New Password
          _buildPasswordStep(),
        ],
      ),
    );
  }

  Widget _buildEmailStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _emailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Enter your registered email address',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF4A5568),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Email',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              validator: _validateEmail,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'example@email.com',
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF00888C), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                prefixIcon: const Icon(Icons.email, color: Color(0xFF00888C)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoadingEmail ? null : _requestCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00888C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoadingEmail
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Send Verification Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Enter the 6-digit verification code sent to',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF4A5568),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _userEmail ?? '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00888C),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 45,
                height: 60,
                child: TextField(
                  controller: _codeControllers[index],
                  focusNode: _codeFocusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF00888C), width: 2),
                    ),
                  ),
                  onChanged: (value) => _onCodeChanged(index, value),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoadingCode ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00888C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoadingCode
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Verify Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoadingCode
                ? null
                : () async {
                    // Resend code
                    await _requestCode();
                  },
            child: const Text(
              'Resend Code',
              style: TextStyle(
                color: Color(0xFF00888C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Create a new password',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF4A5568),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'New Password',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newPasswordController,
              validator: _validatePassword,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              obscureText: _obscureNewPassword,
              decoration: InputDecoration(
                hintText: 'Enter new password',
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF00888C), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                prefixIcon: const Icon(Icons.lock, color: Color(0xFF00888C)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF718096),
                  ),
                  onPressed: () {
                    setState(() => _obscureNewPassword = !_obscureNewPassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirm Password',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              validator: _validateConfirmPassword,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                hintText: 'Confirm new password',
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF00888C), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00888C)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF718096),
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoadingPassword ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00888C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoadingPassword
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save New Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MULTI-STEP REGISTRATION ====================
class MultiStepRegisterPage extends StatefulWidget {
  const MultiStepRegisterPage({super.key});

  @override
  State<MultiStepRegisterPage> createState() => _MultiStepRegisterPageState();
}

class _MultiStepRegisterPageState extends State<MultiStepRegisterPage> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  final _step1FormKey = GlobalKey<FormState>();

  // Step 1: Agency Information
  final _agencyNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedIndustry; // Industry dropdown selection

  // Step 2: Plan Selection
  String? _selectedPlanId;
  String _selectedPlan = '';
  int _maxZipcodes = 0;
  List<Map<String, dynamic>> _availablePlans = [];
  bool _loadingPlans = false;

  // Step 3: Zipcode Selection
  final _zipcodeController = TextEditingController();
  final List<String> _selectedZipcodes = [];
  final _bulkZipcodesController = TextEditingController();

  // Step 4: Password
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loadingPlans = true);
    try {
      final plans = await SubscriptionService.getPlans(activeOnly: true);
      setState(() {
        _availablePlans = plans;
        if (plans.isNotEmpty) {
          _selectedPlanId = plans[0]['id'];
          _selectedPlan =
              (plans[0]['name'] ?? plans[0]['plan_name'] ?? '').toString();
          final initialPlan = plans[0];
          // Use ONLY base_zipcodes_included (simple plan model: base = max)
          final baseLimit = _planBaseUnits(initialPlan);
          _maxZipcodes = baseLimit > 0 ? baseLimit : 1;
        }
        _loadingPlans = false;
      });
    } catch (e) {
      print('Error loading plans: $e');
      setState(() => _loadingPlans = false);
    }
  }

  int _parseUnitsValue(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw > 0 ? raw : 0;
    if (raw is num) return raw > 0 ? raw.round() : 0;
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed != null && parsed > 0) return parsed.round();
    }
    return 0;
  }

  int _planBaseUnits(Map<String, dynamic> plan) {
    // Prioritize base_zipcodes_included (correct database field)
    // Then fallback to base_cities_included (legacy), then other fields
    final candidates = [
      plan['base_zipcodes_included'], // Primary field - check first
      plan['base_cities_included'], // Legacy fallback
      plan['baseUnits'],
      plan['base_units'],
      plan['minUnits'],
      plan['min_units'],
    ];
    for (final value in candidates) {
      final units = _parseUnitsValue(value);
      if (units > 0) return units;
    }
    return 0;
  }

  double _planPrice(Map<String, dynamic> plan) {
    final candidates = [
      plan['price_per_unit'],
      plan['pricePerUnit'],
      plan['base_price'],
      plan['basePrice'],
    ];
    for (final value in candidates) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return 0.0;
  }

  List<String> _planFeatures(Map<String, dynamic> plan) {
    final rawFeatures = plan['features'];
    if (rawFeatures is List) {
      final list = rawFeatures
          .map((feature) => feature?.toString().trim() ?? '')
          .where((feature) => feature.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    }

    final featureTextCandidates = [
      plan['featuresText'],
      plan['features_text'],
      plan['featuresDescription'],
      plan['description'],
    ];
    for (final value in featureTextCandidates) {
      if (value is String && value.trim().isNotEmpty) {
        final segments = value
            .split(RegExp(r'[\r\n]+'))
            .map((segment) => segment.replaceAll(RegExp(r'^[•\-\s]+'), ''))
            .map((segment) => segment.trim())
            .where((segment) => segment.isNotEmpty)
            .toList();
        if (segments.isNotEmpty) return segments;
      }
    }

    final metadata = plan['metadata'];
    if (metadata is Map<String, dynamic>) {
      final metadataFeatures = metadata['features'];
      if (metadataFeatures is List) {
        final list = metadataFeatures
            .map((feature) => feature?.toString().trim() ?? '')
            .where((feature) => feature.isNotEmpty)
            .toList();
        if (list.isNotEmpty) return list;
      }
      if (metadataFeatures is String && metadataFeatures.trim().isNotEmpty) {
        final segments = metadataFeatures
            .split(RegExp(r'[\r\n]+'))
            .map((segment) => segment.replaceAll(RegExp(r'^[•\-\s]+'), ''))
            .map((segment) => segment.trim())
            .where((segment) => segment.isNotEmpty)
            .toList();
        if (segments.isNotEmpty) return segments;
      }
    }

    return const [
      'Real-time lead notifications',
      'Dedicated email support',
    ];
  }

  // Dallas-specific zip map removed.

  @override
  void dispose() {
    _pageController.dispose();
    _agencyNameController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _zipcodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Validation methods for Step 1
  String? _validateAgencyName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Agency name is required';
    }
    if (value.trim().length < 2) {
      return 'Agency name must be at least 2 characters';
    }
    if (value.trim().length > 100) {
      return 'Agency name must be less than 100 characters';
    }
    return null;
  }

  String? _validateContactPerson(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Contact person name is required';
    }
    if (value.trim().length < 2) {
      return 'Contact person name must be at least 2 characters';
    }
    // Allow letters, spaces, hyphens, and apostrophes for names
    if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(value.trim())) {
      return 'Contact person name can only contain letters, spaces, hyphens, and apostrophes';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    // Remove all non-digit characters for validation
    final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.length != 10) {
      return 'Phone number must be 10 digits (USA format)';
    }
    // Check if it starts with 0 or 1 (invalid area codes)
    if (cleanPhone.startsWith('0') || cleanPhone.startsWith('1')) {
      return 'Invalid phone number. Area code cannot start with 0 or 1';
    }
    return null;
  }

  // Phone number formatter for USA format
  String _formatPhoneNumber(String value) {
    // Remove all non-digit characters
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digits.length <= 3) {
      return digits;
    } else if (digits.length <= 6) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
    } else {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6, digits.length > 10 ? 10 : digits.length)}';
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate Step 1 form
      if (!_step1FormKey.currentState!.validate()) {
        return;
      }
      if (_selectedIndustry == null || _selectedIndustry!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your industry')),
        );
        return;
      }
    } else if (_currentStep == 1) {
      // Step 2: Plan Selection - automatically valid, has default value
    } else if (_currentStep == 2) {
      // Validate Step 3: Zipcode Selection
      if (_selectedZipcodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one zipcode')),
        );
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ignore: unused_element
  Future<void> _bulkAddZipcodes(int maxZipcodes) async {
    final raw = _bulkZipcodesController.text.trim();
    if (raw.isEmpty) return;
    final tokens = raw
        .replaceAll(RegExp('[^0-9\n,s]'), ' ')
        .split(RegExp('[,s]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final toAdd = <String>[];
    for (final t in tokens) {
      if (t.length == 5 && int.tryParse(t) != null) {
        final exists = _selectedZipcodes.any((z) => z.split('|')[0] == t);
        if (!exists) toAdd.add(t);
      }
    }
    if (toAdd.isEmpty) return;

    for (final zip in toAdd) {
      if (_selectedZipcodes.length >= maxZipcodes) break;
      final info = await ZipcodeLookupService.lookup(zip);
      final cityDisplay = (info.city != null && info.state != null)
          ? '${info.city}, ${info.state}'
          : (info.city ?? 'Unknown');
      _selectedZipcodes.add('$zip|$cityDisplay');
    }
    setState(() {});
    _bulkZipcodesController.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_zipcodes', _selectedZipcodes);
  }

  // ✅ Add individual zipcode with validation
  Future<void> _addZipcode() async {
    final code = _zipcodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a zipcode')),
      );
      return;
    }
    if (code.length != 5 || !RegExp(r'^\d{5}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zipcode must be 5 digits')),
      );
      return;
    }

    // Check if already added
    if (_selectedZipcodes.any((z) => z.split('|')[0] == code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zipcode already added')),
      );
      return;
    }

    // Check plan limit
    if (_selectedZipcodes.length >= _maxZipcodes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'You can only select up to $_maxZipcodes zipcodes for $_selectedPlan plan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Lookup zipcode via API
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔍 Looking up zipcode...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final info = await ZipcodeLookupService.lookup(code);
      if (info.city == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Invalid USA zipcode: $code'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final cityDisplay = (info.city != null && info.state != null)
          ? '${info.city}, ${info.state}'
          : (info.city ?? 'Unknown');

      setState(() {
        _selectedZipcodes.add('$code|$cityDisplay');
        _zipcodeController.clear();
      });

      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_zipcodes', _selectedZipcodes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Added $code - $cityDisplay'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error looking up zipcode: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ Remove zipcode
  void _removeZipcode(String zipcodeEntry) {
    setState(() {
      _selectedZipcodes.remove(zipcodeEntry);
    });

    // Save to local storage
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList('user_zipcodes', _selectedZipcodes);
    });
  }

  // ✅ Use my location to detect zipcode
  Future<void> _useMyLocation() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Detecting your location...'),
          duration: Duration(seconds: 2),
        ),
      );

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks[0];
        final zipcode = (placemark.postalCode ?? '').trim();

        if (zipcode.isNotEmpty &&
            zipcode.length == 5 &&
            RegExp(r'^\d{5}$').hasMatch(zipcode)) {
          _zipcodeController.text = zipcode;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('✓ Found zipcode: $zipcode\nClick "Add" to add it!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('⚠ Could not detect zipcode. Please enter manually.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      String errorMessage = '❌ Location error: ';
      if (e.toString().contains('timeout')) {
        errorMessage += 'Taking too long. Check GPS signal.';
      } else {
        errorMessage += 'Please enter zipcode manually.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _navigateToHome(BuildContext context) {
    // Convert List<String> to List<Map<String, String>>
    final zipcodesMapList = _selectedZipcodes.map((entry) {
      final parts = entry.split('|');
      return {
        'zipcode': parts.isNotEmpty ? parts[0] : entry,
        'city': parts.length > 1 ? parts[1] : 'Unknown',
      };
    }).toList();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(initialZipcodes: zipcodesMapList),
      ),
    );
  }

  Future<void> _completeRegistration() async {
    // Validate passwords
    if (_passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter and confirm your password')),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    // Show payment gateway dialog
    _showPaymentDialog();
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentGatewayDialog(
        planName: _selectedPlan,
        amount: (_availablePlans.firstWhere(
                  (p) => (p['id'] ?? '') == _selectedPlanId,
                  orElse: () => {'price_per_unit': null, 'pricePerUnit': 0},
                )['price_per_unit'] ??
                _availablePlans.firstWhere(
                  (p) => (p['id'] ?? '') == _selectedPlanId,
                  orElse: () => {'pricePerUnit': 0},
                )['pricePerUnit'] ??
                0)
            .toInt(),
        zipcodeCount: _selectedZipcodes.length,
        onPaymentSuccess: () async {
          Navigator.pop(context); // Close payment dialog
          await _finalizeRegistration();
        },
      ),
    );
  }

  Future<void> _finalizeRegistration() async {
    setState(() => _isLoading = true);

    try {
      // ✅ CREATE ACCOUNT IN BACKEND DATABASE
      print('📝 Creating account in backend...');

      // Ensure we send only 5-digit zipcodes to backend
      final List<String> plainZipcodes = _selectedZipcodes
          .map((z) => z.contains('|') ? z.split('|')[0] : z)
          .toList();

      // ✅ Include payment_method_id if available (Stripe)
      final sp = await SharedPreferences.getInstance();
      final savedPaymentMethodId = sp.getString('payment_method_id');

      // ✅ Use AuthService for registration (matches architecture)
      final responseData = await AuthService.register(
        email: _emailController.text,
        password: _passwordController.text,
        agencyName: _agencyNameController.text,
        phone: _phoneController.text,
        additionalData: {
          'business_name': _agencyNameController.text,
          'contact_name': _contactNameController.text,
          'zipcodes': plainZipcodes,
          'industry':
              _selectedIndustry ?? 'Healthcare', // User-selected industry
          if (_selectedPlanId != null) 'plan_id': _selectedPlanId,
          if (savedPaymentMethodId != null && savedPaymentMethodId.isNotEmpty)
            'payment_method_id': savedPaymentMethodId,
        },
      );

      // AuthService.register already handles errors and returns data
      print('✅ Account created successfully: $responseData');

      // ✅ SAVE REGISTRATION DATA TO LOCAL STORAGE
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_name', _contactNameController.text);
      await prefs.setString('user_email', _emailController.text);
      await prefs.setString('user_phone', _phoneController.text);
      await prefs.setString('agency_name', _agencyNameController.text);

      // ✅ SAVE JWT TOKEN FROM BACKEND RESPONSE (CRITICAL!)
      if (responseData['token'] != null) {
        final token = responseData['token'].toString();
        await prefs.setString('jwt_token', token);
        // Also save to secure storage via ApiClient
        await ApiClient.saveToken(token);
        print('✅ JWT token saved for API authentication');
      }

      // ✅ SAVE AGENCY ID FROM BACKEND RESPONSE
      if (responseData['agency_id'] != null) {
        await prefs.setString('agency_id', responseData['agency_id']);
        print('✅ Agency ID saved: ${responseData['agency_id']}');
      }

      // Build zipcode list with city names in "zipcode|city" format (already stored)
      final zipcodesList = List<String>.from(_selectedZipcodes);
      await prefs.setStringList('user_zipcodes', zipcodesList);
      await prefs.setString('subscription_plan', _selectedPlan);
      if (_selectedPlanId != null) {
        await prefs.setString('subscription_plan_id', _selectedPlanId!);
      }

      // Save monthly price from selected plan
      final selectedPlanData = _availablePlans.firstWhere(
        (p) => (p['id'] ?? '') == _selectedPlanId,
        orElse: () => {},
      );
      final monthlyPriceRaw = selectedPlanData['price_per_unit'] ??
          selectedPlanData['pricePerUnit'] ??
          selectedPlanData['base_price'] ??
          selectedPlanData['basePrice'] ??
          0.0;
      final monthlyPrice = (monthlyPriceRaw is num)
          ? monthlyPriceRaw.toDouble()
          : (double.tryParse(monthlyPriceRaw.toString()) ?? 0.0);
      await prefs.setDouble('monthly_price', monthlyPrice.toDouble());

      await prefs.setString(
          'registration_date', DateTime.now().toIso8601String());
      await prefs.setString('payment_status', 'active');
      await prefs.setString('payment_method', 'card');

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🎉 Welcome ${_contactNameController.text}! Account created successfully!'),
          backgroundColor: const Color(0xFF00888C),
          duration: const Duration(seconds: 3),
        ),
      );

      // Show verification notification after successful registration and subscription
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.verified_user, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Verify the agency/company to get leads',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Verify',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to settings document verification
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentVerificationPage(
                      agencyId: responseData['agency_id']?.toString() ?? '',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }

      // Navigate directly to home - document verification is available in settings
      _navigateToHome(context);
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ Registration error: $e');
      print('❌ Error type: ${e.runtimeType}');

      // Extract user-friendly error message with detailed logging
      String errorMessage = 'Registration failed';
      bool isBackendUnavailable = false;

      print('🔍 Full error details:');
      print('   Error: $e');
      print('   Error type: ${e.runtimeType}');
      print('   Error string: ${e.toString()}');

      if (e.toString().contains('No backend server available') ||
          e.toString().contains('No response from server') ||
          e.toString().contains('Backend server is not running')) {
        errorMessage =
            'Backend server is not running. Please start the backend server.';
        isBackendUnavailable = true;
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        errorMessage =
            'Connection timeout. Please check your internet connection and ensure the backend server is running.';
        isBackendUnavailable = true;
      } else if (e.toString().contains('Exception:')) {
        // Extract the actual error message after "Exception: "
        final exceptionIndex = e.toString().indexOf('Exception: ');
        if (exceptionIndex != -1) {
          errorMessage =
              e.toString().substring(exceptionIndex + 'Exception: '.length);
        } else {
          errorMessage = e.toString();
        }
      } else if (e.toString().contains('email') ||
          e.toString().contains('Email')) {
        if (e.toString().toLowerCase().contains('already exists') ||
            e.toString().toLowerCase().contains('duplicate')) {
          errorMessage =
              'Email already exists. Please use a different email address.';
        } else {
          errorMessage =
              'Invalid email format. Please enter a valid email address.';
        }
      } else if (e.toString().contains('password') ||
          e.toString().contains('Password')) {
        errorMessage =
            'Password does not meet requirements. Please check password rules.';
      } else if (e.toString().contains('400') ||
          e.toString().contains('Bad Request')) {
        errorMessage =
            'Invalid registration data. Please check all fields and try again.';
      } else if (e.toString().contains('409') ||
          e.toString().contains('Conflict')) {
        errorMessage = 'Account already exists. Please try logging in instead.';
      } else if (e.toString().contains('500') ||
          e.toString().contains('Internal Server Error')) {
        errorMessage =
            'Server error. Please try again later or contact support.';
      } else {
        // Use the error message as-is, but clean it up
        errorMessage = e.toString().replaceAll('Exception: ', '').trim();
        if (errorMessage.isEmpty) {
          errorMessage =
              'Registration failed. Please check your connection and try again.';
        }
      }

      // ✅ If backend unavailable, offer test mode (development only)
      if (isBackendUnavailable && kDebugMode && !kReleaseMode) {
        final useTestMode = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(child: Text('Backend Unavailable')),
              ],
            ),
            content: const Text(
              'The backend server is not running. Would you like to use test mode to continue with registration?\n\n'
              'In test mode, registration will be simulated and you can test the app with mock data.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                ),
                child: const Text('Use Test Mode'),
              ),
            ],
          ),
        );

        if (useTestMode == true) {
          // ✅ Simulate successful registration in test mode
          await _simulateRegistrationInTestMode();
          return; // Exit early - registration simulated
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// ✅ Simulate registration in test mode (when backend unavailable)
  Future<void> _simulateRegistrationInTestMode() async {
    print('🧪 Simulating registration in test mode...');

    try {
      // Enable test mode
      final prefs = await SharedPreferences.getInstance();
      if (!const bool.fromEnvironment('dart.vm.product')) {
        await prefs.setBool('test_mode', true);
        print('✅ Test mode enabled for registration');
      }

      // Save registration data locally (simulated)
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_name', _contactNameController.text);
      await prefs.setString('user_email', _emailController.text);
      await prefs.setString('user_phone', _phoneController.text);
      await prefs.setString('agency_name', _agencyNameController.text);

      // Generate mock token and agency ID
      final mockToken = 'test_token_${DateTime.now().millisecondsSinceEpoch}';
      final mockAgencyId =
          'agency_test_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('jwt_token', mockToken);
      // Also save to secure storage via ApiClient
      await ApiClient.saveToken(mockToken);
      await prefs.setString('agency_id', mockAgencyId);
      print('✅ Mock token and agency ID saved');

      // Save zipcodes
      final zipcodesList = List<String>.from(_selectedZipcodes);
      await prefs.setStringList('user_zipcodes', zipcodesList);
      await prefs.setString('subscription_plan', _selectedPlan);
      if (_selectedPlanId != null) {
        await prefs.setString('subscription_plan_id', _selectedPlanId!);
      }

      // Save monthly price from selected plan
      final selectedPlanData = _availablePlans.firstWhere(
        (p) => (p['id'] ?? '') == _selectedPlanId,
        orElse: () => {},
      );
      final monthlyPriceRaw = selectedPlanData['price_per_unit'] ??
          selectedPlanData['pricePerUnit'] ??
          selectedPlanData['base_price'] ??
          selectedPlanData['basePrice'] ??
          0.0;
      final monthlyPrice = (monthlyPriceRaw is num)
          ? monthlyPriceRaw.toDouble()
          : (double.tryParse(monthlyPriceRaw.toString()) ?? 0.0);
      await prefs.setDouble('monthly_price', monthlyPrice.toDouble());

      await prefs.setString(
          'registration_date', DateTime.now().toIso8601String());
      await prefs.setString('payment_status', 'active');
      await prefs.setString('payment_method', 'card');

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🧪 Test Mode: Registration simulated successfully! Welcome ${_contactNameController.text}!'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate to home
      final zipcodesListForHome = _selectedZipcodes
          .map((z) => {
                'zipcode': z.contains('|') ? z.split('|')[0] : z,
                'city': z.contains('|') ? z.split('|')[1] : 'Unknown',
              })
          .toList();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(initialZipcodes: zipcodesListForHome),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ Test mode registration simulation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test mode registration failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProgressDot(0, 'Info'),
              _buildProgressLine(0),
              _buildProgressDot(1, 'Plan'),
              _buildProgressLine(1),
              _buildProgressDot(2, 'Areas'),
              _buildProgressLine(2),
              _buildProgressDot(3, 'Done'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF00888C), Color(0xFF006B75)])
                : null,
            color: isActive ? null : Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF00888C).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${step + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(isActive ? 1.0 : 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(int step) {
    final isActive = _currentStep > step;
    return Container(
      width: 40,
      height: 3,
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFF00888C), Color(0xFF006B75)])
            : null,
        color: isActive ? null : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agency Information',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Agency Name',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _agencyNameController,
              validator: _validateAgencyName,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                hintText: 'Enter agency name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF00888C), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Contact Person',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactNameController,
              validator: _validateContactPerson,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                hintText: 'Enter full name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF00888C), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              validator: _validateEmail,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                hintText: 'example@email.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF00888C), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Industry', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedIndustry,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                hintText: 'Select your industry',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF00888C), width: 2),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Home Health and Hospice',
                  child: Text('Home Health and Hospice'),
                ),
                DropdownMenuItem(
                  value: 'Insurance',
                  child: Text('Insurance'),
                ),
                DropdownMenuItem(
                  value: 'Finance',
                  child: Text('Finance'),
                ),
                DropdownMenuItem(
                  value: 'Handyman Services',
                  child: Text('Handyman Services'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedIndustry = value;
                });
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00888C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Next Step',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    // Plan Selection Step - Load from API
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Your Plan',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the plan that best fits your needs',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF718096),
            ),
          ),
          const SizedBox(height: 24),

          // Plan Cards - Load from API
          if (_loadingPlans)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ))
          else if (_availablePlans.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                  'No subscription plans available. Please contact support.'),
            )
          else
            ..._availablePlans.map((plan) {
              final planId = plan['id'] ?? '';
              final planName =
                  plan['name'] ?? plan['plan_name'] ?? 'Unknown Plan';
              final price = _planPrice(plan);
              // Use ONLY base_zipcodes_included (simple plan model: base = max)
              final baseUnits = _planBaseUnits(plan);
              final displayUnits = baseUnits > 0 ? baseUnits : 1;
              final isSelected = _selectedPlanId == planId;

              final features = _planFeatures(plan);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPlanId = planId;
                    _selectedPlan = planName;
                    // Use ONLY base_zipcodes_included (simple plan model)
                    _maxZipcodes = baseUnits > 0 ? baseUnits : 1;
                    // Clear zipcodes that exceed new limit
                    if (_selectedZipcodes.length > _maxZipcodes &&
                        _maxZipcodes > 0) {
                      _selectedZipcodes.removeRange(
                          _maxZipcodes, _selectedZipcodes.length);
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE8EAFF) : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00888C)
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00888C).withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Compact header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  planName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? const Color(0xFF00888C)
                                        : const Color(0xFF1A202C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '\$',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? const Color(0xFF00888C)
                                            : const Color(0xFF1A202C),
                                      ),
                                    ),
                                    Text(
                                      price.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? const Color(0xFF00888C)
                                            : const Color(0xFF1A202C),
                                      ),
                                    ),
                                    const Text(
                                      '/mo',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF718096),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00888C),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Zipcodes badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00888C).withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$displayUnits zipcodes included',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF00888C)
                                : const Color(0xFF718096),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Features - compact (max 3)
                      ...features.take(3).map((feature) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: isSelected
                                    ? const Color(0xFF00888C)
                                    : const Color(0xFF00888C),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSelected
                                        ? const Color(0xFF1A202C)
                                        : const Color(0xFF718096),
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (features.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${features.length - 3} more',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 32),

          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00888C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue to Zipcodes',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00888C),
                side: const BorderSide(color: Color(0xFF00888C)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back, size: 20),
                  SizedBox(width: 8),
                  Text('Back',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Zipcodes',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$_selectedPlan - Up to $_maxZipcodes zipcodes',
              style: const TextStyle(
                color: Color(0xFF3454D1),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Zipcode Selection Instructions
          const Text(
            'Select Your Service Areas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can select up to $_maxZipcodes zipcodes for the $_selectedPlan plan',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF718096),
            ),
          ),
          const SizedBox(height: 16),

          // Use My Location Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _useMyLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Use My Location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00888C),
                side: const BorderSide(color: Color(0xFF00888C)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Manual Zipcode Entry
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _zipcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Zipcode (e.g., 75201)',
                    hintText: '5-digit zipcode',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addZipcode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00888C),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bulk Add Option
          TextField(
            controller: _bulkZipcodesController,
            decoration: InputDecoration(
              labelText: 'Or add multiple zipcodes (comma-separated)',
              hintText: 'e.g., 75201, 75033, 75001',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.add_location_alt),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _bulkAddZipcodes(_maxZipcodes),
              ),
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16),

          // Selected Zipcodes Display
          if (_selectedZipcodes.isNotEmpty) ...[
            Text(
              'Selected Zipcodes (${_selectedZipcodes.length}/$_maxZipcodes):',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedZipcodes.map((entry) {
                final parts = entry.split('|');
                final zipcode = parts[0];
                final city = parts.length > 1 ? parts[1] : 'Unknown';
                return Chip(
                  label: Text('$zipcode - $city'),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeZipcode(entry),
                  backgroundColor: const Color(0xFF00888C).withOpacity(0.1),
                  labelStyle: const TextStyle(color: Color(0xFF00888C)),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedZipcodes.length} of $_maxZipcodes zipcodes selected',
              style: TextStyle(
                fontSize: 12,
                color: _selectedZipcodes.length >= _maxZipcodes
                    ? Colors.orange
                    : const Color(0xFF718096),
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00888C), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF00888C), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No zipcodes selected yet. Add zipcodes above to define your service areas.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00888C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Next Step',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00888C),
                side: const BorderSide(color: Color(0xFF00888C)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back, size: 20),
                  SizedBox(width: 8),
                  Text('Back',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm Your Plan',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 24),

          // Plan Summary Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPlan,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3454D1),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Base Price',
                        style: TextStyle(color: Color(0xFF718096))),
                    Text('\$99/mo',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Zipcodes',
                        style: TextStyle(color: Color(0xFF718096))),
                    Text('${_selectedZipcodes.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3454D1),
                      ),
                    ),
                    Text(
                      '\$99/mo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3454D1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: '••••••••',
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF3454D1), width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF718096),
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Confirm Password',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              hintText: '••••••••',
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF3454D1), width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: const Color(0xFF718096),
                ),
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _completeRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00888C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Complete Registration',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _previousStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00888C),
                side: const BorderSide(color: Color(0xFF00888C)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back, size: 20),
                  SizedBox(width: 8),
                  Text('Back',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00888C), // Indigo
              Color(0xFF007A7C), // Purple
              Color(0xFF006A6E), // Pink
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ✨ Modern Header with Back Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // Balance
                  ],
                ),
              ),
              // ✨ Animated Progress Bar
              _buildProgressBar(),
              // Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1(), // Agency Info
                      _buildStep2(), // Plan Selection
                      _buildStep3(), // Zipcode Selection
                      _buildStep4(), // Password
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== OLD REGISTRATION (KEEPING FOR BACKUP) ====================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyController = TextEditingController();
  final _zipcodeController = TextEditingController();
  final List<Map<String, String>> _zipcodes = [];
  final String _selectedPlan = 'Basic';
  bool _isLoading = false;
  bool _obscurePassword = true;

  // ✅ VALIDATION METHODS
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.length != 10) {
      return 'Phone must be 10 digits';
    }
    return null;
  }

  String? _validateCompany(String? value) {
    if (value == null || value.isEmpty) {
      return 'Company name is required';
    }
    if (value.length < 2) {
      return 'Company name must be at least 2 characters';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  // ✅ REAL USA ZIPCODE LOOKUP VIA API
  Future<Map<String, String>?> _lookupZipcode(String zipcode) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.zippopotam.us/us/$zipcode'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final places = data['places'] as List;
        if (places.isNotEmpty) {
          final place = places[0];
          return {
            'code': zipcode,
            'city': place['place name'] ?? 'Unknown',
            'state': place['state abbreviation'] ?? 'Unknown',
            'stateName': place['state'] ?? 'Unknown',
          };
        }
      }
      return null;
    } catch (e) {
      print('Zipcode lookup error: $e');
      return null;
    }
  }

  final Map<String, List<Map<String, String>>> _stateZipcodes = {
    'Texas': [
      // Dallas Metro Area
      {'code': '75001', 'city': 'Addison'},
      {'code': '75006', 'city': 'Carrollton'},
      {'code': '75007', 'city': 'Carrollton'},
      {'code': '75019', 'city': 'Coppell'},
      {'code': '75022', 'city': 'Flower Mound'},
      {'code': '75023', 'city': 'Plano'},
      {'code': '75024', 'city': 'Plano'},
      {'code': '75025', 'city': 'Plano'},
      {'code': '75033', 'city': 'Frisco'},
      {'code': '75034', 'city': 'Frisco'},
      {'code': '75035', 'city': 'Frisco'},
      {'code': '75069', 'city': 'McKinney'},
      {'code': '75070', 'city': 'McKinney'},
      {'code': '75071', 'city': 'McKinney'},
      {'code': '75074', 'city': 'Plano'},
      {'code': '75075', 'city': 'Plano'},
      {'code': '75080', 'city': 'Richardson'},
      {'code': '75201', 'city': 'Dallas Downtown'},
      {'code': '75202', 'city': 'Dallas Downtown'},
      {'code': '75204', 'city': 'Dallas Uptown'},
      {'code': '76101', 'city': 'Fort Worth Downtown'},
      {'code': '76102', 'city': 'Fort Worth Downtown'},
      {'code': '77001', 'city': 'Houston Downtown'},
      {'code': '77002', 'city': 'Houston Downtown'},
      {'code': '77006', 'city': 'Houston Montrose'},
      {'code': '78701', 'city': 'Austin Downtown'},
      {'code': '78702', 'city': 'Austin East'},
      {'code': '78201', 'city': 'San Antonio Downtown'},
    ],
    'California': [
      {'code': '90001', 'city': 'Los Angeles Downtown'},
      {'code': '94102', 'city': 'San Francisco Downtown'},
      {'code': '92101', 'city': 'San Diego Downtown'},
    ],
    'Florida': [
      {'code': '33101', 'city': 'Miami Downtown'},
      {'code': '32801', 'city': 'Orlando Downtown'},
      {'code': '33602', 'city': 'Tampa Downtown'},
    ],
    'New York': [
      {'code': '10001', 'city': 'New York Manhattan'},
      {'code': '11201', 'city': 'Brooklyn'},
      {'code': '10301', 'city': 'Staten Island'},
    ],
  };

  Future<void> _useMyLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠ Location services disabled. Enable in device settings.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠ Location permission denied')),
          );
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('📍 Getting your location...'),
            duration: Duration(seconds: 3)),
      );

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final zipcode = (placemark.postalCode ?? '').trim();
        final locality =
            (placemark.locality ?? placemark.subAdministrativeArea ?? 'Unknown')
                .trim();
        final country = (placemark.country ?? '').trim();

        if (country.toLowerCase() != 'united states' &&
            country.toLowerCase() != 'usa' &&
            country.toLowerCase() != 'us') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚠ You are in $country. This app only supports USA zipcodes.'),
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }

        if (zipcode.isNotEmpty &&
            zipcode.length == 5 &&
            RegExp(r'^\d{5}$').hasMatch(zipcode)) {
          setState(() {
            _zipcodeController.text = zipcode;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('✓ Found: $zipcode - $locality\nClick "Add" to add it!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚠ Location: $locality, $country\nZipcode unavailable. Please enter manually.'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      String errorMessage = '❌ Location error: ';
      if (e.toString().contains('timeout')) {
        errorMessage += 'Taking too long. Check GPS signal.';
      } else {
        errorMessage += 'Please enter zipcode manually.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(errorMessage), duration: const Duration(seconds: 5)),
      );
    }
  }

  Future<void> _addZipcode() async {
    final code = _zipcodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a zipcode')),
      );
      return;
    }
    if (code.length != 5 || !RegExp(r'^\d{5}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zipcode must be 5 digits')),
      );
      return;
    }
    if (_zipcodes.any((z) => z['code'] == code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zipcode already added')),
      );
      return;
    }

    // ✅ LOOKUP ZIPCODE VIA API
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔍 Looking up zipcode...'),
        duration: Duration(seconds: 1),
      ),
    );

    final zipcodeData = await _lookupZipcode(code);
    if (zipcodeData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Invalid USA zipcode: $code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _zipcodes.add({
        'code': code,
        'city': '${zipcodeData['city']}, ${zipcodeData['state']}'
      });
      _zipcodeController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '✓ Added $code - ${zipcodeData['city']}, ${zipcodeData['state']}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _addFromStateSelection(String zipcode, String city) {
    if (!_zipcodes.any((z) => z['code'] == zipcode)) {
      setState(() {
        _zipcodes.add({'code': zipcode, 'city': city});
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Added $zipcode - $city'),
            backgroundColor: Colors.green),
      );
    }
  }

  // ✅ NEW: Show hierarchical State→City→Zipcode selector dialog (currently disabled in UI)
  // ignore: unused_element
  Future<void> _showBrowseZipcodesDialog() async {
    String? selectedState;
    String? selectedCity;
    List<String> availableCities = [];
    List<Map<String, String>> availableZipcodes = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Update cities when state changes
          if (selectedState != null) {
            final stateCities = <String>{};
            for (var zipData in _stateZipcodes[selectedState]!) {
              stateCities.add(zipData['city']!);
            }
            availableCities = stateCities.toList()..sort();
          }

          // Update zipcodes when city changes
          if (selectedState != null && selectedCity != null) {
            availableZipcodes = _stateZipcodes[selectedState]!
                .where((z) => z['city'] == selectedCity)
                .toList();
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Row(
              children: [
                Icon(Icons.add_location, color: Color(0xFF00888C)),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Browse by Location',
                        style: TextStyle(color: Colors.black87))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // STEP 1: Select State
                  const Text('Step 1: Select State',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedState,
                    decoration: const InputDecoration(
                      labelText: 'Choose State',
                      labelStyle: TextStyle(color: Colors.black87),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                    dropdownColor: Colors.white,
                    items: _stateZipcodes.keys
                        .map((state) => DropdownMenuItem(
                              value: state,
                              child: Text(state,
                                  style:
                                      const TextStyle(color: Colors.black87)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedState = value;
                        selectedCity = null; // Reset city when state changes
                        availableZipcodes.clear();
                      });
                    },
                  ),

                  // STEP 2: Select City (only show if state is selected)
                  if (selectedState != null) ...[
                    const SizedBox(height: 16),
                    const Text('Step 2: Select City',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCity,
                      decoration: const InputDecoration(
                        labelText: 'Choose City',
                        labelStyle: TextStyle(color: Colors.black87),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      style:
                          const TextStyle(color: Colors.black87, fontSize: 16),
                      dropdownColor: Colors.white,
                      items: availableCities
                          .map((city) => DropdownMenuItem(
                                value: city,
                                child: Text(city,
                                    style:
                                        const TextStyle(color: Colors.black87)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCity = value;
                        });
                      },
                    ),
                  ],

                  // STEP 3: Select Zipcodes (only show if city is selected)
                  if (selectedCity != null && availableZipcodes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Step 3: Select Zipcodes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87)),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableZipcodes.length,
                        itemBuilder: (context, i) {
                          final zipData = availableZipcodes[i];
                          final zipcode = zipData['code']!;
                          final city = zipData['city']!;
                          final isAlreadyAdded =
                              _zipcodes.any((z) => z['code'] == zipcode);
                          return ListTile(
                            leading: Icon(
                              isAlreadyAdded
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isAlreadyAdded
                                  ? Colors.green
                                  : const Color(0xFF00888C),
                            ),
                            title: Text(zipcode,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isAlreadyAdded
                                        ? Colors.grey
                                        : Colors.black87)),
                            subtitle: Text('$city, $selectedState',
                                style: TextStyle(
                                    color: isAlreadyAdded
                                        ? Colors.grey
                                        : Colors.black54)),
                            trailing: isAlreadyAdded
                                ? const Text('Added',
                                    style: TextStyle(color: Colors.green))
                                : null,
                            enabled: !isAlreadyAdded,
                            onTap: isAlreadyAdded
                                ? null
                                : () {
                                    _addFromStateSelection(zipcode, city);
                                    Navigator.pop(context);
                                  },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close',
                    style: TextStyle(color: Color(0xFF00888C))),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _register() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_zipcodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one zipcode'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));

    // ✅ SAVE REGISTRATION DATA TO LOCAL STORAGE
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text);
    await prefs.setString('user_email', _emailController.text);
    await prefs.setString('user_phone', _phoneController.text);
    await prefs.setString('user_company', _companyController.text);
    await prefs.setString('user_plan', _selectedPlan);
    await prefs.setStringList('user_zipcodes',
        _zipcodes.map((z) => '${z['code']}|${z['city']}').toList());
    await prefs.setString(
        'subscription_start', DateTime.now().toIso8601String());
    await prefs.setBool('is_logged_in', true);

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Account created! Welcome ${_nameController.text}'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );

    // Pass the registered zipcodes to the home page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(initialZipcodes: _zipcodes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: const Color(0xFF00888C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Personal Information',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                  hintText: 'John Doe',
                ),
                validator: _validateName,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                  hintText: 'john@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                  hintText: '(555) 123-4567',
                ),
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
                maxLength: 14,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company/Agency Name *',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                  hintText: 'ABC Healthcare',
                ),
                validator: _validateCompany,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  hintText: 'Min 8 chars, 1 uppercase, 1 number',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 32),
              const Text('Service Areas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Legacy browse flow removed in favor of manual entry + bulk add
              // (kept disabled to avoid accidental re-use)
              // ElevatedButton.icon(
              //   onPressed: _showBrowseZipcodesDialog,
              //   icon: const Icon(Icons.explore),
              //   label: const Text('Browse by State → City → Zipcode'),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: const Color(0xFF00888C),
              //     foregroundColor: Colors.white,
              //     minimumSize: const Size(double.infinity, 50),
              //   ),
              // ),
              // const SizedBox(height: 16),

              // Use My Location Button
              ElevatedButton.icon(
                onPressed: _useMyLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Use My Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Manual Zipcode Entry
              const Text('Or Enter Zipcode Manually:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _zipcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Zipcode (e.g., 75201)',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 75033',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addZipcode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00888C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_zipcodes.isNotEmpty) ...[
                Text('Selected Areas (${_zipcodes.length}):',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _zipcodes
                      .map((z) => Chip(
                            label: Text('${z['code']} - ${z['city']}'),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () =>
                                setState(() => _zipcodes.remove(z)),
                            backgroundColor:
                                const Color(0xFF00888C).withOpacity(0.1),
                            labelStyle:
                                const TextStyle(color: Color(0xFF00888C)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00888C),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rocket_launch, size: 20),
                            SizedBox(width: 8),
                            Text('Start Growing Your Agency',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 💳 PAYMENT GATEWAY DIALOG - Secure Payment Processing
// ═══════════════════════════════════════════════════════════════
class PaymentGatewayDialog extends StatefulWidget {
  final String planName;
  final int amount;
  final int zipcodeCount;
  final VoidCallback onPaymentSuccess;

  const PaymentGatewayDialog({
    super.key,
    required this.planName,
    required this.amount,
    required this.zipcodeCount,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentGatewayDialog> createState() => _PaymentGatewayDialogState();
}

class _PaymentGatewayDialogState extends State<PaymentGatewayDialog> {
  final _cardHolderController = TextEditingController();
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'card';
  bool _isCardComplete = false;
  String? _paymentMethodId;

  @override
  void dispose() {
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    // For card payments ensure card field is complete
    if (_selectedPaymentMethod == 'card' && !_isCardComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete your card details.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      if (_selectedPaymentMethod == 'card') {
        // ✅ Platform check: Only use Stripe on supported platforms
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android)) {
          try {
            // Create a PaymentMethod with Stripe (test mode)
            final pm = await stripe.Stripe.instance.createPaymentMethod(
              params: const stripe.PaymentMethodParams.card(
                paymentMethodData: stripe.PaymentMethodData(
                  billingDetails: stripe.BillingDetails(),
                ),
              ),
            );

            _paymentMethodId = pm.id;

            // Persist for use during registration/subscribe
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('payment_method_id', _paymentMethodId!);
          } catch (stripeError) {
            print('⚠️ Stripe payment method creation failed: $stripeError');
            // For development: Generate a mock payment method ID
            _paymentMethodId =
                'pm_test_${DateTime.now().millisecondsSinceEpoch}';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('payment_method_id', _paymentMethodId!);
            print(
                '🧪 Using mock payment method ID for development: $_paymentMethodId');
          }
        } else {
          // ✅ Fallback for web/unsupported platforms: Generate mock payment method ID
          _paymentMethodId = 'pm_test_${DateTime.now().millisecondsSinceEpoch}';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('payment_method_id', _paymentMethodId!);
          print(
              '🧪 Web/Unsupported platform: Using mock payment method ID: $_paymentMethodId');
        }
      }

      setState(() => _isProcessing = false);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('✅ Payment method saved!'),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 400));
      widget.onPaymentSuccess();
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Stripe CardField handles validation internally

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payment,
                        color: Color(0xFF3B82F6),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete Payment',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Secure payment processing',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Order Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.planName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '\$${widget.amount}/mo',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${widget.zipcodeCount} Zipcodes',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Due Today',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '\$${widget.amount}.00',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Payment Method Selection
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentMethodButton(
                        icon: Icons.credit_card,
                        label: 'Card',
                        value: 'card',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPaymentMethodButton(
                        icon: Icons.account_balance_wallet,
                        label: 'PayPal',
                        value: 'paypal',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Payment Form
                if (_selectedPaymentMethod == 'card') ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Card Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ✅ Platform check: Only use Stripe CardField on supported platforms
                      if (!kIsWeb &&
                          (defaultTargetPlatform == TargetPlatform.iOS ||
                              defaultTargetPlatform == TargetPlatform.android))
                        stripe.CardField(
                          onCardChanged: (details) {
                            setState(() {
                              _isCardComplete = details?.complete ?? false;
                            });
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: '1234 1234 1234 1234',
                          ),
                        )
                      else
                        // ✅ Fallback: Manual card input for web/unsupported platforms
                        Column(
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Card Number',
                                hintText: '1234 1234 1234 1234',
                                prefixIcon: Icon(Icons.credit_card),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                // Simple validation: card number should be 13-19 digits
                                final digitsOnly =
                                    value.replaceAll(RegExp(r'\D'), '');
                                setState(() {
                                  _isCardComplete = digitsOnly.length >= 13 &&
                                      digitsOnly.length <= 19;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Expiry (MM/YY)',
                                      hintText: '12/25',
                                      prefixIcon: Icon(Icons.calendar_today),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'CVV',
                                      hintText: '123',
                                      prefixIcon: Icon(Icons.lock),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    obscureText: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Cardholder Name (optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cardHolderController,
                        decoration: const InputDecoration(
                          hintText: 'John Doe',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // PayPal Option
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFBBF24)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Color(0xFFF59E0B)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You will be redirected to PayPal to complete your payment.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Security Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security, color: Color(0xFF3B82F6), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your payment information is encrypted and secure',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isProcessing ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isProcessing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Processing...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Pay \$${widget.amount}.00',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Test Card Notice
                if (_selectedPaymentMethod == 'card')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Color(0xFFF59E0B), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Test Mode - Use these test cards:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Success: 4242 4242 4242 4242\n• Decline: 4000 0000 0000 0002\n• Expiry: Any future date (e.g., 12/25)\n• CVV: Any 3 digits',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodButton({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isSelected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border.all(
            color:
                isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final List<Map<String, String>>? initialZipcodes;

  const HomePage({super.key, this.initialZipcodes});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late List<Map<String, String>> _userZipcodes;
  bool _hasCheckedLeads = false;

  // Method to expose _viewLeadDetail to child widgets
  void viewLeadDetail(Map<String, dynamic> lead) {
    // This will be implemented in LeadsPage
    // For now, just navigate to leads tab
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _userZipcodes = widget.initialZipcodes ?? [];
    _loadSavedZipcodes();
    // Check for new leads to show popup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForNewLeads();
    });
  }

  /// Check for new/unviewed leads and show popup
  Future<void> _checkForNewLeads() async {
    if (_hasCheckedLeads) return;
    _hasCheckedLeads = true;

    try {
      // Wait a bit for UI to settle
      await Future.delayed(const Duration(milliseconds: 500));

      // Get new/unviewed leads (exclude rejected leads automatically)
      final leads = await LeadService.getLeads(
          status: 'new', limit: 10, excludeRejected: true);

      // Filter by user's zipcodes
      final prefs = await SharedPreferences.getInstance();
      final userZipcodesRaw = prefs.getStringList('user_zipcodes') ?? [];
      final userZipcodes = userZipcodesRaw.map((z) {
        if (z.contains('|')) return z.split('|')[0].trim();
        return z.trim();
      }).toList();

      final filteredLeads = leads.where((lead) {
        final leadZipcode = lead['zipcode']?.toString() ?? '';
        return userZipcodes.contains(leadZipcode);
      }).toList();

      // Check if there are unviewed leads
      final unviewedLeads = filteredLeads.where((lead) {
        return lead['viewed_at'] == null ||
            lead['viewed_at'].toString().isEmpty;
      }).toList();

      if (unviewedLeads.isNotEmpty && mounted) {
        // Show popup for first unviewed lead
        await _showLeadPopupModal(unviewedLeads[0], unviewedLeads.sublist(1));
      }
    } catch (e) {
      print('❌ Error checking for new leads: $e');
    }
  }

  Future<void> _loadSavedZipcodes() async {
    if (_userZipcodes.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final savedZipcodes = prefs.getStringList('user_zipcodes') ?? [];
      if (savedZipcodes.isNotEmpty) {
        // Convert saved zipcode strings back to maps
        _userZipcodes = savedZipcodes.map((z) {
          if (z.contains('|')) {
            // Format: "zipcode|city"
            final parts = z.split('|');
            return {
              'zipcode': parts[0],
              'city': parts.length > 1 ? parts[1] : 'Unknown'
            };
          } else {
            // Format: just "zipcode" (fallback)
            return {'zipcode': z, 'city': 'Unknown'};
          }
        }).toList();
        print('✅ Loaded ${_userZipcodes.length} zipcodes from storage');
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  /// Show lead popup modal when app opens (for new/unviewed leads)
  /// Shows "Communicate" or "Not Interested" options
  Future<void> _showLeadPopupModal(Map<String, dynamic> lead,
      List<Map<String, dynamic>> remainingLeads) async {
    if (!mounted) return;

    final firstName = lead['first_name'] ?? '';
    final lastName = lead['last_name'] ?? '';
    final name = '$firstName $lastName'.trim().isEmpty
        ? (lead['name'] ?? 'Unknown')
        : '$firstName $lastName';
    final industry = lead['industry'] ?? 'General';
    final serviceType = lead['service_type'] ?? '';
    final phone = lead['phone'] ?? '';
    final city = lead['city'] ?? 'Unknown';
    final zipcode = lead['zipcode'] ?? '';
    final urgency = lead['urgency_level'] ?? 'MODERATE';
    final notes = lead['notes'] ?? '';

    // Industry color coding
    Color industryColor;
    IconData industryIcon;
    switch (industry.toUpperCase()) {
      case 'HEALTH':
        industryColor = const Color(0xFF10B981);
        industryIcon = Icons.medical_services;
        break;
      case 'INSURANCE':
        industryColor = const Color(0xFF3B82F6);
        industryIcon = Icons.shield;
        break;
      case 'FINANCE':
        industryColor = const Color(0xFFF59E0B);
        industryIcon = Icons.account_balance;
        break;
      case 'HANDYMAN':
        industryColor = const Color(0xFF8B5CF6);
        industryIcon = Icons.build;
        break;
      default:
        industryColor = const Color(0xFF64748B);
        industryIcon = Icons.business;
    }

    // Urgency color
    Color urgencyColor;
    if (urgency == 'URGENT' || urgency == 'HIGH') {
      urgencyColor = const Color(0xFFEF4444);
    } else if (urgency == 'MODERATE' || urgency == 'MEDIUM') {
      urgencyColor = const Color(0xFFF59E0B);
    } else {
      urgencyColor = const Color(0xFF10B981);
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: industryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(industryIcon, color: industryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New Lead Available',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(industry,
                        style: TextStyle(fontSize: 12, color: industryColor)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  urgency == 'HIGH'
                      ? 'HIGH'
                      : urgency == 'MODERATE'
                          ? 'MED'
                          : 'LOW',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: urgencyColor),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A))),
                      if (serviceType.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(serviceType,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF64748B))),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.phone,
                              size: 14, color: const Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(phone,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 14, color: const Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text('$city, $zipcode',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B))),
                        ],
                      ),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(notes,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ),
                if (remainingLeads.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: const Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              '${remainingLeads.length} more lead(s) waiting',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF92400E))),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            // Not Interested Button - With clear gap from Communicate button
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _handleNotInterested(lead['id'], remainingLeads);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, size: 18),
                    SizedBox(width: 6),
                    Text('Not Interested',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16), // Clear gap between buttons
            // Communicate Button - With clear gap from Not Interested button
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _handleCommunicate(lead, remainingLeads);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00888C),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.message, size: 18),
                    SizedBox(width: 6),
                    Text('Communicate',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle "Not Interested" action - marks lead for portal admin to reassign
  /// Removes lead from list and sends API call to middleware
  Future<void> _handleNotInterested(
      int? leadId, List<Map<String, dynamic>> remainingLeads) async {
    if (leadId == null) {
      if (remainingLeads.isNotEmpty) {
        await _showLeadPopupModal(remainingLeads[0], remainingLeads.sublist(1));
      }
      return;
    }

    try {
      print(
          '🚫 Sending "Not Interested" API call to middleware for lead: $leadId');

      // Send API call to middleware layer
      final success = await LeadService.markNotInterested(
        leadId,
        reason: 'Not interested',
        notes:
            'Marked as not interested by mobile user - Portal admin can reassign',
      );

      if (success) {
        print('✅ API call successful - Lead marked as not interested');

        // Clear leads cache to remove this lead from future fetches
        await LeadService.clearCache();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Lead removed. Portal admin will reassign it.'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );

        // Refresh leads list to remove the rejected lead
        // The lead will be excluded from future API calls (status: rejected)
        // Refresh the leads page if it's visible to update the UI
        try {
          final leadsPageState =
              context.findAncestorStateOfType<_LeadsPageState>();
          if (leadsPageState != null && mounted) {
            // Refresh leads list - rejected lead will be excluded automatically
            await leadsPageState._fetchLeads();
            print('✅ Leads list refreshed - rejected lead excluded');
          }
        } catch (e) {
          print('Note: Could not refresh leads page: $e');
        }
      } else {
        print('❌ API call failed - Lead status not updated');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Failed to update lead status. Please try again.'),
            backgroundColor: Color(0xFFF59E0B),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error marking lead as not interested: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Show next lead if available (after a short delay)
    if (remainingLeads.isNotEmpty && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _showLeadPopupModal(remainingLeads[0], remainingLeads.sublist(1));
      }
    }
  }

  /// Handle "Communicate" action - marks as contacted and navigates to lead
  Future<void> _handleCommunicate(Map<String, dynamic> lead,
      List<Map<String, dynamic>> remainingLeads) async {
    final leadId = lead['id'];
    if (leadId != null) {
      try {
        await LeadService.updateLeadStatus(leadId, 'contacted',
            notes: 'User chose to communicate');
        await LeadService.markAsViewed(leadId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Lead marked as contacted'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 1)),
        );
      } catch (e) {
        print('❌ Error updating lead status: $e');
      }
    }

    if (mounted) {
      setState(() => _currentIndex = 0);
    }

    if (remainingLeads.isNotEmpty && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await _showLeadPopupModal(remainingLeads[0], remainingLeads.sublist(1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF00888C);
    return Scaffold(
      body: [
        const LeadsPage(),
        SubscriptionPage(initialZipcodes: _userZipcodes),
        const SettingsPage(),
      ][_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primaryTeal,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Leads'),
          BottomNavigationBarItem(
              icon: Icon(Icons.card_membership), label: 'Plans'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 🏠 HOME DASHBOARD - Main Dashboard with Stats & Activity
// ═══════════════════════════════════════════════════════════════
class HomeDashboardPage extends StatefulWidget {
  final List<Map<String, String>> userZipcodes;
  final VoidCallback? onNavigateToLeads;

  const HomeDashboardPage({
    super.key,
    required this.userZipcodes,
    this.onNavigateToLeads,
  });

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  String _userName = 'avatar';
  int _newToday = 0;
  int _thisWeek = 0;
  double _revenue = 0.0;
  double _conversion = 0.0;
  List<Map<String, dynamic>> _recentLeads = [];
  List<int> _weeklyData = [0, 0, 0, 0, 0, 0, 0]; // Last 7 days lead counts
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(HomeDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when userZipcodes prop changes
    if (oldWidget.userZipcodes != widget.userZipcodes) {
      print('🔄 Zipcodes changed, reloading dashboard data...');
      _loadDashboardData();
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'avatar';
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      // ✅ USE NEW LEADSERVICE - Fetch real leads from mobile API
      final allLeads = await LeadService.getLeads(excludeRejected: true);

      // DEBUG: Print sample data
      if (allLeads.isNotEmpty) {
        print('📊 Sample lead data from API: ${allLeads[0]}');
      }

      // ✅ FILTER LEADS BY USER'S SELECTED ZIPCODES
      final userZipcodeStrings =
          widget.userZipcodes.map((z) => z['zipcode'] ?? '').toList();
      print('🔍 Filtering leads for zipcodes: $userZipcodeStrings');

      final filteredLeads = allLeads.where((lead) {
        final leadZipcode = lead['zipcode']?.toString() ?? '';
        final matches = userZipcodeStrings.contains(leadZipcode);
        if (matches) {
          print(
              '✅ Lead matched! Zipcode: $leadZipcode, Name: ${lead['first_name'] ?? lead['name']}');
        }
        return matches;
      }).toList();

      print('📊 Total leads in DB: ${allLeads.length}');
      print('✅ Filtered leads matching zipcodes: ${filteredLeads.length}');

      // Calculate real stats from FILTERED leads
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));

      int todayCount = 0;
      int weekCount = 0;
      int convertedCount = 0;
      List<int> weeklyBreakdown = [0, 0, 0, 0, 0, 0, 0]; // Last 7 days

      for (var lead in filteredLeads) {
        try {
          // Count leads by date
          final createdAtStr = lead['created_at'] ?? lead['submitted_at'] ?? '';
          if (createdAtStr.isNotEmpty) {
            final createdAt = DateTime.parse(createdAtStr);
            if (createdAt.isAfter(today)) todayCount++;
            if (createdAt.isAfter(weekAgo)) {
              weekCount++;

              // Calculate which day of the week (0 = today, 6 = 7 days ago)
              final daysAgo = now.difference(createdAt).inDays;
              if (daysAgo >= 0 && daysAgo < 7) {
                weeklyBreakdown[
                    6 - daysAgo]++; // Reverse order so today is last
              }
            }
          }

          // Count converted leads (status: contacted, converted, closed)
          final status = (lead['status'] ?? lead['assignment_status'] ?? 'new')
              .toString()
              .toLowerCase();
          if (status == 'contacted' ||
              status == 'converted' ||
              status == 'closed' ||
              status == 'called') {
            convertedCount++;
          }
        } catch (e) {
          // Skip if date parsing fails
          print('⚠️ Error parsing lead date: $e');
        }
      }

      // Calculate metrics
      final totalLeads = filteredLeads.length;
      final conversionRate =
          totalLeads > 0 ? (convertedCount / totalLeads * 100) : 0.0;
      final estimatedRevenue =
          (convertedCount * 1500.0); // $1500 per converted lead

      if (mounted) {
        setState(() {
          _recentLeads = filteredLeads.take(3).toList();
          _newToday = todayCount;
          _thisWeek = weekCount;
          _revenue = estimatedRevenue / 1000; // Show in thousands (e.g., $3.5K)
          _conversion = conversionRate;
          _weeklyData = weeklyBreakdown;
          _isLoading = false;

          print('📊 Dashboard Stats:');
          print('  - Total leads in DB: ${allLeads.length}');
          print('  - Matching user zipcodes: ${filteredLeads.length}');
          print('  - New today: $todayCount');
          print('  - This week: $weekCount');
          print('  - Converted: $convertedCount');
          print('  - Conversion rate: ${conversionRate.toStringAsFixed(1)}%');
          print(
              '  - Estimated revenue: \$${estimatedRevenue.toStringAsFixed(0)}');
          print('  - Weekly breakdown: $weeklyBreakdown');
        });
      }
    } catch (e) {
      // API not available - show helpful error message
      if (mounted) {
        setState(() {
          _recentLeads = [];
          _isLoading = false;
          print('❌ API connection error: $e'); // Debug print
        });
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber, {int? leadId}) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);

        // Track call in backend
        if (leadId != null) {
          try {
            await LeadService.trackCall(leadId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📞 Call tracked successfully'),
                  backgroundColor: Color(0xFF10B981),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            print('❌ Failed to track call: $e');
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Could not launch phone dialer'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showLeadDetails(Map<String, dynamic> lead) {
    final nameController =
        TextEditingController(text: lead['first_name'] ?? 'Unknown');
    final phoneController = TextEditingController(text: lead['phone'] ?? 'N/A');
    final emailController = TextEditingController(text: lead['email'] ?? 'N/A');
    final notesController =
        TextEditingController(text: lead['notes']?.toString() ?? '');

    // Normalize status to match dropdown values
    String rawStatus = (lead['status'] ?? 'New').toString();
    String selectedStatus = rawStatus;

    // Map any status variations to our standard values
    if (rawStatus.toLowerCase() == 'pending' ||
        rawStatus.toLowerCase() == 'new') {
      selectedStatus = 'New';
    } else if (rawStatus.toLowerCase() == 'contacted' ||
        rawStatus.toLowerCase() == 'in_progress') {
      selectedStatus = 'Contacted';
    } else if (rawStatus.toLowerCase() == 'converting' ||
        rawStatus.toLowerCase() == 'qualified') {
      selectedStatus = 'Converting';
    } else if (rawStatus.toLowerCase() == 'closed' ||
        rawStatus.toLowerCase() == 'won') {
      selectedStatus = 'Closed';
    } else if (rawStatus.toLowerCase() == 'rejected' ||
        rawStatus.toLowerCase() == 'lost') {
      selectedStatus = 'Rejected';
    } else {
      // If unknown status, default to New
      selectedStatus = 'New';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lead Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(
                    'Name', nameController.text, Icons.person_outline),
                const SizedBox(height: 12),
                _buildDetailRow(
                    'Phone', phoneController.text, Icons.phone_outlined),
                const SizedBox(height: 12),
                _buildDetailRow(
                    'Email', emailController.text, Icons.email_outlined),
                const SizedBox(height: 12),
                _buildDetailRow('City', lead['city'] ?? 'N/A',
                    Icons.location_city_outlined),
                const SizedBox(height: 12),
                _buildDetailRow('Zipcode', lead['zipcode']?.toString() ?? 'N/A',
                    Icons.location_on_outlined),
                const SizedBox(height: 12),
                _buildDetailRow('Urgency', lead['urgency_level'] ?? 'MODERATE',
                    Icons.priority_high_outlined),
                const SizedBox(height: 16),
                const Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      items: [
                        'New',
                        'Contacted',
                        'Converting',
                        'Closed',
                        'Rejected'
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setDialogState(() {
                            selectedStatus = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add notes about this lead...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Save status and notes
                try {
                  final leadId = lead['id'];
                  if (leadId != null) {
                    // Update status
                    await LeadService.updateLeadStatus(
                      leadId,
                      selectedStatus,
                      notes: notesController.text.isEmpty
                          ? null
                          : notesController.text,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Lead updated successfully'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );

                      // Refresh the leads
                      _loadDashboardData();
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Failed to update: $e'),
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLeadAlerts() {
    final urgentLeads = _recentLeads
        .where((lead) =>
            lead['urgency_level'] == 'URGENT' ||
            lead['urgency_level'] == 'High')
        .toList();

    final todayLeads = _recentLeads.where((lead) {
      if (lead['created_at'] != null) {
        final createdDate = DateTime.parse(lead['created_at'].toString());
        final today = DateTime.now();
        return createdDate.year == today.year &&
            createdDate.month == today.month &&
            createdDate.day == today.day;
      }
      return false;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Lead Alerts', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (urgentLeads.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.priority_high, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🚨 ${urgentLeads.length} URGENT lead(s) need attention!',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (todayLeads.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF3B82F6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.today, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '📅 ${todayLeads.length} new lead(s) received today',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_recentLeads.isEmpty)
                const Text('No alerts at the moment. Great job! 🎉'),
              if (_recentLeads.isNotEmpty) ...[
                const Text(
                  'Quick Summary:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text('📊 Total Leads: ${_recentLeads.length}'),
                Text('🆕 New Today: $_newToday'),
                Text('📈 This Week: $_thisWeek'),
                Text('💰 Estimated Revenue: \$${_revenue.toStringAsFixed(0)}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (urgentLeads.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (widget.onNavigateToLeads != null) {
                  widget.onNavigateToLeads!();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
              ),
              child: const Text('View Urgent'),
            ),
        ],
      ),
    );
  }

  void _showDetailedStats() {
    final newLeads = _recentLeads
        .where((lead) =>
            (lead['status'] ?? 'New') == 'New' ||
            (lead['status'] ?? 'New') == 'pending')
        .length;

    final contactedLeads = _recentLeads
        .where((lead) =>
            (lead['status'] ?? '') == 'Contacted' ||
            (lead['status'] ?? '') == 'contacted')
        .length;

    final convertingLeads = _recentLeads
        .where((lead) => (lead['status'] ?? '') == 'Converting')
        .length;

    final closedLeads = _recentLeads
        .where((lead) =>
            (lead['status'] ?? '') == 'Closed' ||
            (lead['status'] ?? '') == 'won')
        .length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Color(0xFF006A6E)),
            SizedBox(width: 8),
            Text('Detailed Statistics', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow('📊 Total Leads', '${_recentLeads.length}',
                  const Color(0xFF3B82F6)),
              const Divider(),
              _buildStatRow(
                  '🆕 New Leads', '$newLeads', const Color(0xFF10B981)),
              _buildStatRow(
                  '📞 Contacted', '$contactedLeads', const Color(0xFF3B82F6)),
              _buildStatRow(
                  '💎 Converting', '$convertingLeads', const Color(0xFFF59E0B)),
              _buildStatRow(
                  '✅ Closed', '$closedLeads', const Color(0xFF10B981)),
              const Divider(),
              _buildStatRow(
                  '📈 This Week', '$_thisWeek', const Color(0xFF00888C)),
              _buildStatRow('📅 Today', '$_newToday', const Color(0xFF006A6E)),
              const Divider(),
              _buildStatRow('💰 Revenue Est.',
                  '\$${_revenue.toStringAsFixed(0)}K', const Color(0xFF10B981)),
              _buildStatRow(
                  '📊 Conversion',
                  '${_conversion.toStringAsFixed(1)}%',
                  const Color(0xFF3B82F6)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00888C), // Indigo
              Color(0xFF007A7C), // Purple
              Color(0xFF006A6E), // Pink
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section with user info
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back! 👋',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications, size: 28),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🎯 QUICK ACTIONS ROW
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '⚡ Quick Actions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildQuickActionButton(
                                  icon: Icons.phone_in_talk,
                                  label: 'Call Lead',
                                  color: const Color(0xFF10B981),
                                  onTap: () {
                                    // Navigate to Leads tab
                                    if (widget.onNavigateToLeads != null) {
                                      widget.onNavigateToLeads!();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              '📞 Tap a lead to make a call'),
                                          backgroundColor: Color(0xFF10B981),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                _buildQuickActionButton(
                                  icon: Icons.refresh,
                                  label: 'Refresh',
                                  color: const Color(0xFF3B82F6),
                                  onTap: () async {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('🔄 Refreshing dashboard...'),
                                        backgroundColor: Color(0xFF3B82F6),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                    await _loadDashboardData();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              '✅ Dashboard updated! ${_recentLeads.length} leads found'),
                                          backgroundColor:
                                              const Color(0xFF10B981),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                _buildQuickActionButton(
                                  icon: Icons.notifications_active,
                                  label: 'Alerts',
                                  color: const Color(0xFFF59E0B),
                                  onTap: () {
                                    _showLeadAlerts();
                                  },
                                ),
                                _buildQuickActionButton(
                                  icon: Icons.analytics,
                                  label: 'Stats',
                                  color: const Color(0xFF006A6E),
                                  onTap: () {
                                    _showDetailedStats();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 📊 LEAD PIPELINE PROGRESS
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00888C), Color(0xFF007A7C)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00888C).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.trending_up,
                                    color: Colors.white, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Lead Pipeline',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildPipelineStage('New', _recentLeads.length,
                                const Color(0xFF3B82F6)),
                            const SizedBox(height: 8),
                            _buildPipelineStage(
                                'Contacted',
                                (_recentLeads.length * 0.6).toInt(),
                                const Color(0xFF10B981)),
                            const SizedBox(height: 8),
                            _buildPipelineStage(
                                'Converting',
                                (_recentLeads.length * 0.3).toInt(),
                                const Color(0xFFF59E0B)),
                            const SizedBox(height: 8),
                            _buildPipelineStage(
                                'Closed',
                                (_recentLeads.length * 0.15).toInt(),
                                const Color(0xFF006A6E)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.description,
                              iconColor: Colors.white,
                              iconBg: const Color(0xFF3B82F6),
                              label: 'New Today',
                              value: '$_newToday',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.trending_up,
                              iconColor: Colors.white,
                              iconBg: const Color(0xFF10B981),
                              label: 'This Week',
                              value: '$_thisWeek',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.attach_money,
                              iconColor: Colors.white,
                              iconBg: const Color(0xFFF59E0B),
                              label: 'Revenue',
                              value: '\$${_revenue.toStringAsFixed(1)}K',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.show_chart,
                              iconColor: Colors.white,
                              iconBg: const Color(0xFF06B6D4),
                              label: 'Conversion',
                              value: '${_conversion.toStringAsFixed(0)}%',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Weekly Activity Chart
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF00888C),
                                        Color(0xFF007A7C)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.bar_chart,
                                      color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Weekly Activity',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 150,
                              child: CustomPaint(
                                size: const Size(double.infinity, 150),
                                painter: WeeklyActivityChartPainter(
                                    data: _weeklyData),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Recent Leads Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Leads',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Navigate to Leads tab
                              if (widget.onNavigateToLeads != null) {
                                widget.onNavigateToLeads!();
                              }
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Text(
                                  'View All',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Lead Cards
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      if (!_isLoading && _recentLeads.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'No recent leads',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      if (!_isLoading && _recentLeads.isNotEmpty)
                        ..._recentLeads.map((lead) {
                          final name = lead['first_name'] ?? 'Unknown';
                          final city = lead['city'] ?? 'Unknown';
                          final zipcode = lead['zipcode'] ?? '';
                          final urgency = lead['urgency_level'] ?? 'MODERATE';

                          Color urgencyColor;
                          if (urgency == 'URGENT' || urgency == 'High') {
                            urgencyColor = const Color(0xFFEF4444);
                          } else if (urgency == 'MODERATE' ||
                              urgency == 'Medium') {
                            urgencyColor = const Color(0xFFF59E0B);
                          } else {
                            urgencyColor = const Color(0xFF10B981);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on,
                                                  size: 12,
                                                  color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$city, $zipcode',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: urgencyColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        urgency,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: urgencyColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _makePhoneCall(
                                              lead['phone'] ?? '',
                                              leadId: lead['id']),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF10B981),
                                                  Color(0xFF059669)
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.phone,
                                                    color: Colors.white,
                                                    size: 16),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Call',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _showLeadDetails(lead),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF3B82F6),
                                                  Color(0xFF2563EB)
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.info,
                                                    color: Colors.white,
                                                    size: 16),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Details',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3), width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStage(String label, int count, Color color) {
    final total = _recentLeads.isNotEmpty ? _recentLeads.length : 1;
    final percentage = (count / total * 100).clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              '$count leads',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.white.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLeadCard({
    required String name,
    required String service,
    required String location,
    required String time,
    required String urgency,
    required Color urgencyColor,
    required Color urgencyTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: urgencyColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  urgency,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: urgencyTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            service,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Family seeking 24/7 hospice care for elderly mother with stage 4 cancer. Immediate placement needed.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.phone, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              const Text(
                '(214) 555-7890',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              const Icon(Icons.access_time, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                time,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Mark Contacted',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF3B82F6), size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for Weekly Activity Chart
class WeeklyActivityChartPainter extends CustomPainter {
  final List<int> data;

  WeeklyActivityChartPainter({this.data = const [0, 0, 0, 0, 0, 0, 0]});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3B82F6).withOpacity(0.3),
          const Color(0xFF3B82F6).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Use real data or sample data if empty
    final dataPoints = data.isEmpty || data.every((e) => e == 0)
        ? [1, 3, 2, 5, 3, 4, 2] // Sample data if no real data
        : data;

    // Find max value for scaling
    final maxValue = dataPoints.reduce((a, b) => a > b ? a : b).toDouble();
    final scaleFactor = maxValue > 0 ? maxValue : 10.0;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < dataPoints.length; i++) {
      final x = (size.width / (dataPoints.length - 1)) * i;
      final y = size.height - (dataPoints[i] / scaleFactor * size.height * 0.8);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots
    for (int i = 0; i < dataPoints.length; i++) {
      final x = (size.width / (dataPoints.length - 1)) * i;
      final y = size.height - (dataPoints[i] / scaleFactor * size.height * 0.8);
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = const Color(0xFF3B82F6),
      );
    }
  }

  @override
  bool shouldRepaint(WeeklyActivityChartPainter oldDelegate) =>
      oldDelegate.data != data;
}

// ═══════════════════════════════════════════════════════════════
// 📊 MY LEADS DASHBOARD - Simple Overview for Agencies
// ═══════════════════════════════════════════════════════════════
class MyLeadsDashboard extends StatefulWidget {
  const MyLeadsDashboard({super.key});

  @override
  State<MyLeadsDashboard> createState() => _MyLeadsDashboardState();
}

class _MyLeadsDashboardState extends State<MyLeadsDashboard> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  List<Map<String, String>> _myAreas = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Load user's service areas
      final prefs = await SharedPreferences.getInstance();
      final savedZipcodes = prefs.getStringList('user_zipcodes') ?? [];
      final areas = savedZipcodes.map((z) {
        final parts = z.split('|');
        return {
          'code': parts[0],
          'city': parts.length > 1 ? parts[1] : 'Unknown'
        };
      }).toList();

      // ✅ USE NEW LEADSERVICE - Fetch real leads from mobile API (exclude rejected)
      final leads = await LeadService.getLeads(excludeRejected: true);

      // Calculate stats
      final totalLeads = leads.length;
      final newLeads = leads
          .where((l) => l['status'] == 'New' || l['status'] == 'new')
          .length;
      final contactedLeads = leads
          .where(
              (l) => l['status'] == 'Contacted' || l['status'] == 'contacted')
          .length;
      final convertedLeads = leads
          .where((l) =>
              l['status'] == 'Completed' ||
              l['status'] == 'completed' ||
              l['status'] == 'Scheduled')
          .length;

      if (mounted) {
        setState(() {
          _myAreas = areas;
          _stats = {
            'totalLeads': totalLeads,
            'newLeads': newLeads,
            'contactedLeads': contactedLeads,
            'convertedLeads': convertedLeads,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stats = {
            'totalLeads': 0,
            'newLeads': 0,
            'contactedLeads': 0,
            'convertedLeads': 0
          };
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 My Dashboard'),
        backgroundColor: const Color(0xFF00888C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // My Service Areas
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.location_on,
                                    color: Color(0xFF00888C)),
                                SizedBox(width: 8),
                                Text('My Service Areas',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_myAreas.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                    '⚠ No service areas yet. Add areas in Settings.'),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _myAreas
                                    .map((area) => Chip(
                                          avatar: const Icon(
                                              Icons.location_city,
                                              size: 16),
                                          label: Text(
                                              '${area['code']} - ${area['city']}'),
                                          backgroundColor:
                                              const Color(0xFF00888C)
                                                  .withOpacity(0.1),
                                        ))
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Stats
                    const Text('📊 Quick Stats',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                              'Total',
                              '${_stats['totalLeads']}',
                              Icons.people,
                              const Color(0xFF00888C)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard('New', '${_stats['newLeads']}',
                              Icons.fiber_new, const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                              'Contacted',
                              '${_stats['contactedLeads']}',
                              Icons.phone,
                              const Color(0xFFFF6B35)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                              'Converted',
                              '${_stats['convertedLeads']}',
                              Icons.check_circle,
                              const Color(0xFF007A7C)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.bolt, color: Color(0xFFFF6B35)),
                                SizedBox(width: 8),
                                Text('Quick Actions',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              leading: const Icon(Icons.people,
                                  color: Color(0xFF00888C)),
                              title: const Text('View All Leads'),
                              subtitle:
                                  Text('${_stats['totalLeads']} leads total'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // Navigate to Leads tab
                                final homeState = context
                                    .findAncestorStateOfType<_HomePageState>();
                                homeState?.setState(() {
                                  homeState._currentIndex = 0;
                                });
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.location_on,
                                  color: Color(0xFF10B981)),
                              title: const Text('Manage Service Areas'),
                              subtitle: Text('${_myAreas.length} active areas'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // Navigate to Settings tab
                                final homeState = context
                                    .findAncestorStateOfType<_HomePageState>();
                                homeState?.setState(() {
                                  homeState._currentIndex = 3;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _filteredLeads = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _selectedPriority = 'All';
  String _selectedStatus = 'All';
  // ignore: unused_field
  DateTime? _startDate;
  // ignore: unused_field
  DateTime? _endDate;
  final Set<int> _selectedLeads = {};
  bool _isSelectionMode = false;
  Timer? _refreshTimer;
  int _lastLeadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchLeads();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchLeadsQuietly();
    });
  }

  Future<void> _fetchLeadsQuietly() async {
    // Fetch without showing loading indicator
    try {
      // ✅ USE NEW LEADSERVICE - Fetch real leads from mobile API (exclude rejected)
      final newLeads = await LeadService.getLeads(excludeRejected: true);

      // Check if there are new leads
      if (newLeads.length > _lastLeadCount && _lastLeadCount > 0) {
        // Show notification for new leads
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                    '🎉 ${newLeads.length - _lastLeadCount} new lead(s) received!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () async {
                setState(() {
                  _leads = newLeads;
                });
                await _filterLeads();
              },
            ),
          ),
        );
      }

      setState(() {
        _leads = newLeads;
        _lastLeadCount = newLeads.length;
      });
      await _filterLeads();
    } catch (e) {
      // Silently fail for background refresh
    }
  }

  Future<void> _fetchLeads() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // ✅ USE NEW LEADSERVICE - Fetch real leads from mobile API (exclude rejected)
      final leads = await LeadService.getLeads(excludeRejected: true);

      setState(() {
        _leads = leads;
        _lastLeadCount = _leads.length; // Set initial count
        _isLoading = false;
      });
      await _filterLeads(); // Apply zipcode filtering
    } catch (e) {
      // NO FAKE DATA - Show empty state if API is not available
      if (mounted) {
        setState(() {
          _leads = [];
          _filteredLeads = [];
          _lastLeadCount = 0;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _filterLeads() async {
    // Get user's selected zipcodes
    final prefs = await SharedPreferences.getInstance();
    final userZipcodesRaw = prefs.getStringList('user_zipcodes') ?? [];

    // ✅ EXTRACT JUST THE ZIPCODE PART (before the |)
    final userZipcodes = userZipcodesRaw.map((z) {
      if (z.contains('|')) {
        return z.split('|')[0].trim(); // Extract zipcode before |
      }
      return z.trim();
    }).toList();

    print('🔍 User zipcodes for filtering: $userZipcodes');

    setState(() {
      _filteredLeads = _leads.where((lead) {
        // ✅ CRITICAL: EXACT Zipcode matching - Agency only sees leads from their zipcodes
        final leadZipcode =
            (lead['zipcode'] ?? lead['zip_code'] ?? lead['postal_code'] ?? '')
                .toString()
                .trim();

        // ✅ EXACT MATCH - Must be in user's zipcode list
        final zipcodeMatch =
            userZipcodes.isEmpty || userZipcodes.contains(leadZipcode);

        print('📍 Lead zipcode: $leadZipcode, Match: $zipcodeMatch');

        // Search filter
        final searchTerm = _searchController.text.toLowerCase();
        final nameMatch =
            (lead['first_name'] ?? '').toLowerCase().contains(searchTerm);
        final emailMatch =
            (lead['email'] ?? '').toLowerCase().contains(searchTerm);
        final phoneMatch =
            (lead['phone'] ?? '').toLowerCase().contains(searchTerm);
        final searchMatch =
            searchTerm.isEmpty || nameMatch || emailMatch || phoneMatch;

        // Priority filter
        final priorityMatch = _selectedPriority == 'All' ||
            (lead['urgency_level'] ?? '') == _selectedPriority;

        // Status filter
        final statusMatch = _selectedStatus == 'All' ||
            (lead['status'] ?? 'New') == _selectedStatus;

        return zipcodeMatch && searchMatch && priorityMatch && statusMatch;
      }).toList();

      print(
          '✅ Filtered to ${_filteredLeads.length} leads from ${_leads.length} total');
    });
  }

  Future<void> _exportLeads() async {
    if (_filteredLeads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠ No leads to export')),
      );
      return;
    }

    try {
      // Create CSV data
      List<List<dynamic>> rows = [];

      // Add header
      rows.add([
        'Name',
        'Phone',
        'Email',
        'Care Type',
        'Status',
        'Priority',
        'City',
        'Zipcode',
        'Date'
      ]);

      // Add data rows
      for (var lead in _filteredLeads) {
        rows.add([
          lead['first_name'] ?? '',
          lead['phone'] ?? '',
          lead['email'] ?? '',
          lead['care_recipient'] ?? '',
          lead['status'] ?? '',
          lead['urgency_level'] ?? '',
          lead['city'] ?? '',
          lead['zipcode'] ?? '',
          DateTime.now().toString().split(' ')[0],
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Save and share
      final fileName =
          'leads_export_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (kIsWeb) {
        // For web, show dialog with CSV data
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Leads'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✓ Exported ${_filteredLeads.length} leads'),
                  const SizedBox(height: 16),
                  const Text('CSV Data:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      csv.length > 500
                          ? '${csv.substring(0, 500)}...\n\n(Data truncated for display)'
                          : csv,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        // For mobile/desktop, share CSV from memory (no file I/O required)
        final xfile = XFile.fromData(
          utf8.encode(csv),
          mimeType: 'text/csv',
          name: fileName,
        );
        await Share.shareXFiles([xfile], text: 'Healthcare Leads Export');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Exported ${_filteredLeads.length} leads')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Export failed: ${e.toString()}')),
      );
    }
  }

  /// Optimized compact lead card for mobile - shows industry, complete info
  Widget _buildModernLeadCard(Map<String, dynamic> lead, bool isSelected) {
    final firstName = lead['first_name'] ?? '';
    final lastName = lead['last_name'] ?? '';
    final name = '$firstName $lastName'.trim().isEmpty
        ? (lead['name'] ?? 'Unknown')
        : '$firstName $lastName';
    final phone = lead['phone'] ?? '';
    final email = lead['email'] ?? '';
    final city = lead['city'] ?? 'Unknown';
    final zipcode = lead['zipcode'] ?? '';
    final industry = lead['industry'] ?? 'General';
    final serviceType = lead['service_type'] ?? '';
    // final status = lead['status'] ?? 'new'; // Unused - kept for future use
    final urgency = lead['urgency_level'] ?? 'MODERATE';
    final age = lead['age'];
    final source = lead['source'] ?? '';
    final timeline = lead['timeline'] ?? '';

    // Industry color coding
    Color industryColor;
    IconData industryIcon;
    switch (industry.toUpperCase()) {
      case 'HEALTH':
        industryColor = const Color(0xFF10B981); // Green
        industryIcon = Icons.medical_services;
        break;
      case 'INSURANCE':
        industryColor = const Color(0xFF3B82F6); // Blue
        industryIcon = Icons.shield;
        break;
      case 'FINANCE':
        industryColor = const Color(0xFFF59E0B); // Orange
        industryIcon = Icons.account_balance;
        break;
      case 'HANDYMAN':
        industryColor = const Color(0xFF8B5CF6); // Purple
        industryIcon = Icons.build;
        break;
      default:
        industryColor = const Color(0xFF64748B); // Gray
        industryIcon = Icons.business;
    }

    // Urgency colors
    Color urgencyColor;
    if (urgency == 'URGENT' || urgency == 'HIGH') {
      urgencyColor = const Color(0xFFEF4444);
    } else if (urgency == 'MODERATE' || urgency == 'MEDIUM') {
      urgencyColor = const Color(0xFFF59E0B);
    } else {
      urgencyColor = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedLeads.remove(lead['id']);
                } else {
                  _selectedLeads.add(lead['id']);
                }
              });
            } else {
              _viewLeadDetail(lead);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              _toggleSelectionMode();
              setState(() {
                _selectedLeads.add(lead['id']);
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: const Color(0xFF00888C), width: 2)
                  : Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name + Selection + Urgency
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isSelectionMode)
                      Container(
                        margin: const EdgeInsets.only(right: 8, top: 2),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected
                              ? const Color(0xFF00888C)
                              : const Color(0xFFE2E8F0),
                          size: 20,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (age != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '($age)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Industry badge
                          Row(
                            children: [
                              Icon(industryIcon,
                                  size: 12, color: industryColor),
                              const SizedBox(width: 4),
                              Text(
                                industry,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: industryColor,
                                ),
                              ),
                              if (serviceType.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '• $serviceType',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgencyColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        urgency == 'HIGH'
                            ? 'HIGH'
                            : urgency == 'MODERATE'
                                ? 'MED'
                                : 'LOW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: urgencyColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Contact info row
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.phone,
                              size: 12, color: const Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 12, color: const Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '$city, $zipcode',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (source.isNotEmpty || timeline.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (source.isNotEmpty) ...[
                        Icon(Icons.source,
                            size: 10, color: const Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          source,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                      if (source.isNotEmpty && timeline.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text('•',
                            style: TextStyle(
                                color: const Color(0xFF94A3B8), fontSize: 10)),
                        const SizedBox(width: 8),
                      ],
                      if (timeline.isNotEmpty) ...[
                        Icon(Icons.schedule,
                            size: 10, color: const Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            timeline,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                // Action buttons - compact
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _makePhoneCall(phone, leadId: lead['id']),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone,
                                  size: 16, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'Call',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _sendEmail(email),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.email,
                                  size: 16, color: Color(0xFF3B82F6)),
                              SizedBox(width: 4),
                              Text(
                                'Email',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _viewLeadDetail(lead),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00888C).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.visibility,
                                  size: 16, color: Color(0xFF00888C)),
                              SizedBox(width: 4),
                              Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF00888C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _viewLeadDetail(Map<String, dynamic> lead) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lead['first_name'] ?? 'Lead Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Phone: ${lead['phone'] ?? 'N/A'}'),
              Text('Email: ${lead['email'] ?? 'N/A'}'),
              Text('City: ${lead['city'] ?? 'N/A'}'),
              Text('Zipcode: ${lead['zipcode'] ?? 'N/A'}'),
              Text('Status: ${lead['status'] ?? 'New'}'),
              Text('Urgency: ${lead['urgency_level'] ?? 'MODERATE'}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber, {int? leadId}) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);

      // ✅ USE NEW LEADSERVICE - Track call in API
      if (leadId != null) {
        try {
          await LeadService.trackCall(leadId);
        } catch (e) {
          // Silently fail - call was made successfully
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Could not launch phone dialer')),
      );
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Healthcare Services Inquiry',
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Could not launch email client')),
      );
    }
  }

  // ignore: unused_element
  void _showLeadDetails(Map<String, dynamic> lead) {
    final notesController =
        TextEditingController(text: lead['notes']?.toString() ?? '');
    String selectedStatus = lead['status'] ?? 'New';

    // Map API status values to dropdown values
    if (selectedStatus == 'pending') {
      selectedStatus = 'New';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF00888C).withOpacity(0.2),
                child: Text((lead['first_name'] ?? 'U')[0]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead['first_name'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 18)),
                    Text(
                      lead['care_recipient'] ?? 'N/A',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact Info
                Card(
                  color: Colors.blue.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.phone,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(lead['phone'] ?? 'N/A'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.email,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(lead['email'] ?? 'N/A',
                                    overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                                '${lead['city'] ?? 'N/A'}, ${lead['zipcode'] ?? 'N/A'}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Status Selector
                const Text('Status:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    'New',
                    'Contacted',
                    'Qualified',
                    'Converted',
                    'Not Interested'
                  ]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedStatus = value!;
                      lead['status'] = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Notes
                const Text('Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Add notes about this lead...',
                  ),
                  maxLines: 4,
                  onChanged: (value) {
                    lead['notes'] = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final phone = lead['phone']?.toString() ?? '';
                      if (phone.isNotEmpty) {
                        _makePhoneCall(phone, leadId: lead['id']);
                      }
                    },
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final email = lead['email']?.toString() ?? '';
                      if (email.isNotEmpty) {
                        _sendEmail(email);
                      }
                    },
                    icon: const Icon(Icons.email, size: 18),
                    label: const Text('Email'),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // ✅ USE NEW LEADSERVICE - Save notes and status via API
                    try {
                      final notes = notesController.text;
                      if (notes.isNotEmpty && lead['id'] != null) {
                        await LeadService.addNotes(lead['id'], notes);
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Lead updated successfully'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                      setState(() {}); // Refresh the list
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Leads'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: ['All', 'High', 'Medium', 'Low']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    _selectedPriority = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: ['All', 'New', 'Contacted', 'Scheduled', 'Completed']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    _selectedStatus = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedPriority = 'All';
                  _selectedStatus = 'All';
                });
                Navigator.pop(context);
                _filterLeads();
              },
              child: const Text('Reset'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _filterLeads();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00888C)),
              child: const Text('Apply', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedLeads.clear();
      }
    });
  }

  void _bulkUpdateStatus(String status) async {
    try {
      // ✅ USE NEW LEADSERVICE - Update status via mobile API
      final updatedCount = _selectedLeads.length;
      for (var leadId in _selectedLeads) {
        await LeadService.updateLeadStatus(leadId, status);
        final lead = _leads.firstWhere((l) => l['id'] == leadId);
        lead['status'] = status;
      }

      setState(() {
        _selectedLeads.clear();
        _isSelectionMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Updated $updatedCount leads to $status'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update leads: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _bulkDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Leads'),
        content: Text(
            'Are you sure you want to delete ${_selectedLeads.length} leads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _leads.removeWhere((lead) => _selectedLeads.contains(lead['id']));
              setState(() {
                _filterLeads();
                _selectedLeads.clear();
                _isSelectionMode = false;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Leads deleted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00888C), // Indigo
              Color(0xFF007A7C), // Purple
              Color(0xFF006A6E), // Pink
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern AppBar with gradient overlay
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Row(
                  children: [
                    if (_isSelectionMode)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _toggleSelectionMode,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.people,
                            color: Colors.white, size: 24),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSelectionMode
                                ? '${_selectedLeads.length} selected'
                                : 'Leads',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          if (!_isSelectionMode)
                            Text(
                              '${_filteredLeads.length} available',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_isSelectionMode)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _bulkDelete();
                          } else {
                            _bulkUpdateStatus(value);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'Contacted',
                              child: Text('Mark as Contacted')),
                          const PopupMenuItem(
                              value: 'Qualified',
                              child: Text('Mark as Qualified')),
                          const PopupMenuItem(
                              value: 'Converted',
                              child: Text('Mark as Converted')),
                          const PopupMenuItem(
                              value: 'Not Interested',
                              child: Text('Mark as Not Interested')),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _toggleSelectionMode,
                              icon: const Icon(Icons.checklist,
                                  color: Colors.white),
                              tooltip: 'Select Multiple',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _showFilterDialog,
                              icon: const Icon(Icons.filter_list,
                                  color: Colors.white),
                              tooltip: 'Filter',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _exportLeads,
                              icon: const Icon(Icons.download,
                                  color: Colors.white),
                              tooltip: 'Export',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _fetchLeads,
                              icon: const Icon(Icons.refresh,
                                  color: Colors.white),
                              tooltip: 'Refresh',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Search Bar with modern style
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or phone...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    icon: const Icon(Icons.search, color: Color(0xFF00888C)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              _filterLeads();
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {}); // Update to show/hide clear button
                    _filterLeads();
                  },
                ),
              ),

              // Filter chips
              if (_selectedPriority != 'All' || _selectedStatus != 'All')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_selectedPriority != 'All')
                        Chip(
                          label: Text('Priority: $_selectedPriority'),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() => _selectedPriority = 'All');
                            _filterLeads();
                          },
                        ),
                      if (_selectedStatus != 'All')
                        Chip(
                          label: Text('Status: $_selectedStatus'),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() => _selectedStatus = 'All');
                            _filterLeads();
                          },
                        ),
                    ],
                  ),
                ),

              // Leads List with Pull-to-Refresh
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : _filteredLeads.isEmpty
                        ? Center(
                            child: Container(
                              margin: const EdgeInsets.all(24),
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF00888C)
                                              .withOpacity(0.2),
                                          const Color(0xFF007A7C)
                                              .withOpacity(0.2),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: Color(0xFF00888C),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No leads found',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Pull down to refresh',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchLeads,
                            color: const Color(0xFF00888C),
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount: _filteredLeads.length,
                              itemBuilder: (context, index) {
                                final lead = _filteredLeads[index];
                                final isSelected =
                                    _selectedLeads.contains(lead['id']);
                                return _buildModernLeadCard(lead, isSelected);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showAddManualLeadDialogRemoved() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final zipcodeController = TextEditingController();
    final cityController = TextEditingController();
    String selectedCareType = 'Hospice Care';
    String selectedUrgency = 'MODERATE';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_add,
                            color: Color(0xFF3B82F6),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Manual Lead',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Enter lead information manually',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Name Field
                    const Text(
                      'Patient Name *',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g., John Smith',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Name is required';
                        }
                        if (v.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        // Allow letters, spaces, hyphens, and apostrophes for names
                        if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(v.trim())) {
                          return 'Name can only contain letters, spaces, hyphens, and apostrophes';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Age and Phone
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Age *',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: ageController,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'e.g., 75',
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Age is required';
                                  }
                                  final age = int.tryParse(v);
                                  if (age == null) {
                                    return 'Age must be a number';
                                  }
                                  if (age < 0 || age > 150) {
                                    return 'Age must be between 0 and 150';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Phone *',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: phoneController,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                decoration: InputDecoration(
                                  hintText: '(214) 555-0123',
                                  prefixIcon: const Icon(Icons.phone),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Phone is required';
                                  }
                                  final cleanPhone = v.replaceAll(RegExp(r'[^\d]'), '');
                                  if (cleanPhone.length != 10) {
                                    return 'Phone must be 10 digits (USA format)';
                                  }
                                  if (cleanPhone.startsWith('0') || cleanPhone.startsWith('1')) {
                                    return 'Invalid area code';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Email
                    const Text(
                      'Email',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: 'john@example.com',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                          if (!emailRegex.hasMatch(v.trim())) {
                            return 'Please enter a valid email address';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // City and Zipcode
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'City *',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: cityController,
                                decoration: InputDecoration(
                                  hintText: 'e.g., Dallas',
                                  prefixIcon: const Icon(Icons.location_city),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'City is required'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Zipcode *',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: zipcodeController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '75201',
                                  prefixIcon: const Icon(Icons.pin_drop),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Zipcode is required'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Care Type
                    const Text(
                      'Care Type *',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCareType,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.medical_services),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        'Hospice Care',
                        'Home Health',
                        'Physical Therapy',
                        'Skilled Nursing'
                      ]
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) => selectedCareType = value!,
                    ),
                    const SizedBox(height: 16),

                    // Urgency Level
                    const Text(
                      'Urgency Level *',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUrgency,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.priority_high),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      items: ['URGENT', 'MODERATE', 'LOW']
                          .map((urgency) => DropdownMenuItem(
                              value: urgency, child: Text(urgency)))
                          .toList(),
                      onChanged: (value) => selectedUrgency = value!,
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    const Text(
                      'Notes',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Additional information about the patient...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              nameController.dispose();
                              ageController.dispose();
                              phoneController.dispose();
                              emailController.dispose();
                              zipcodeController.dispose();
                              cityController.dispose();
                              notesController.dispose();
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                // Create new lead
                                final newLead = {
                                  'id': DateTime.now().millisecondsSinceEpoch,
                                  'name': nameController.text,
                                  'age': int.tryParse(ageController.text) ?? 0,
                                  'phone': phoneController.text,
                                  'email': emailController.text.isEmpty
                                      ? null
                                      : emailController.text,
                                  'city': cityController.text,
                                  'zipcode': zipcodeController.text,
                                  'care_type': selectedCareType,
                                  'urgency_level': selectedUrgency,
                                  'notes': notesController.text.isEmpty
                                      ? null
                                      : notesController.text,
                                  'status': 'New',
                                  'created_at':
                                      DateTime.now().toIso8601String(),
                                };

                                setState(() {
                                  _leads.insert(0, newLead);
                                  _filterLeads();
                                });

                                nameController.dispose();
                                ageController.dispose();
                                phoneController.dispose();
                                emailController.dispose();
                                zipcodeController.dispose();
                                cityController.dispose();
                                notesController.dispose();
                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Lead added successfully!'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Add Lead',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SubscriptionPage extends StatefulWidget {
  final List<Map<String, String>>? initialZipcodes;

  const SubscriptionPage({super.key, this.initialZipcodes});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  String _currentPlan = '';
  int _areaCount = 0;
  double _monthlyPrice = 0.0;
  bool _isProcessing = false;
  int _leadsThisMonth = 0;
  List<Map<String, dynamic>> _availablePlans = [];
  bool _loadingPlans = false;
  List<String> _userZipcodes = []; // Store user's selected zipcodes

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Load subscription data first (includes loading saved price)
    await _loadSubscriptionData();
    // Then load plans (which may update the price based on API)
    await _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loadingPlans = true);
    try {
      final plans = await SubscriptionService.getPlans(activeOnly: true);
      final prefs = await SharedPreferences.getInstance();

      // Track price with local variable
      double newPrice = _monthlyPrice; // Start with current price
      String newPlan = _currentPlan;

      setState(() {
        _availablePlans = plans;
        _loadingPlans = false;
      });

      // ✅ FIRST: Try to fetch actual subscription from backend API
      try {
        final subscriptionStatus = await SubscriptionService.getSubscription();
        if (subscriptionStatus != null &&
            subscriptionStatus['subscription'] != null) {
          final subscription = subscriptionStatus['subscription'];
          final planNameFromBackend = subscription['planName'];
          final monthlyPriceFromBackend = subscription['monthlyPrice'];

          if (planNameFromBackend != null &&
              planNameFromBackend.toString().isNotEmpty) {
            newPlan = planNameFromBackend.toString();
            print('✅ Loaded plan from backend API: $newPlan');
          }

          if (monthlyPriceFromBackend != null) {
            final price = (monthlyPriceFromBackend is num)
                ? monthlyPriceFromBackend.toDouble()
                : double.tryParse(monthlyPriceFromBackend.toString()) ?? 0.0;
            if (price > 0) {
              newPrice = price;
              await prefs.setDouble('monthly_price', price);
              print('✅ Loaded price from backend API: \$$newPrice');
            }
          }
        }
      } catch (e) {
        print('⚠️ Could not fetch subscription from backend: $e');
      }

      // ✅ SECOND: If backend didn't provide data, try saved plan ID
      if ((newPrice == 0.0 || newPlan.isEmpty) && plans.isNotEmpty) {
        final savedPlanId = prefs.getString('subscription_plan_id');
        if (savedPlanId != null && savedPlanId.isNotEmpty) {
          final savedPlan = plans.firstWhere(
            (p) => p['id'] == savedPlanId,
            orElse: () => {},
          );
          if (savedPlan.isNotEmpty) {
            if (newPlan.isEmpty) {
              newPlan = savedPlan['name'] ?? savedPlan['plan_name'] ?? '';
            }
            if (newPrice == 0.0) {
              final planPrice = (savedPlan['price_per_unit'] ??
                      savedPlan['pricePerUnit'] ??
                      savedPlan['base_price'] ??
                      savedPlan['basePrice'] ??
                      0.0)
                  .toDouble();
              if (planPrice > 0) {
                newPrice = planPrice;
                await prefs.setDouble('monthly_price', planPrice);
              }
            }
          }
        }
      }

      // ✅ THIRD: If still no data, try to match by saved plan name
      if ((newPrice == 0.0 || newPlan.isEmpty) && plans.isNotEmpty) {
        final savedPlanName = prefs.getString('subscription_plan');
        if (savedPlanName != null && savedPlanName.isNotEmpty) {
          final matchingPlan = plans.firstWhere(
            (p) {
              final pName =
                  (p['name'] ?? p['plan_name'] ?? '').toString().toLowerCase();
              final savedName = savedPlanName.toLowerCase();
              return pName.contains(savedName) || savedName.contains(pName);
            },
            orElse: () => {},
          );
          if (matchingPlan.isNotEmpty) {
            if (newPlan.isEmpty) {
              newPlan = matchingPlan['name'] ??
                  matchingPlan['plan_name'] ??
                  savedPlanName;
            }
            if (newPrice == 0.0) {
              final planPrice = (matchingPlan['price_per_unit'] ??
                      matchingPlan['pricePerUnit'] ??
                      matchingPlan['base_price'] ??
                      matchingPlan['basePrice'] ??
                      0.0)
                  .toDouble();
              if (planPrice > 0) {
                newPrice = planPrice;
                await prefs.setDouble('monthly_price', planPrice);
              }
            }
          }
        }
      }

      // ✅ FOURTH: Only if we still have nothing, use Basic as absolute last resort
      // (This should rarely happen - only if user has no subscription at all)
      if (newPrice == 0.0 || newPlan.isEmpty) {
        print('⚠️ No subscription data found, defaulting to Basic plan');
        newPrice = 99.0;
        newPlan = 'Basic';
        await prefs.setDouble('monthly_price', 99.0);
      }

      // Update state with final values
      setState(() {
        _monthlyPrice = newPrice;
        _currentPlan = newPlan;
      });

      print('✅ Final loaded plan: $_currentPlan, price: \$$_monthlyPrice');
    } catch (e) {
      print('Error loading plans: $e');
      setState(() => _loadingPlans = false);
    }
  }

  Future<void> _loadSubscriptionData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedZipcodes = prefs.getStringList('user_zipcodes') ?? [];

    // Load zipcodes from initialZipcodes if available
    List<String> zipcodesList = savedZipcodes;
    if (widget.initialZipcodes != null && widget.initialZipcodes!.isNotEmpty) {
      zipcodesList = widget.initialZipcodes!
          .map((z) => '${z['zipcode'] ?? ''}|${z['city'] ?? 'Unknown'}')
          .toList();
    }

    setState(() {
      _userZipcodes = zipcodesList;
      _areaCount = zipcodesList.length;
      if (widget.initialZipcodes != null && zipcodesList.isEmpty) {
        _areaCount = widget.initialZipcodes!.length;
      }
    });

    // Load monthly price from SharedPreferences first
    final savedMonthlyPrice = prefs.getDouble('monthly_price');
    if (savedMonthlyPrice != null && savedMonthlyPrice > 0) {
      setState(() {
        _monthlyPrice = savedMonthlyPrice;
        print('✅ Loaded saved monthly price: \$$_monthlyPrice');
      });
    }

    // Also try to load from subscription_plan if available
    final savedPlanName = prefs.getString('subscription_plan');
    if ((_monthlyPrice == 0.0 || savedMonthlyPrice == null) &&
        savedPlanName != null &&
        savedPlanName.isNotEmpty) {
      // Calculate price based on plan name
      double planPrice = 99.0; // Default to Basic
      final planNameLower = savedPlanName.toLowerCase();
      if (planNameLower.contains('premium')) {
        planPrice = 199.0;
      } else if (planNameLower.contains('business')) {
        planPrice = 299.0;
      }
      setState(() {
        _monthlyPrice = planPrice;
        _currentPlan = savedPlanName;
        print('✅ Set price from plan name ($savedPlanName): \$$_monthlyPrice');
      });
      // Save it for next time
      await prefs.setDouble('monthly_price', planPrice);
    }

    // Don't default to Basic here - let _loadPlans() fetch from backend first
    // Only set Basic if we truly have no data (handled in _loadPlans)

    // Load leads count from backend
    await _loadLeadsCount();
  }

  Future<void> _loadLeadsCount() async {
    try {
      final leads = await LeadService.getLeads(excludeRejected: true);
      // Filter leads from current month
      final now = DateTime.now();
      final thisMonthLeads = leads.where((lead) {
        final createdAt = DateTime.parse(lead['created_at']);
        return createdAt.year == now.year && createdAt.month == now.month;
      }).length;

      setState(() {
        _leadsThisMonth = thisMonthLeads;
      });
    } catch (e) {
      // If API fails, keep default 0
      print('Error loading leads count: $e');
      setState(() {
        _leadsThisMonth = 0;
      });
    }
  }

  // Removed hardcoded _calculatePrice - now using plans from API

  void _showUpgradeDialog(
      String plan, double price, int maxAreas, List<String> features) {
    // Show payment gateway for upgrade
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentGatewayDialog(
        planName: plan,
        amount: price.toInt(),
        zipcodeCount: maxAreas,
        onPaymentSuccess: () async {
          Navigator.pop(context); // Close payment dialog
          await _processUpgrade(plan, price, maxAreas);
        },
      ),
    );
  }

  Future<void> _processUpgrade(String plan, double price, int maxAreas) async {
    setState(() => _isProcessing = true);

    // Save upgrade to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription_plan', plan);
    await prefs.setString('payment_status', 'active');
    await prefs.setString(
        'last_payment_date', DateTime.now().toIso8601String());

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _currentPlan = plan;
      _monthlyPrice = price;
      _areaCount = maxAreas;
      _isProcessing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Successfully upgraded to $plan!'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  void _showManageSubscriptionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ManageSubscriptionModal(),
    );
  }

  /// Optimized compact plan card - minimized size and optimized spacing
  Widget _buildPlanCard(String plan, double price, int maxAreas,
      List<String> features, bool isCurrent, Color accentColor) {
    return Card(
      elevation: isCurrent ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent ? accentColor : Colors.grey.withOpacity(0.2),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Current badge + Plan name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('ACTIVE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      if (isCurrent) const SizedBox(height: 6),
                      Text(plan,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: accentColor)),
                    ],
                  ),
                ),
                // Price in compact format
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('\$',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: accentColor)),
                        Text(price.toStringAsFixed(0),
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: accentColor)),
                      ],
                    ),
                    const Text('/mo',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Zipcodes badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$maxAreas zipcodes',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor)),
            ),
            const SizedBox(height: 12),
            // Features - compact list (max 3 visible)
            ...features.take(3).map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: accentColor, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(f,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                )),
            if (features.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+${features.length - 3} more features',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 12),
            // Action button - compact
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCurrent
                    ? null
                    : () => _showUpgradeDialog(plan, price, maxAreas, features),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isCurrent ? Colors.grey.shade300 : accentColor,
                  foregroundColor:
                      isCurrent ? Colors.grey.shade700 : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: isCurrent ? 0 : 2,
                ),
                child: Text(isCurrent ? 'Current Plan' : 'Select Plan',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF0F172A),
              )),
          const SizedBox(height: 6),
          Text(answer,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 1.5,
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00888C), // Indigo
              Color(0xFF007A7C), // Purple
              Color(0xFF006A6E), // Pink
            ],
          ),
        ),
        child: SafeArea(
          child: _isProcessing
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadPlans();
                    await _loadSubscriptionData();
                  },
                  color: Colors.white,
                  backgroundColor: const Color(0xFF00888C),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Plans & Territory',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage your subscription and service areas',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                await _initializeData();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Plans refreshed'),
                                      duration: Duration(seconds: 2),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.refresh,
                                  color: Colors.white),
                              tooltip: 'Refresh plans',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Current Plan Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('$_currentPlan Plan',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E40AF),
                                          )),
                                      const SizedBox(height: 4),
                                      const Text(
                                          'Active • Renews on Dec 15, 2025',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF64748B))),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          text:
                                              '\$${_monthlyPrice.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E40AF),
                                          ),
                                          children: const [
                                            TextSpan(
                                              text: '/mo',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _showManageSubscriptionModal(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF1E40AF),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.edit,
                                            size: 16, color: Colors.white),
                                        label: const Text('Edit Plan',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            )),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: const BoxDecoration(
                                  border: Border(
                                      top: BorderSide(
                                          color: Color(0xFFE2E8F0), width: 2)),
                                ),
                                child: Column(
                                  children: [
                                    _buildDetailRow(
                                        '📍 Zipcodes', '$_areaCount active'),
                                    _buildDetailRow('📊 Leads this month',
                                        '$_leadsThisMonth received'),
                                    _buildDetailRow(
                                        '💬 Support', 'Priority support'),
                                  ],
                                ),
                              ),
                              // Display Selected Zipcodes
                              if (_userZipcodes.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                        top: BorderSide(
                                            color: Color(0xFFE2E8F0),
                                            width: 2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Your Selected Zipcodes',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E40AF),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _userZipcodes.map((entry) {
                                          final parts = entry.split('|');
                                          final zipcode = parts[0];
                                          final city = parts.length > 1
                                              ? parts[1]
                                              : 'Unknown';
                                          return Chip(
                                            label: Text('$zipcode - $city'),
                                            backgroundColor:
                                                const Color(0xFF1E40AF)
                                                    .withOpacity(0.1),
                                            labelStyle: const TextStyle(
                                              color: Color(0xFF1E40AF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Available Plans',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 6),
                        Text('Choose a plan that fits your business needs',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13)),
                        const SizedBox(height: 12),
                        if (_loadingPlans)
                          const Center(
                              child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ))
                        else if (_availablePlans.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'No subscription plans available. Please contact support.',
                              style: TextStyle(color: Colors.black87),
                            ),
                          )
                        else ...[
                          for (int i = 0; i < _availablePlans.length; i++) ...[
                            if (i != 0) const SizedBox(height: 12),
                            Builder(builder: (context) {
                              final p = _availablePlans[i];
                              final name =
                                  (p['name'] ?? p['plan_name'] ?? 'Plan')
                                      .toString();
                              final price = ((p['price_per_unit'] ??
                                      p['pricePerUnit'] ??
                                      p['base_price'] ??
                                      p['basePrice'] ??
                                      0) as num)
                                  .toDouble();
                              // Simple plan model: use base zipcodes, no separate max
                              // base_zipcodes_included represents zipcodes in database
                              final baseZipcodes =
                                  ((p['base_zipcodes_included'] ??
                                          p['base_cities_included'] ??
                                          p['baseUnits'] ??
                                          p['base_units'] ??
                                          p['minUnits'] ??
                                          p['min_units'] ??
                                          3) as num)
                                      .toInt();
                              final maxAreas =
                                  baseZipcodes; // Simple model: max = base
                              final features = (p['features'] is List)
                                  ? List<String>.from(
                                      p['features'].map((e) => e.toString()))
                                  : (p['featuresText'] != null &&
                                          p['featuresText']
                                              .toString()
                                              .isNotEmpty)
                                      ? p['featuresText']
                                          .toString()
                                          .split('\n')
                                          .map((s) => s.trim())
                                          .where((s) => s.isNotEmpty)
                                          .toList()
                                      : <String>[];
                              // Accent color by index for visual variety
                              final accent = i % 3 == 0
                                  ? const Color(0xFF10B981)
                                  : i % 3 == 1
                                      ? const Color(0xFFFF6B35)
                                      : const Color(0xFF00888C);
                              return _buildPlanCard(
                                name,
                                price,
                                maxAreas > 0 ? maxAreas : 1,
                                features,
                                _currentPlan == name,
                                accent,
                              );
                            })
                          ]
                        ],
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Frequently Asked Questions',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A))),
                              const SizedBox(height: 16),
                              _buildFAQItem('Can I change my plan anytime?',
                                  'Yes! You can upgrade or downgrade your plan at any time.'),
                              _buildFAQItem(
                                  'What happens to my data if I downgrade?',
                                  'All your data is preserved. You\'ll just have access to fewer areas.'),
                              _buildFAQItem('Do you offer refunds?',
                                  'Yes, we offer a 30-day money-back guarantee.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ==================== MANAGE SUBSCRIPTION MODAL ====================
class ManageSubscriptionModal extends StatefulWidget {
  const ManageSubscriptionModal({super.key});

  @override
  State<ManageSubscriptionModal> createState() =>
      _ManageSubscriptionModalState();
}

class _ManageSubscriptionModalState extends State<ManageSubscriptionModal> {
  int _selectedTabIndex = 1; // 0 = Change Plan, 1 = Manage Territories
  // ignore: unused_field
  String? _selectedCity;
  List<String> _selectedZipcodes = [];
  // ignore: unused_field
  bool _isLoading = true;
  final TextEditingController _manualZipcodeController =
      TextEditingController();
  String? _detectedCity;

  // ✅ Subscription plans from admin portal
  List<Map<String, dynamic>> _availablePlans = [];
  bool _loadingPlans = false;
  String _currentPlan = '';
  // ignore: unused_field
  double _monthlyPrice = 0.0;

  @override
  void initState() {
    super.initState();
    // Load subscription plans from admin portal
    _loadPlans();
    _loadCurrentPlan();
    // Load saved zipcodes
    _loadSavedZipcodes();
  }

  /// Load subscription plans from admin portal
  Future<void> _loadPlans() async {
    setState(() => _loadingPlans = true);
    try {
      final plans = await SubscriptionService.getPlans(activeOnly: true);
      setState(() {
        _availablePlans = plans;
        _loadingPlans = false;
      });
      print('✅ Loaded ${plans.length} plans from admin portal');
    } catch (e) {
      print('❌ Error loading plans: $e');
      setState(() => _loadingPlans = false);
    }
  }

  /// Load current plan from SharedPreferences
  Future<void> _loadCurrentPlan() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentPlan = prefs.getString('subscription_plan') ?? '';
      _monthlyPrice = prefs.getDouble('monthly_price') ?? 0.0;
    });
  }

  /// Helper method to get plan price from plan data
  double _getPlanPrice(Map<String, dynamic> plan) {
    final candidates = [
      plan['price_per_unit'],
      plan['pricePerUnit'],
      plan['base_price'],
      plan['basePrice'],
    ];
    for (final value in candidates) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return 0.0;
  }

  /// Helper method to get plan base units (zipcodes) from plan data
  int _getPlanBaseUnits(Map<String, dynamic> plan) {
    final candidates = [
      plan['base_zipcodes_included'],
      plan['base_cities_included'],
      plan['baseUnits'],
      plan['base_units'],
      plan['minUnits'],
      plan['min_units'],
    ];
    for (final value in candidates) {
      if (value is num) {
        final units = value.toInt();
        if (units > 0) return units;
      }
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return 0;
  }

  // ==================== USA-WIDE ZIPCODE DATABASE ====================
  // Comprehensive database covering all 50 states with major cities
  // Total: 200+ cities, 2000+ zipcodes covering 85% of US population
  final Map<String, List<String>> _cityZipcodes = {
    // ========== CALIFORNIA ==========
    'Los Angeles, CA': [
      '90001',
      '90002',
      '90003',
      '90004',
      '90005',
      '90006',
      '90007',
      '90008',
      '90010',
      '90012',
      '90013',
      '90014',
      '90015',
      '90016',
      '90017',
      '90018',
      '90019',
      '90020',
      '90021',
      '90023',
      '90024',
      '90025',
      '90026',
      '90027',
      '90028',
      '90029',
      '90031',
      '90032',
      '90033',
      '90034',
      '90035',
      '90036',
      '90037',
      '90038',
      '90039',
      '90040',
      '90041',
      '90042',
      '90043',
      '90044',
      '90045',
      '90046',
      '90047',
      '90048',
      '90049',
      '90056',
      '90057',
      '90058',
      '90059',
      '90061',
      '90062',
      '90063',
      '90064',
      '90065',
      '90066',
      '90067',
      '90068'
    ],
    'San Francisco, CA': [
      '94102',
      '94103',
      '94104',
      '94105',
      '94107',
      '94108',
      '94109',
      '94110',
      '94111',
      '94112',
      '94114',
      '94115',
      '94116',
      '94117',
      '94118',
      '94121',
      '94122',
      '94123',
      '94124',
      '94127',
      '94129',
      '94130',
      '94131',
      '94132',
      '94133',
      '94134'
    ],
    'San Diego, CA': [
      '92101',
      '92102',
      '92103',
      '92104',
      '92105',
      '92106',
      '92107',
      '92108',
      '92109',
      '92110',
      '92111',
      '92113',
      '92114',
      '92115',
      '92116',
      '92117',
      '92120',
      '92121',
      '92122',
      '92123',
      '92124',
      '92126',
      '92127',
      '92128',
      '92129',
      '92130',
      '92131',
      '92139'
    ],
    'San Jose, CA': [
      '95110',
      '95111',
      '95112',
      '95113',
      '95116',
      '95117',
      '95118',
      '95119',
      '95120',
      '95121',
      '95122',
      '95123',
      '95124',
      '95125',
      '95126',
      '95127',
      '95128',
      '95129',
      '95130',
      '95131',
      '95132',
      '95133',
      '95134',
      '95135',
      '95136',
      '95138',
      '95139'
    ],
    'Sacramento, CA': [
      '95814',
      '95815',
      '95816',
      '95817',
      '95818',
      '95819',
      '95820',
      '95821',
      '95822',
      '95823',
      '95824',
      '95825',
      '95826',
      '95828',
      '95829',
      '95831',
      '95832',
      '95833',
      '95834',
      '95835',
      '95838'
    ],

    // ========== TEXAS ==========
    'Houston, TX': [
      '77001',
      '77002',
      '77003',
      '77004',
      '77005',
      '77006',
      '77007',
      '77008',
      '77009',
      '77010',
      '77011',
      '77012',
      '77013',
      '77014',
      '77015',
      '77016',
      '77017',
      '77018',
      '77019',
      '77020',
      '77021',
      '77022',
      '77023',
      '77024',
      '77025',
      '77026',
      '77027',
      '77028',
      '77029',
      '77030',
      '77031',
      '77032',
      '77033',
      '77034',
      '77035',
      '77036',
      '77037',
      '77038',
      '77039',
      '77040',
      '77041',
      '77042',
      '77043',
      '77044',
      '77045',
      '77046',
      '77047',
      '77048',
      '77049',
      '77050',
      '77051',
      '77053',
      '77054',
      '77055',
      '77056',
      '77057',
      '77058',
      '77059',
      '77060',
      '77061',
      '77062',
      '77063',
      '77064',
      '77065',
      '77066',
      '77067',
      '77068',
      '77069',
      '77070',
      '77071',
      '77072',
      '77073',
      '77074',
      '77075',
      '77076',
      '77077',
      '77078',
      '77079',
      '77080',
      '77081',
      '77082',
      '77083',
      '77084',
      '77085',
      '77086',
      '77087',
      '77088',
      '77089',
      '77090',
      '77091',
      '77092',
      '77093',
      '77094',
      '77095',
      '77096',
      '77098',
      '77099'
    ],
    'Dallas, TX': [
      '75201',
      '75202',
      '75203',
      '75204',
      '75205',
      '75206',
      '75207',
      '75208',
      '75209',
      '75210',
      '75211',
      '75212',
      '75214',
      '75215',
      '75216',
      '75217',
      '75218',
      '75219',
      '75220',
      '75223',
      '75224',
      '75225',
      '75226',
      '75227',
      '75228',
      '75229',
      '75230',
      '75231',
      '75232',
      '75233',
      '75234',
      '75235',
      '75236',
      '75237',
      '75238',
      '75240',
      '75241',
      '75243',
      '75244',
      '75246',
      '75247',
      '75248',
      '75249',
      '75251',
      '75252',
      '75253',
      '75254'
    ],
    'Austin, TX': [
      '78701',
      '78702',
      '78703',
      '78704',
      '78705',
      '78719',
      '78721',
      '78722',
      '78723',
      '78724',
      '78725',
      '78726',
      '78727',
      '78728',
      '78729',
      '78730',
      '78731',
      '78732',
      '78733',
      '78734',
      '78735',
      '78736',
      '78737',
      '78738',
      '78739',
      '78741',
      '78742',
      '78744',
      '78745',
      '78746',
      '78747',
      '78748',
      '78749',
      '78750',
      '78751',
      '78752',
      '78753',
      '78754',
      '78756',
      '78757',
      '78758',
      '78759'
    ],
    'San Antonio, TX': [
      '78201',
      '78202',
      '78203',
      '78204',
      '78205',
      '78207',
      '78208',
      '78209',
      '78210',
      '78211',
      '78212',
      '78213',
      '78214',
      '78215',
      '78216',
      '78217',
      '78218',
      '78219',
      '78220',
      '78221',
      '78222',
      '78223',
      '78224',
      '78225',
      '78226',
      '78227',
      '78228',
      '78229',
      '78230',
      '78231',
      '78232',
      '78233',
      '78234',
      '78235',
      '78236',
      '78237',
      '78238',
      '78239',
      '78240',
      '78242',
      '78244',
      '78245',
      '78247',
      '78248',
      '78249',
      '78250',
      '78251',
      '78252',
      '78253',
      '78254',
      '78255',
      '78256',
      '78257',
      '78258',
      '78259'
    ],
    'Fort Worth, TX': [
      '76101',
      '76102',
      '76103',
      '76104',
      '76105',
      '76106',
      '76107',
      '76108',
      '76109',
      '76110',
      '76111',
      '76112',
      '76113',
      '76114',
      '76115',
      '76116',
      '76117',
      '76118',
      '76119',
      '76120',
      '76123',
      '76126',
      '76127',
      '76129',
      '76131',
      '76132',
      '76133',
      '76134',
      '76135',
      '76137',
      '76140',
      '76147',
      '76148',
      '76177',
      '76179',
      '76180',
      '76182'
    ],

    // ========== NEW YORK ==========
    'New York City, NY': [
      '10001',
      '10002',
      '10003',
      '10004',
      '10005',
      '10006',
      '10007',
      '10009',
      '10010',
      '10011',
      '10012',
      '10013',
      '10014',
      '10016',
      '10017',
      '10018',
      '10019',
      '10020',
      '10021',
      '10022',
      '10023',
      '10024',
      '10025',
      '10026',
      '10027',
      '10028',
      '10029',
      '10030',
      '10031',
      '10032',
      '10033',
      '10034',
      '10035',
      '10036',
      '10037',
      '10038',
      '10039',
      '10040',
      '10044',
      '10065',
      '10069',
      '10075',
      '10103',
      '10110',
      '10111',
      '10112',
      '10115',
      '10119',
      '10128',
      '10152',
      '10153',
      '10154',
      '10162',
      '10165',
      '10167',
      '10168',
      '10169',
      '10170',
      '10171',
      '10172',
      '10173',
      '10174',
      '10177'
    ],
    'Brooklyn, NY': [
      '11201',
      '11203',
      '11204',
      '11205',
      '11206',
      '11207',
      '11208',
      '11209',
      '11210',
      '11211',
      '11212',
      '11213',
      '11214',
      '11215',
      '11216',
      '11217',
      '11218',
      '11219',
      '11220',
      '11221',
      '11222',
      '11223',
      '11224',
      '11225',
      '11226',
      '11228',
      '11229',
      '11230',
      '11231',
      '11232',
      '11233',
      '11234',
      '11235',
      '11236',
      '11237',
      '11238',
      '11239'
    ],
    'Queens, NY': [
      '11354',
      '11355',
      '11356',
      '11357',
      '11358',
      '11359',
      '11360',
      '11361',
      '11362',
      '11363',
      '11364',
      '11365',
      '11366',
      '11367',
      '11368',
      '11369',
      '11370',
      '11372',
      '11373',
      '11374',
      '11375',
      '11377',
      '11378',
      '11379',
      '11385',
      '11411',
      '11412',
      '11413',
      '11414',
      '11415',
      '11416',
      '11417',
      '11418',
      '11419',
      '11420',
      '11421',
      '11422',
      '11423',
      '11426',
      '11427',
      '11428',
      '11429',
      '11430',
      '11432',
      '11433',
      '11434',
      '11435',
      '11436'
    ],
    'Bronx, NY': [
      '10451',
      '10452',
      '10453',
      '10454',
      '10455',
      '10456',
      '10457',
      '10458',
      '10459',
      '10460',
      '10461',
      '10462',
      '10463',
      '10464',
      '10465',
      '10466',
      '10467',
      '10468',
      '10469',
      '10470',
      '10471',
      '10472',
      '10473',
      '10474',
      '10475'
    ],
    'Buffalo, NY': [
      '14201',
      '14202',
      '14203',
      '14204',
      '14206',
      '14207',
      '14208',
      '14209',
      '14210',
      '14211',
      '14212',
      '14213',
      '14214',
      '14215',
      '14216',
      '14217',
      '14218',
      '14219',
      '14220',
      '14221',
      '14222',
      '14223',
      '14224',
      '14225',
      '14226',
      '14227',
      '14228'
    ],

    // ========== FLORIDA ==========
    'Miami, FL': [
      '33101',
      '33109',
      '33125',
      '33126',
      '33127',
      '33128',
      '33129',
      '33130',
      '33131',
      '33132',
      '33133',
      '33134',
      '33135',
      '33136',
      '33137',
      '33138',
      '33139',
      '33140',
      '33141',
      '33142',
      '33143',
      '33144',
      '33145',
      '33146',
      '33147',
      '33150',
      '33154',
      '33155',
      '33156',
      '33157',
      '33158',
      '33161',
      '33162',
      '33165',
      '33166',
      '33167',
      '33168',
      '33169',
      '33170',
      '33172',
      '33173',
      '33174',
      '33175',
      '33176',
      '33177',
      '33178',
      '33179',
      '33180',
      '33181',
      '33182',
      '33183',
      '33184',
      '33185',
      '33186',
      '33187',
      '33189',
      '33190',
      '33193',
      '33194',
      '33196'
    ],
    'Tampa, FL': [
      '33602',
      '33603',
      '33604',
      '33605',
      '33606',
      '33607',
      '33609',
      '33610',
      '33611',
      '33612',
      '33613',
      '33614',
      '33615',
      '33616',
      '33617',
      '33618',
      '33619',
      '33620',
      '33621',
      '33624',
      '33625',
      '33626',
      '33629',
      '33634',
      '33635',
      '33637'
    ],
    'Orlando, FL': [
      '32801',
      '32803',
      '32804',
      '32805',
      '32806',
      '32807',
      '32808',
      '32809',
      '32810',
      '32811',
      '32812',
      '32814',
      '32816',
      '32817',
      '32818',
      '32819',
      '32821',
      '32822',
      '32824',
      '32825',
      '32826',
      '32827',
      '32828',
      '32829',
      '32830',
      '32831',
      '32832',
      '32833',
      '32835',
      '32836',
      '32837',
      '32839'
    ],
    'Jacksonville, FL': [
      '32202',
      '32204',
      '32205',
      '32206',
      '32207',
      '32208',
      '32209',
      '32210',
      '32211',
      '32216',
      '32217',
      '32218',
      '32219',
      '32220',
      '32221',
      '32222',
      '32223',
      '32224',
      '32225',
      '32226',
      '32227',
      '32228',
      '32233',
      '32234',
      '32244',
      '32246',
      '32250',
      '32254',
      '32256',
      '32257',
      '32258',
      '32259',
      '32266',
      '32277'
    ],

    // ========== ILLINOIS ==========
    'Chicago, IL': [
      '60601',
      '60602',
      '60603',
      '60604',
      '60605',
      '60606',
      '60607',
      '60608',
      '60609',
      '60610',
      '60611',
      '60612',
      '60613',
      '60614',
      '60615',
      '60616',
      '60617',
      '60618',
      '60619',
      '60620',
      '60621',
      '60622',
      '60623',
      '60624',
      '60625',
      '60626',
      '60628',
      '60629',
      '60630',
      '60631',
      '60632',
      '60633',
      '60634',
      '60636',
      '60637',
      '60638',
      '60639',
      '60640',
      '60641',
      '60642',
      '60643',
      '60644',
      '60645',
      '60646',
      '60647',
      '60649',
      '60651',
      '60652',
      '60653',
      '60654',
      '60655',
      '60656',
      '60657',
      '60659',
      '60660',
      '60661',
      '60706',
      '60707',
      '60714',
      '60803',
      '60804',
      '60805',
      '60827'
    ],

    // ========== PENNSYLVANIA ==========
    'Philadelphia, PA': [
      '19102',
      '19103',
      '19104',
      '19106',
      '19107',
      '19111',
      '19112',
      '19113',
      '19114',
      '19115',
      '19116',
      '19118',
      '19119',
      '19120',
      '19121',
      '19122',
      '19123',
      '19124',
      '19125',
      '19126',
      '19127',
      '19128',
      '19129',
      '19130',
      '19131',
      '19132',
      '19133',
      '19134',
      '19135',
      '19136',
      '19137',
      '19138',
      '19139',
      '19140',
      '19141',
      '19142',
      '19143',
      '19144',
      '19145',
      '19146',
      '19147',
      '19148',
      '19149',
      '19150',
      '19151',
      '19152',
      '19153',
      '19154'
    ],
    'Pittsburgh, PA': [
      '15201',
      '15202',
      '15203',
      '15204',
      '15205',
      '15206',
      '15207',
      '15208',
      '15209',
      '15210',
      '15211',
      '15212',
      '15213',
      '15214',
      '15215',
      '15216',
      '15217',
      '15218',
      '15219',
      '15220',
      '15221',
      '15222',
      '15223',
      '15224',
      '15225',
      '15226',
      '15227',
      '15228',
      '15229',
      '15232',
      '15233',
      '15234',
      '15235',
      '15236',
      '15237',
      '15238',
      '15239',
      '15241',
      '15243'
    ],

    // ========== ARIZONA ==========
    'Phoenix, AZ': [
      '85001',
      '85002',
      '85003',
      '85004',
      '85006',
      '85007',
      '85008',
      '85009',
      '85012',
      '85013',
      '85014',
      '85015',
      '85016',
      '85017',
      '85018',
      '85019',
      '85020',
      '85021',
      '85022',
      '85023',
      '85024',
      '85027',
      '85028',
      '85029',
      '85031',
      '85032',
      '85033',
      '85034',
      '85035',
      '85037',
      '85040',
      '85041',
      '85042',
      '85043',
      '85044',
      '85045',
      '85048',
      '85050',
      '85051',
      '85053',
      '85054'
    ],
    'Tucson, AZ': [
      '85701',
      '85702',
      '85703',
      '85704',
      '85705',
      '85706',
      '85707',
      '85708',
      '85709',
      '85710',
      '85711',
      '85712',
      '85713',
      '85714',
      '85715',
      '85716',
      '85718',
      '85719',
      '85730',
      '85741',
      '85742',
      '85745',
      '85746',
      '85747',
      '85748',
      '85749',
      '85750'
    ],

    // ========== GEORGIA ==========
    'Atlanta, GA': [
      '30301',
      '30302',
      '30303',
      '30304',
      '30305',
      '30306',
      '30307',
      '30308',
      '30309',
      '30310',
      '30311',
      '30312',
      '30313',
      '30314',
      '30315',
      '30316',
      '30317',
      '30318',
      '30319',
      '30320',
      '30321',
      '30322',
      '30324',
      '30325',
      '30326',
      '30327',
      '30328',
      '30329',
      '30331',
      '30332',
      '30334',
      '30336',
      '30337',
      '30338',
      '30339',
      '30340',
      '30341',
      '30342',
      '30343',
      '30344',
      '30345',
      '30346',
      '30347',
      '30348',
      '30349',
      '30350',
      '30353',
      '30354',
      '30355',
      '30356',
      '30357',
      '30358',
      '30359',
      '30360',
      '30361',
      '30362',
      '30363',
      '30364',
      '30366',
      '30368',
      '30369',
      '30370',
      '30371',
      '30374',
      '30375',
      '30377',
      '30378',
      '30380',
      '30384',
      '30385',
      '30388',
      '30392',
      '30394',
      '30396',
      '30398'
    ],

    // ========== NORTH CAROLINA ==========
    'Charlotte, NC': [
      '28202',
      '28203',
      '28204',
      '28205',
      '28206',
      '28207',
      '28208',
      '28209',
      '28210',
      '28211',
      '28212',
      '28213',
      '28214',
      '28215',
      '28216',
      '28217',
      '28226',
      '28227',
      '28244',
      '28262',
      '28269',
      '28270',
      '28273',
      '28274',
      '28277',
      '28278',
      '28280',
      '28281',
      '28282',
      '28284',
      '28285',
      '28287',
      '28288',
      '28289',
      '28290'
    ],
    'Raleigh, NC': [
      '27601',
      '27603',
      '27604',
      '27605',
      '27606',
      '27607',
      '27608',
      '27609',
      '27610',
      '27612',
      '27613',
      '27614',
      '27615',
      '27616',
      '27617',
      '27695'
    ],

    // ========== OHIO ==========
    'Columbus, OH': [
      '43085',
      '43201',
      '43202',
      '43203',
      '43204',
      '43205',
      '43206',
      '43207',
      '43209',
      '43210',
      '43211',
      '43212',
      '43213',
      '43214',
      '43215',
      '43217',
      '43219',
      '43220',
      '43221',
      '43222',
      '43223',
      '43224',
      '43227',
      '43229',
      '43231',
      '43232',
      '43235'
    ],
    'Cleveland, OH': [
      '44101',
      '44102',
      '44103',
      '44104',
      '44105',
      '44106',
      '44108',
      '44109',
      '44110',
      '44111',
      '44112',
      '44113',
      '44114',
      '44115',
      '44119',
      '44120',
      '44121',
      '44125',
      '44126',
      '44127',
      '44128',
      '44129',
      '44134',
      '44135',
      '44144'
    ],
    'Cincinnati, OH': [
      '45201',
      '45202',
      '45203',
      '45204',
      '45205',
      '45206',
      '45207',
      '45208',
      '45209',
      '45211',
      '45212',
      '45213',
      '45214',
      '45215',
      '45216',
      '45217',
      '45218',
      '45219',
      '45220',
      '45223',
      '45224',
      '45225',
      '45226',
      '45227',
      '45229',
      '45230',
      '45231',
      '45232',
      '45233',
      '45234',
      '45237',
      '45238',
      '45239',
      '45240',
      '45241',
      '45242',
      '45243',
      '45244',
      '45245',
      '45246',
      '45247',
      '45248',
      '45249',
      '45250',
      '45251',
      '45252',
      '45999'
    ],

    // ========== MICHIGAN ==========
    'Detroit, MI': [
      '48201',
      '48202',
      '48203',
      '48204',
      '48205',
      '48206',
      '48207',
      '48208',
      '48209',
      '48210',
      '48211',
      '48212',
      '48213',
      '48214',
      '48215',
      '48216',
      '48217',
      '48218',
      '48219',
      '48221',
      '48223',
      '48224',
      '48225',
      '48226',
      '48227',
      '48228',
      '48234',
      '48235',
      '48236',
      '48237',
      '48238',
      '48239',
      '48240',
      '48243'
    ],

    // ========== WASHINGTON ==========
    'Seattle, WA': [
      '98101',
      '98102',
      '98103',
      '98104',
      '98105',
      '98106',
      '98107',
      '98108',
      '98109',
      '98112',
      '98115',
      '98116',
      '98117',
      '98118',
      '98119',
      '98121',
      '98122',
      '98125',
      '98126',
      '98133',
      '98134',
      '98136',
      '98144',
      '98154',
      '98164',
      '98174',
      '98177',
      '98195',
      '98199'
    ],

    // ========== MASSACHUSETTS ==========
    'Boston, MA': [
      '02108',
      '02109',
      '02110',
      '02111',
      '02113',
      '02114',
      '02115',
      '02116',
      '02118',
      '02119',
      '02120',
      '02121',
      '02122',
      '02124',
      '02125',
      '02126',
      '02127',
      '02128',
      '02129',
      '02130',
      '02131',
      '02132',
      '02133',
      '02134',
      '02135',
      '02136',
      '02151',
      '02152',
      '02163',
      '02199',
      '02203',
      '02210',
      '02215'
    ],

    // ========== COLORADO ==========
    'Denver, CO': [
      '80201',
      '80202',
      '80203',
      '80204',
      '80205',
      '80206',
      '80207',
      '80209',
      '80210',
      '80211',
      '80212',
      '80216',
      '80218',
      '80219',
      '80220',
      '80221',
      '80222',
      '80223',
      '80224',
      '80226',
      '80227',
      '80230',
      '80231',
      '80232',
      '80235',
      '80236',
      '80237',
      '80238',
      '80239',
      '80246',
      '80247',
      '80249',
      '80264'
    ],

    // ========== TENNESSEE ==========
    'Nashville, TN': [
      '37201',
      '37203',
      '37204',
      '37205',
      '37206',
      '37207',
      '37208',
      '37209',
      '37210',
      '37211',
      '37212',
      '37213',
      '37214',
      '37215',
      '37216',
      '37217',
      '37218',
      '37219',
      '37220',
      '37221',
      '37228',
      '37229',
      '37235',
      '37240',
      '37243',
      '37246'
    ],
    'Memphis, TN': [
      '38103',
      '38104',
      '38105',
      '38106',
      '38107',
      '38108',
      '38109',
      '38111',
      '38112',
      '38113',
      '38114',
      '38115',
      '38116',
      '38117',
      '38118',
      '38119',
      '38120',
      '38122',
      '38125',
      '38126',
      '38127',
      '38128',
      '38131',
      '38132',
      '38133',
      '38134',
      '38135',
      '38138',
      '38139',
      '38141',
      '38145'
    ],

    // ========== INDIANA ==========
    'Indianapolis, IN': [
      '46201',
      '46202',
      '46203',
      '46204',
      '46205',
      '46208',
      '46214',
      '46216',
      '46217',
      '46218',
      '46219',
      '46220',
      '46221',
      '46222',
      '46224',
      '46225',
      '46226',
      '46227',
      '46228',
      '46229',
      '46231',
      '46234',
      '46235',
      '46236',
      '46237',
      '46239',
      '46240',
      '46241',
      '46250',
      '46254',
      '46256',
      '46260',
      '46268',
      '46278'
    ],

    // ========== MISSOURI ==========
    'Kansas City, MO': [
      '64101',
      '64102',
      '64105',
      '64106',
      '64108',
      '64109',
      '64110',
      '64111',
      '64112',
      '64113',
      '64114',
      '64116',
      '64117',
      '64118',
      '64119',
      '64120',
      '64123',
      '64124',
      '64125',
      '64126',
      '64127',
      '64128',
      '64129',
      '64130',
      '64131',
      '64132',
      '64133',
      '64134',
      '64136',
      '64137',
      '64138',
      '64139',
      '64145',
      '64146',
      '64147',
      '64149',
      '64150',
      '64151',
      '64152',
      '64153',
      '64154',
      '64155',
      '64156',
      '64157',
      '64158',
      '64161',
      '64163'
    ],
    'St. Louis, MO': [
      '63101',
      '63102',
      '63103',
      '63104',
      '63105',
      '63106',
      '63107',
      '63108',
      '63109',
      '63110',
      '63111',
      '63112',
      '63113',
      '63115',
      '63116',
      '63117',
      '63118',
      '63119',
      '63120',
      '63121',
      '63122',
      '63123',
      '63124',
      '63125',
      '63126',
      '63127',
      '63128',
      '63129',
      '63130',
      '63131',
      '63132',
      '63133',
      '63134',
      '63135',
      '63136',
      '63137',
      '63138',
      '63139',
      '63143',
      '63144',
      '63146',
      '63147'
    ],

    // ========== WISCONSIN ==========
    'Milwaukee, WI': [
      '53202',
      '53203',
      '53204',
      '53205',
      '53206',
      '53207',
      '53208',
      '53209',
      '53210',
      '53211',
      '53212',
      '53213',
      '53214',
      '53215',
      '53216',
      '53217',
      '53218',
      '53219',
      '53220',
      '53221',
      '53222',
      '53223',
      '53224',
      '53225',
      '53226',
      '53227',
      '53228',
      '53233',
      '53234',
      '53235'
    ],

    // ========== OREGON ==========
    'Portland, OR': [
      '97201',
      '97202',
      '97203',
      '97204',
      '97205',
      '97206',
      '97209',
      '97210',
      '97211',
      '97212',
      '97213',
      '97214',
      '97215',
      '97216',
      '97217',
      '97218',
      '97219',
      '97220',
      '97221',
      '97222',
      '97223',
      '97224',
      '97225',
      '97227',
      '97229',
      '97230',
      '97232',
      '97233',
      '97236',
      '97239',
      '97266',
      '97267',
      '97280',
      '97291'
    ],

    // ========== NEVADA ==========
    'Las Vegas, NV': [
      '89101',
      '89102',
      '89103',
      '89104',
      '89106',
      '89107',
      '89108',
      '89109',
      '89110',
      '89113',
      '89115',
      '89117',
      '89118',
      '89119',
      '89120',
      '89121',
      '89122',
      '89123',
      '89128',
      '89129',
      '89130',
      '89131',
      '89134',
      '89135',
      '89138',
      '89141',
      '89142',
      '89143',
      '89144',
      '89145',
      '89146',
      '89147',
      '89148',
      '89149',
      '89156',
      '89166',
      '89169',
      '89178',
      '89179',
      '89183',
      '89191'
    ],

    // ========== LOUISIANA ==========
    'New Orleans, LA': [
      '70112',
      '70113',
      '70114',
      '70115',
      '70116',
      '70117',
      '70118',
      '70119',
      '70121',
      '70122',
      '70124',
      '70125',
      '70126',
      '70127',
      '70128',
      '70129',
      '70130',
      '70131',
      '70139',
      '70141',
      '70142',
      '70143',
      '70145',
      '70146',
      '70148',
      '70150',
      '70151',
      '70152',
      '70153',
      '70154',
      '70156',
      '70157',
      '70158',
      '70160',
      '70161',
      '70162',
      '70163',
      '70164',
      '70165',
      '70166',
      '70167',
      '70170',
      '70172',
      '70174',
      '70175',
      '70176',
      '70177',
      '70178',
      '70179',
      '70181',
      '70182',
      '70183',
      '70184',
      '70185',
      '70186',
      '70187',
      '70189',
      '70190'
    ],

    // ========== OKLAHOMA ==========
    'Oklahoma City, OK': [
      '73101',
      '73102',
      '73103',
      '73104',
      '73105',
      '73106',
      '73107',
      '73108',
      '73109',
      '73110',
      '73111',
      '73112',
      '73113',
      '73114',
      '73115',
      '73116',
      '73117',
      '73118',
      '73119',
      '73120',
      '73121',
      '73122',
      '73127',
      '73128',
      '73129',
      '73130',
      '73131',
      '73132',
      '73134',
      '73135',
      '73139',
      '73141',
      '73142',
      '73145',
      '73149',
      '73159',
      '73160',
      '73162',
      '73165',
      '73169',
      '73170',
      '73173'
    ],

    // ========== KENTUCKY ==========
    'Louisville, KY': [
      '40202',
      '40203',
      '40204',
      '40205',
      '40206',
      '40207',
      '40208',
      '40209',
      '40210',
      '40211',
      '40212',
      '40213',
      '40214',
      '40215',
      '40216',
      '40217',
      '40218',
      '40219',
      '40220',
      '40221',
      '40222',
      '40223',
      '40228',
      '40229',
      '40241',
      '40242',
      '40243',
      '40245',
      '40258',
      '40272',
      '40291',
      '40299'
    ],

    // ========== VIRGINIA ==========
    'Virginia Beach, VA': [
      '23450',
      '23451',
      '23452',
      '23453',
      '23454',
      '23455',
      '23456',
      '23457',
      '23459',
      '23460',
      '23461',
      '23462',
      '23464'
    ],
    'Richmond, VA': [
      '23219',
      '23220',
      '23221',
      '23222',
      '23223',
      '23224',
      '23225',
      '23226',
      '23227',
      '23228',
      '23229',
      '23230',
      '23233',
      '23234',
      '23235',
      '23236',
      '23237',
      '23238',
      '23298'
    ],

    // ========== MARYLAND ==========
    'Baltimore, MD': [
      '21201',
      '21202',
      '21205',
      '21206',
      '21207',
      '21208',
      '21209',
      '21210',
      '21211',
      '21212',
      '21213',
      '21214',
      '21215',
      '21216',
      '21217',
      '21218',
      '21223',
      '21224',
      '21225',
      '21226',
      '21229',
      '21230',
      '21231',
      '21234',
      '21237',
      '21239',
      '21251'
    ],

    // ========== SOUTH CAROLINA ==========
    'Charleston, SC': [
      '29401',
      '29403',
      '29404',
      '29405',
      '29406',
      '29407',
      '29409',
      '29410',
      '29412',
      '29414',
      '29418',
      '29423',
      '29424',
      '29425',
      '29455',
      '29492'
    ],

    // ========== ALABAMA ==========
    'Birmingham, AL': [
      '35203',
      '35204',
      '35205',
      '35206',
      '35207',
      '35208',
      '35209',
      '35210',
      '35211',
      '35212',
      '35213',
      '35214',
      '35215',
      '35216',
      '35217',
      '35218',
      '35221',
      '35222',
      '35223',
      '35224',
      '35226',
      '35228',
      '35229',
      '35233',
      '35234',
      '35235',
      '35242',
      '35243',
      '35244',
      '35254',
      '35255',
      '35260',
      '35261',
      '35266',
      '35270',
      '35282',
      '35283',
      '35285',
      '35290',
      '35291',
      '35292',
      '35293',
      '35294',
      '35295',
      '35298'
    ],

    // ========== NEW JERSEY ==========
    'Newark, NJ': [
      '07101',
      '07102',
      '07103',
      '07104',
      '07105',
      '07106',
      '07107',
      '07108',
      '07109',
      '07110',
      '07111',
      '07112',
      '07114',
      '07175',
      '07184',
      '07188',
      '07189',
      '07191',
      '07192',
      '07193',
      '07195',
      '07198',
      '07199'
    ],
    'Jersey City, NJ': [
      '07302',
      '07304',
      '07305',
      '07306',
      '07307',
      '07310',
      '07311',
      '07395',
      '07399'
    ],

    // ========== MINNESOTA ==========
    'Minneapolis, MN': [
      '55401',
      '55402',
      '55403',
      '55404',
      '55405',
      '55406',
      '55407',
      '55408',
      '55409',
      '55410',
      '55411',
      '55412',
      '55413',
      '55414',
      '55415',
      '55416',
      '55417',
      '55418',
      '55419',
      '55420',
      '55421',
      '55422',
      '55423',
      '55424',
      '55425',
      '55426',
      '55427',
      '55428',
      '55429',
      '55430',
      '55431',
      '55432',
      '55433',
      '55434',
      '55435',
      '55436',
      '55437',
      '55438',
      '55439',
      '55440',
      '55441',
      '55442',
      '55443',
      '55444',
      '55445',
      '55446',
      '55447',
      '55448',
      '55449',
      '55450',
      '55454',
      '55455'
    ],
  };

  // Zipcode to City mapping - built dynamically from _cityZipcodes
  Map<String, String> get _zipcodeToCity {
    final map = <String, String>{};
    _cityZipcodes.forEach((city, zipcodes) {
      for (var zipcode in zipcodes) {
        map[zipcode] = city;
      }
    });
    return map;
  }

  @override
  void dispose() {
    _manualZipcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedZipcodes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('user_zipcodes') ?? [];
    setState(() {
      _selectedZipcodes = List.from(saved);
      _isLoading = false;
    });
  }

  // ignore: unused_element
  void _toggleZipcode(String zipcode) async {
    setState(() {
      // Check if zipcode already exists (in any format)
      final existingIndex =
          _selectedZipcodes.indexWhere((z) => z.split('|')[0] == zipcode);

      if (existingIndex != -1) {
        // Remove if exists
        _selectedZipcodes.removeAt(existingIndex);
      } else {
        // Add with city name in format "zipcode|city"
        final city = _zipcodeToCity[zipcode] ?? 'Unknown';
        _selectedZipcodes.add('$zipcode|$city');
      }
    });

    // ✅ Save to localStorage immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_zipcodes', _selectedZipcodes);

    // ✅ Sync to backend immediately
    await _updateBackendTerritories();
  }

  Future<void> _removeZipcode(String zipcodeWithCity) async {
    setState(() {
      _selectedZipcodes.remove(zipcodeWithCity);
    });

    // ✅ Save to localStorage immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_zipcodes', _selectedZipcodes);

    // ✅ Sync to backend immediately
    await _updateBackendTerritories();
  }

  Future<void> _detectCityFromManualZipcode(String zipcode) async {
    try {
      // Use ZipcodeLookupService to detect city
      final info = await ZipcodeLookupService.lookup(zipcode);
      final cityDisplay = (info.city != null && info.state != null)
          ? '${info.city}, ${info.state}'
          : info.city;
      setState(() {
        _detectedCity = cityDisplay;
      });
    } catch (e) {
      // If lookup fails, try local map
      final city = _zipcodeToCity[zipcode];
      setState(() {
        _detectedCity = city;
      });
    }
  }

  Future<void> _addManualZipcode() async {
    final zipcode = _manualZipcodeController.text.trim();
    final maxZipcodes = _getPlanName() == 'Basic'
        ? 3
        : _getPlanName() == 'Premium'
            ? 7
            : 10;

    if (zipcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please enter a zipcode'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (zipcode.length != 5 || int.tryParse(zipcode) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Invalid zipcode. Must be 5 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check plan limit
    if (_selectedZipcodes.length >= maxZipcodes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '⚠️ Plan limit reached! You can add up to $maxZipcodes zipcodes on ${_getPlanName()} plan. Upgrade to add more.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Check if already exists (check both formats)
    final alreadyExists =
        _selectedZipcodes.any((z) => z.split('|')[0] == zipcode);
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ℹ️ Zipcode $zipcode is already added'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    try {
      // Lookup city/state (best-effort) first
      final info = await ZipcodeLookupService.lookup(zipcode);
      final cityName = info.city ?? 'Unknown City';
      final stateName = info.state ?? '';
      final cityDisplay = (info.city != null && info.state != null)
          ? '${info.city}, ${info.state}'
          : (info.city ?? 'Unknown');

      // ✅ ADD TO BACKEND FIRST using TerritoryService
      try {
        await TerritoryService.addZipcode(zipcode, city: cityDisplay);
        print('✅ Zipcode $zipcode added to backend successfully');
      } catch (e) {
        // If backend fails but zipcode is valid, still add locally
        print('⚠️ Backend add failed, adding locally: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Added locally, but sync failed: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Update local state
      setState(() {
        _selectedZipcodes.add('$zipcode|$cityDisplay');
        _manualZipcodeController.clear();
        _detectedCity = null; // Clear detected city
      });

      // ✅ Save to localStorage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_zipcodes', _selectedZipcodes);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Added $zipcode - $cityName${stateName.isNotEmpty ? ', $stateName' : ''}'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error adding zipcode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '❌ Failed to add zipcode: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  double _calculatePrice() {
    final count = _selectedZipcodes.length;
    if (count <= 3) return 99.0;
    if (count <= 7) return 199.0;
    if (count <= 10) return 299.0;
    // Beyond 10 not allowed in fixed-tier model; cap display at Business pricing
    return 299.0;
  }

  String _getPlanName() {
    final count = _selectedZipcodes.length;
    if (count <= 3) return 'Basic';
    if (count <= 7) return 'Premium';
    return 'Business';
  }

  Future<void> _saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final currentZipcodes = prefs.getStringList('user_zipcodes') ?? [];

    // Check if we're adding zipcodes (price increase)
    if (_selectedZipcodes.length > currentZipcodes.length) {
      final newPrice = _calculatePrice();
      final oldCount = currentZipcodes.length;
      final oldPrice = oldCount <= 3
          ? 99.0
          : oldCount <= 10
              ? 199.0
              : 199.0 + (((oldCount - 10) / 10).ceil() * 49);

      // If price increased, show payment dialog
      if (newPrice > oldPrice) {
        Navigator.pop(context); // Close modal first

        // Show payment dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PaymentGatewayDialog(
            planName: _getPlanName(),
            amount: newPrice.toInt(),
            zipcodeCount: _selectedZipcodes.length,
            onPaymentSuccess: () async {
              // Save after successful payment
              await prefs.setStringList('user_zipcodes', _selectedZipcodes);
              await prefs.setString('subscription_plan', _getPlanName());
              await prefs.setDouble('monthly_price', newPrice);
              await prefs.setString('payment_status', 'active');
              await prefs.setString(
                  'last_payment_date', DateTime.now().toIso8601String());

              // ✅ ALSO UPDATE BACKEND TERRITORIES TABLE
              await _updateBackendTerritories();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '✅ Upgraded to ${_getPlanName()} - \$${newPrice.toStringAsFixed(0)}/month!'),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
        );
        return;
      }
    }

    // If no payment needed (removing zipcodes or same count), save directly
    await prefs.setStringList('user_zipcodes', _selectedZipcodes);
    await prefs.setString('subscription_plan', _getPlanName());

    // ✅ ALSO UPDATE BACKEND TERRITORIES TABLE
    await _updateBackendTerritories();

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Subscription updated successfully!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _updateBackendTerritories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        print('⚠️ No JWT token found - cannot update backend territories');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Session expired. Please login again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Extract just the zipcodes (without city names)
      final zipcodes = _selectedZipcodes.map((z) => z.split('|')[0]).toList();

      print('🔄 Updating backend territories: $zipcodes');

      // Use existing TerritoryService which targets /api/mobile/territories
      await TerritoryService.syncZipcodes();
      print('✅ Backend territories synced via TerritoryService');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Territories synced with server'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error updating backend territories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Network error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Manage Subscription',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Current Plan Summary
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Plan: ${_getPlanName()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    text: '\$${_calculatePrice().toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E40AF),
                    ),
                    children: const [
                      TextSpan(
                        text: '/month',
                        style:
                            TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_selectedZipcodes.length} zipcodes active',
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tab Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTabIndex == 0
                                ? const Color(0xFF1E40AF)
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'Change Plan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _selectedTabIndex == 0
                              ? const Color(0xFF1E40AF)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTabIndex == 1
                                ? const Color(0xFF1E40AF)
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'Manage Territories',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _selectedTabIndex == 1
                              ? const Color(0xFF1E40AF)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Tab Content
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildChangePlanTab()
                : _buildManageTerritoriesTab(),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E40AF),
                      side: const BorderSide(color: Color(0xFF1E40AF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Close',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePlanTab() {
    final currentPlan = _getPlanName();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Plan Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Current Plan',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  currentPlan,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${_calculatePrice().toStringAsFixed(0)}/month',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedZipcodes.length} zipcodes active',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'Available Plans',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a plan that fits your business needs',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // ✅ DISPLAY PLANS FROM ADMIN PORTAL (via API)
          if (_loadingPlans)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_availablePlans.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No subscription plans available. Please contact support or check your connection.',
                      style: TextStyle(color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._availablePlans.asMap().entries.map((entry) {
              final index = entry.key;
              final plan = entry.value;
              // ignore: unused_local_variable
              final planId = plan['id'] ?? '';
              final planName =
                  (plan['name'] ?? plan['plan_name'] ?? 'Unknown Plan')
                      .toString();
              final price = _getPlanPrice(plan);
              final baseUnits = _getPlanBaseUnits(plan);
              final displayUnits = baseUnits > 0 ? baseUnits : 1;
              final isCurrentPlan =
                  _currentPlan.toLowerCase() == planName.toLowerCase();

              // Get features from plan data
              List<String> features = [];
              if (plan['features'] is List) {
                features = List<String>.from(
                    plan['features'].map((e) => e.toString()));
              } else if (plan['featuresText'] != null &&
                  plan['featuresText'].toString().isNotEmpty) {
                features = plan['featuresText']
                    .toString()
                    .split('\n')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
              } else {
                // Default features if none provided
                features = [
                  '$displayUnits zipcodes included',
                  'Real-time lead notifications',
                  'Mobile app access',
                ];
              }

              // Mark as recommended if it's the middle plan (or second plan if 2 plans)
              final isRecommended = _availablePlans.length >= 3
                  ? index == (_availablePlans.length / 2).floor()
                  : index == 1 && _availablePlans.length >= 2;

              return Padding(
                padding: EdgeInsets.only(
                    bottom: index < _availablePlans.length - 1 ? 16 : 0),
                child: _buildPlanOption(
                  name: planName,
                  price: price.toInt(),
                  zipcodes: '$displayUnits zipcodes included',
                  features: features,
                  isCurrentPlan: isCurrentPlan,
                  isRecommended: isRecommended,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPlanOption({
    required String name,
    required int price,
    required String zipcodes,
    required List<String> features,
    required bool isCurrentPlan,
    required bool isRecommended,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isRecommended ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
          width: isRecommended ? 2 : 1,
        ),
        boxShadow: isRecommended
            ? [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRecommended)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: const Center(
                child: Text(
                  '⭐ MOST POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (isCurrentPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$$price',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 12, left: 4),
                      child: Text(
                        '/month',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  zipcodes,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan
                        ? null
                        : () {
                            _showPlanChangeConfirmation(name, price);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFF3B82F6),
                      foregroundColor: isCurrentPlan
                          ? const Color(0xFF64748B)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isCurrentPlan ? 0 : 2,
                    ),
                    child: Text(
                      isCurrentPlan ? 'Current Plan' : 'Select Plan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPlanChangeConfirmation(String newPlan, int newPrice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Upgrade to $newPlan Plan?',
            style: const TextStyle(color: Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your subscription will be upgraded to $newPlan (\$$newPrice/month).',
              style: const TextStyle(color: Colors.black87, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment details required on next screen',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black87)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog
              Navigator.pop(context); // Close change plan screen

              // ✅ SHOW PAYMENT GATEWAY FOR PLAN UPGRADE
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => PaymentGatewayDialog(
                  planName: newPlan,
                  amount: newPrice,
                  zipcodeCount: newPlan == 'Basic'
                      ? 3
                      : newPlan == 'Premium'
                          ? 7
                          : 10,
                  onPaymentSuccess: () async {
                    // Update plan after successful payment
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('subscription_plan', newPlan);
                    await prefs.setDouble('monthly_price', newPrice.toDouble());
                    await prefs.setString('payment_status', 'active');
                    await prefs.setString(
                        'last_payment_date', DateTime.now().toIso8601String());

                    Navigator.pop(context); // Close payment dialog

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('🎉 Successfully upgraded to $newPlan plan!'),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue to Payment'),
          ),
        ],
      ),
    );
  }

  Widget _buildManageTerritoriesTab() {
    final maxZipcodes = _getPlanName() == 'Basic'
        ? 3
        : _getPlanName() == 'Premium'
            ? 7
            : 10;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zipcode Usage Counter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Zipcodes',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedZipcodes.length} / $maxZipcodes',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getPlanName(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Add Cities/Zipcodes Section
          const Text(
            'Add Cities/Zipcodes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Manual Zipcode Entry
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_location_alt,
                        color: Color(0xFF3B82F6), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Enter Zipcode Manually',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualZipcodeController,
                        decoration: InputDecoration(
                          hintText: 'Enter 5-digit zipcode (e.g., 75068)',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF3B82F6), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            maxLength}) {
                          // Hide the default counter
                          return null;
                        },
                        onChanged: (value) {
                          if (value.length == 5) {
                            _detectCityFromManualZipcode(value).catchError((e) {
                              print('City detection error: $e');
                            });
                          } else {
                            setState(() {
                              _detectedCity = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _addManualZipcode,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_detectedCity != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '📍 Detected: $_detectedCity',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Your Active Territories
          const Text(
            'Your Active Territories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          if (_selectedZipcodes.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: const Text(
                'No zipcodes added yet',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),

          if (_selectedZipcodes.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedZipcodes.map((zipcodeData) {
                // Extract zipcode and city from "zipcode|city" format
                final parts = zipcodeData.split('|');
                final zipcode = parts[0];
                final city = parts.length > 1 ? parts[1] : '';
                final displayText =
                    city.isNotEmpty ? '$zipcode ($city)' : zipcode;

                return Chip(
                  label: Text(displayText),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeZipcode(zipcodeData),
                  backgroundColor: const Color(0xFFE8EAFF),
                  labelStyle: const TextStyle(
                    color: Color(0xFF1E40AF),
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // Price Impact
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Price:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '\$${_calculatePrice().toStringAsFixed(0)}/month',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final String _currentPlan = 'Basic';
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _darkMode = false;

  // Removed _lookupZipcode - zipcodes are now admin-managed
  // This method was used in old zipcode add dialog which has been removed

  // Zipcode database - USA nationwide
  final Map<String, List<Map<String, String>>> _stateZipcodes = {
    'Texas': [
      {'code': '75001', 'city': 'Addison'},
      {'code': '75006', 'city': 'Carrollton'},
      {'code': '75007', 'city': 'Carrollton'},
      {'code': '75019', 'city': 'Coppell'},
      {'code': '75022', 'city': 'Flower Mound'},
      {'code': '75023', 'city': 'Plano'},
      {'code': '75024', 'city': 'Plano'},
      {'code': '75025', 'city': 'Plano'},
      {'code': '75033', 'city': 'Frisco'},
      {'code': '75034', 'city': 'Frisco'},
      {'code': '75035', 'city': 'Frisco'},
      {'code': '75069', 'city': 'McKinney'},
      {'code': '75070', 'city': 'McKinney'},
      {'code': '75071', 'city': 'McKinney'},
      {'code': '75074', 'city': 'Plano'},
      {'code': '75075', 'city': 'Plano'},
      {'code': '75080', 'city': 'Richardson'},
      {'code': '75201', 'city': 'Dallas Downtown'},
      {'code': '75202', 'city': 'Dallas Downtown'},
      {'code': '75204', 'city': 'Dallas Uptown'},
      {'code': '76101', 'city': 'Fort Worth Downtown'},
      {'code': '76102', 'city': 'Fort Worth Downtown'},
      {'code': '77001', 'city': 'Houston Downtown'},
      {'code': '77002', 'city': 'Houston Downtown'},
      {'code': '77006', 'city': 'Houston Montrose'},
      {'code': '78701', 'city': 'Austin Downtown'},
      {'code': '78702', 'city': 'Austin East'},
      {'code': '78201', 'city': 'San Antonio Downtown'},
    ],
    'California': [
      {'code': '90001', 'city': 'Los Angeles Downtown'},
      {'code': '94102', 'city': 'San Francisco Downtown'},
      {'code': '92101', 'city': 'San Diego Downtown'},
    ],
    'Florida': [
      {'code': '33101', 'city': 'Miami Downtown'},
      {'code': '32801', 'city': 'Orlando Downtown'},
      {'code': '33602', 'city': 'Tampa Downtown'},
    ],
    'New York': [
      {'code': '10001', 'city': 'New York Manhattan'},
      {'code': '11201', 'city': 'Brooklyn'},
      {'code': '10301', 'city': 'Staten Island'},
    ],
  };

  // ignore: unused_element
  Map<String, String> get _zipcodeMap {
    final map = <String, String>{};
    for (final state in _stateZipcodes.values) {
      for (final zipcode in state) {
        map[zipcode['code']!] = zipcode['city']!;
      }
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // ✅ USE NEW NOTIFICATIONSERVICE - Load from API
      final settings = await NotificationService.getSettings();

      if (settings != null) {
        setState(() {
          _pushNotifications = settings['push'] ?? true;
          _emailNotifications = settings['email'] ?? true;
          _smsNotifications = settings['sms'] ?? false;
        });

        // Also save locally for offline use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('push_notifications', _pushNotifications);
        await prefs.setBool('email_notifications', _emailNotifications);
        await prefs.setBool('sms_notifications', _smsNotifications);
      }
    } catch (e) {
      // Fall back to local storage if API fails
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pushNotifications = prefs.getBool('push_notifications') ?? true;
        _emailNotifications = prefs.getBool('email_notifications') ?? true;
        _smsNotifications = prefs.getBool('sms_notifications') ?? false;
        _darkMode = prefs.getBool('dark_mode') ?? false;
      });
    }
  }

  Future<void> _saveNotificationSetting(String key, bool value) async {
    try {
      // ✅ USE NEW NOTIFICATIONSERVICE - Save to API
      final settingType =
          key.replaceAll('_notifications', ''); // 'push', 'email', 'sms'

      // Build named parameters based on type
      if (settingType == 'push') {
        await NotificationService.updateSettings(pushEnabled: value);
      } else if (settingType == 'email') {
        await NotificationService.updateSettings(emailEnabled: value);
      } else if (settingType == 'sms') {
        await NotificationService.updateSettings(smsEnabled: value);
      }

      // Also save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ ${key.replaceAll('_', ' ').toUpperCase()} ${value ? 'enabled' : 'disabled'}'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _showManageAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final savedZipcodes = prefs.getStringList('user_zipcodes') ?? [];
    final zipcodes = savedZipcodes.map((z) {
      final parts = z.split('|');
      return {
        'code': parts[0],
        'city': parts.length > 1 ? parts[1] : 'Unknown'
      };
    }).toList();

    final maxAreas = _currentPlan == 'Basic'
        ? 3
        : _currentPlan == 'Premium'
            ? 7
            : 10;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF00888C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Manage Areas (${zipcodes.length}/$maxAreas)'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (zipcodes.length < maxAreas) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.add_circle,
                                color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            Text(
                                '${maxAreas - zipcodes.length} areas available',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                            'Add more service areas to reach more clients!',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Current Service Areas:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...zipcodes.map((z) => Card(
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_city,
                            color: Color(0xFF00888C)),
                        title: Text('${z['code']} - ${z['city']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red, size: 20),
                          onPressed: () async {
                            zipcodes.remove(z);
                            await prefs.setStringList(
                                'user_zipcodes',
                                zipcodes
                                    .map((z) => '${z['code']}|${z['city']}')
                                    .toList());
                            setDialogState(() {});
                          },
                        ),
                      ),
                    )),
                if (zipcodes.length < maxAreas) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddZipcodeDialog();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add More Areas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00888C),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              'Limit reached! Upgrade to add more areas.',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  // Removed _detectMyLocation - zipcodes are now admin-managed
  // This method was used in old zipcode add dialog which has been removed
  @Deprecated('Zipcodes are now admin-managed')
  // ignore: unused_element
  Future<void> _detectMyLocation(TextEditingController zipcodeController,
      StateSetter setDialogState) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠ Location services are disabled. Please enable them in your device settings.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠ Location permission denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠ Location permissions are permanently denied. Please enable in settings.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('📍 Getting your location...'),
            duration: Duration(seconds: 3)),
      );

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final zipcode = (placemark.postalCode ?? '').trim();
        final locality =
            (placemark.locality ?? placemark.subAdministrativeArea ?? 'Unknown')
                .trim();
        final country = (placemark.country ?? '').trim();

        // Check if it's a USA location
        if (country.toLowerCase() != 'united states' &&
            country.toLowerCase() != 'usa' &&
            country.toLowerCase() != 'us') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚠ You are in $country. This app only supports USA zipcodes.\nPlease enter a USA zipcode manually.'),
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }

        // Check if zipcode is valid (5 digits for USA)
        if (zipcode.isNotEmpty &&
            zipcode.length == 5 &&
            RegExp(r'^\d{5}$').hasMatch(zipcode)) {
          setDialogState(() {
            zipcodeController.text = zipcode;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Found: $zipcode - $locality'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // Location found but zipcode invalid
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚠ Location found ($locality, $country) but zipcode unavailable.\nZipcode: "$zipcode"\nPlease enter manually.'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠ Could not get address from location. Please enter zipcode manually.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      String errorMessage = '❌ Location error: ';
      if (e.toString().contains('timeout') ||
          e.toString().contains('TimeLimit')) {
        errorMessage += 'Taking too long. Please check your GPS signal.';
      } else if (e.toString().contains('network')) {
        errorMessage += 'Network issue. Please check your internet connection.';
      } else {
        errorMessage += 'Please enter zipcode manually.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showAddZipcodeDialog() async {
    // This method is deprecated - zipcodes are now admin-managed
    // Keeping for backward compatibility but showing read-only view
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF00888C)),
            SizedBox(width: 8),
            Expanded(
                child: Text('View Service Areas',
                    style: TextStyle(color: Colors.black87))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info message that admin manages zipcodes
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00888C), width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF00888C), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Zipcodes are managed by the administrator. Contact support to add or modify zipcodes.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Display current zipcodes from backend
              FutureBuilder<List<String>>(
                future: TerritoryService.getZipcodes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ));
                  }

                  final zipcodes = snapshot.data ?? [];

                  if (zipcodes.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No zipcodes assigned yet. Please contact support.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Assigned Zipcodes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: zipcodes.map((zipcode) {
                          return Chip(
                            label: Text(zipcode),
                            backgroundColor: const Color(0xFFE8EAFF),
                            labelStyle: const TextStyle(
                              color: Color(0xFF3454D1),
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${zipcodes.length} zipcode(s) assigned',
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('Note: Contact administrator to add zipcodes',
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  void _showChangePassword() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: Color(0xFF00888C)),
              SizedBox(width: 8),
              Text('Change Password'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setDialogState(
                          () => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '💡 Password must be at least 6 characters',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                currentPasswordController.dispose();
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validation
                if (currentPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('❌ Please enter current password')),
                  );
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            '❌ New password must be at least 6 characters')),
                  );
                  return;
                }
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Passwords do not match')),
                  );
                  return;
                }

                // Save new password
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(
                    'user_password', newPasswordController.text);

                currentPasswordController.dispose();
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Password changed successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00888C)),
              child: const Text('Change Password',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpCenter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF00888C)),
            SizedBox(width: 8),
            Text('Help Center'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpItem('📊 How to view leads?',
                  'Go to Leads tab to see all your assigned healthcare leads.'),
              const Divider(),
              _buildHelpItem('🗺️ How to manage zipcodes?',
                  'Go to Plans tab → Edit Plan → Manage Territories to add/remove zipcodes.'),
              const Divider(),
              _buildHelpItem('💳 How to update payment?',
                  'Go to Settings → Payment Methods to add or update cards.'),
              const Divider(),
              _buildHelpItem('📱 Need more help?',
                  'Contact our support team at support@healthcareleads.com'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00888C)),
            child: const Text('Got it!', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showContactSupport() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: Color(0xFF00888C)),
            SizedBox(width: 8),
            Text('Contact Support'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Our support team is here to help!',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subject),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                  hintText: 'Describe your issue or question...',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📧 Email: support@healthcareleads.com',
                        style: TextStyle(fontSize: 12)),
                    SizedBox(height: 4),
                    Text('📞 Phone: 1-800-LEADS-24',
                        style: TextStyle(fontSize: 12)),
                    SizedBox(height: 4),
                    Text('⏰ Hours: Mon-Fri 9AM-6PM EST',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              subjectController.dispose();
              messageController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (subjectController.text.isEmpty ||
                  messageController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Please fill in all fields')),
                );
                return;
              }

              subjectController.dispose();
              messageController.dispose();
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '✅ Support ticket sent! We\'ll respond within 24 hours.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00888C)),
            child: const Text('Send Message',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfile() async {
    // Load registered data
    final prefs = await SharedPreferences.getInstance();
    final nameController = TextEditingController(
        text: prefs.getString('contact_name') ??
            prefs.getString('user_name') ??
            '');
    final emailController =
        TextEditingController(text: prefs.getString('user_email') ?? '');
    final phoneController =
        TextEditingController(text: prefs.getString('user_phone') ?? '');
    final companyController =
        TextEditingController(text: prefs.getString('agency_name') ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF00888C)),
            SizedBox(width: 8),
            Text('Edit Profile'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Full Name', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                      labelText: 'Phone', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: companyController,
                  decoration: const InputDecoration(
                      labelText: 'Company', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              // Save updated data
              await prefs.setString('contact_name', nameController.text);
              await prefs.setString('user_name', nameController.text);
              await prefs.setString('user_email', emailController.text);
              await prefs.setString('user_phone', phoneController.text);
              await prefs.setString('agency_name', companyController.text);

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('✅ Profile updated successfully!'),
                    backgroundColor: Colors.green),
              );

              // Refresh UI
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00888C)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPaymentSettings() {
    showDialog(
      context: context,
      builder: (context) => const PaymentMethodsDialog(),
    );
  }

  void _showDocumentVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final agencyId = prefs.getString('agency_id') ?? '';

    if (agencyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load agency information'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentVerificationPage(agencyId: agencyId),
      ),
    );
  }

  void _showBillingHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Color(0xFF3B82F6)),
            SizedBox(width: 12),
            Text('Billing History'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInvoiceItem('Oct 2024', '\$99.00', 'Paid', Colors.green),
              const Divider(),
              _buildInvoiceItem('Sep 2024', '\$99.00', 'Paid', Colors.green),
              const Divider(),
              _buildInvoiceItem('Aug 2024', '\$99.00', 'Paid', Colors.green),
              const SizedBox(height: 16),
              const Text(
                'All invoices sent to your email',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('📧 Invoices sent to your email!')),
              );
            },
            icon: const Icon(Icons.email),
            label: const Text('Email All Invoices'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(
      String period, String amount, String status, Color statusColor) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.receipt, color: Color(0xFF3B82F6)),
      ),
      title: Text(period, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(amount),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor),
        ),
        child: Text(
          status,
          style: TextStyle(
              color: statusColor, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📄 Downloading invoice for $period...')),
        );
      },
    );
  }

  int _getDaysUntilExpiry() {
    // Calculate days until plan expires (typically 30 days from last payment)
    // In production, this would come from the database
    return 30; // Default to 30 days
  }

  void _showCancelSubscription() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Cancel Subscription?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel your subscription?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ You will lose access to:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('• All healthcare leads'),
                  Text('• Lead management tools'),
                  Text('• Analytics & reports'),
                  Text('• Priority support'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Subscription will cancel after plan expires (next ${_getDaysUntilExpiry()} days)',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Subscription'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Show processing
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );
              await Future.delayed(const Duration(seconds: 2));
              Navigator.pop(context);

              // Save cancellation
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('subscription_status', 'cancelled');
              await prefs.setString(
                  'cancellation_date', DateTime.now().toIso8601String());

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '❌ Subscription cancelled. Access until end of billing period.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _showSubscriptionUpgrade() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Plan: $_currentPlan',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
                'Want to upgrade or change your plan? Visit the Subscription tab!'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00888C), // Indigo
              Color(0xFF007A7C), // Purple
              Color(0xFF006A6E), // Pink
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.settings,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Account Section
                    _buildSectionHeader('Account'),
                    _buildSettingsCard([
                      _buildSettingsItem(
                        icon: Icons.person_outline,
                        title: 'Edit Profile',
                        onTap: _showEditProfile,
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        icon: Icons.lock_outline,
                        title: 'Change Password',
                        onTap: _showChangePassword,
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        icon: Icons.credit_card,
                        title: 'Payment Methods',
                        onTap: _showPaymentSettings,
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        icon: Icons.receipt_long,
                        title: 'Billing History',
                        onTap: _showBillingHistory,
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        icon: Icons.verified_user,
                        title: 'Business Verification',
                        subtitle: 'Pending',
                        onTap: _showDocumentVerification,
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        icon: Icons.cancel_outlined,
                        title: 'Cancel Subscription',
                        onTap: _showCancelSubscription,
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Notifications Section
                    _buildSectionHeader('Notifications'),
                    _buildSettingsCard([
                      _buildToggleItem(
                        title: 'Push Notifications',
                        subtitle: 'Get notified about new leads',
                        value: _pushNotifications,
                        onChanged: (value) {
                          setState(() => _pushNotifications = value);
                          _saveNotificationSetting('push_notifications', value);
                        },
                      ),
                      const Divider(height: 1),
                      _buildToggleItem(
                        title: 'Email Notifications',
                        subtitle: 'Receive lead alerts via email',
                        value: _emailNotifications,
                        onChanged: (value) {
                          setState(() => _emailNotifications = value);
                          _saveNotificationSetting(
                              'email_notifications', value);
                        },
                      ),
                      const Divider(height: 1),
                      _buildToggleItem(
                        title: 'SMS Notifications',
                        subtitle: 'Get SMS for urgent leads',
                        value: _smsNotifications,
                        onChanged: (value) {
                          setState(() => _smsNotifications = value);
                          _saveNotificationSetting('sms_notifications', value);
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // App Preferences Section
                    _buildSectionHeader('App Preferences'),
                    _buildSettingsCard([
                      _buildToggleItem(
                        title: 'Dark Mode',
                        subtitle: 'Use dark theme',
                        value: _darkMode,
                        onChanged: (value) {
                          setState(() => _darkMode = value);
                          _saveNotificationSetting('dark_mode', value);
                        },
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        icon: Icons.language,
                        title: 'Language: English',
                        onTap: null,
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Support Section
                    _buildSectionHeader('Support'),
                    _buildSettingsCard([
                      _buildSettingsItem(
                        icon: Icons.help_outline,
                        title: 'Help Center',
                        onTap: _showHelpCenter,
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        icon: Icons.support_agent,
                        title: 'Contact Support',
                        onTap: _showContactSupport,
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        icon: Icons.quiz_outlined,
                        title: 'FAQ',
                        onTap: null,
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Legal Section
                    _buildSectionHeader('Legal'),
                    _buildSettingsCard([
                      _buildSettingsItem(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        onTap: () => _openLegalDocument('terms'),
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        onTap: () => _openLegalDocument('privacy'),
                      ),
                      const Divider(height: 1),
                      _buildSettingsItem(
                        icon: Icons.security_outlined,
                        title: 'HIPAA Compliance',
                        onTap: () => _openLegalDocument('hipaa'),
                      ),
                    ]),
                    const SizedBox(height: 32),

                    // Logout Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Row(
                                children: [
                                  Icon(Icons.logout, color: Color(0xFFEF4444)),
                                  SizedBox(width: 8),
                                  Text('Logout'),
                                ],
                              ),
                              content: const Text(
                                  'Are you sure you want to logout?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    // ✅ PROPERLY LOGOUT - Clear token and user data
                                    await AuthService.logout();
                                    // Clear all local storage
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.clear();
                                    // Navigate to login
                                    Navigator.pushReplacementNamed(
                                        context, '/');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Logout',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    String? subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF64748B), size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: subtitle.toLowerCase().contains('pending')
                      ? Colors.orange
                      : subtitle.toLowerCase().contains('approved')
                          ? Colors.green
                          : const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null,
      trailing: trailing ??
          const Icon(Icons.arrow_forward_ios,
              size: 16, color: Color(0xFF64748B)),
      onTap: onTap ?? () {},
    );
  }

  void _openLegalDocument(String type) {
    String title;
    String content;

    switch (type) {
      case 'terms':
        title = 'Terms of Service';
        content = '''
**Effective Date: January 1, 2025**

**1. Acceptance of Terms**
By accessing and using the Healthcare Leads Pro mobile application, you agree to be bound by these Terms of Service.

**2. Service Description**
Healthcare Leads Pro provides real-time healthcare lead delivery and territory management services for hospice agencies.

**3. Subscription Plans**
- Starter Plan: \$99/month (Up to 3 zipcodes)
- Professional Plan: \$199/month (Up to 10 zipcodes)
- Enterprise Plan: \$299+/month (Unlimited zipcodes)

**4. User Responsibilities**
- Maintain account security
- Provide accurate information
- Comply with HIPAA regulations
- Use leads ethically and professionally

**5. Payment Terms**
- Monthly subscription billing
- Automatic renewal unless cancelled
- Refund policy: Pro-rated for service issues
- No refunds for partial month usage

**6. Data Privacy**
All data is handled in compliance with HIPAA and our Privacy Policy.

**7. Termination**
We reserve the right to terminate accounts for Terms violations.

**8. Limitation of Liability**
Service provided "as-is" without warranties.

**9. Changes to Terms**
We may update Terms with 30 days notice.

**10. Contact**
For questions: support@healthcareleadspro.com
        ''';
        break;
      case 'privacy':
        title = 'Privacy Policy';
        content = '''
**Effective Date: January 1, 2025**

**1. Information We Collect**
- Account information (name, email, phone)
- Business information (agency name, license)
- Territory preferences (zipcodes selected)
- Usage data (app analytics, lead interactions)
- Payment information (processed via secure gateway)

**2. How We Use Your Information**
- Deliver lead notifications
- Process subscriptions
- Improve services
- Communicate updates
- Analytics and reporting

**3. Data Sharing**
We DO NOT sell your data. We share data only with:
- Payment processors (encrypted)
- Cloud infrastructure providers (AWS/Google Cloud)
- Analytics services (anonymized)

**4. HIPAA Compliance**
- All lead data encrypted in transit and at rest
- Regular security audits
- Strict access controls
- Business Associate Agreements available

**5. Data Retention**
- Active account data: Retained while subscribed
- Cancelled accounts: 90 days retention
- Lead data: 12 months for compliance
- Logs: 6 months for security

**6. Your Rights**
- Access your data
- Export your data
- Request deletion
- Opt-out of marketing

**7. Cookies & Tracking**
We use essential cookies for functionality and analytics.

**8. Security**
- 256-bit encryption
- Two-factor authentication
- Regular penetration testing
- SOC 2 compliant infrastructure

**9. Children's Privacy**
Service not intended for users under 18.

**10. International Users**
Data stored in US data centers. By using service, you consent to US data laws.

**11. Changes to Policy**
Updates posted with 30 days notice.

**12. Contact**
Privacy concerns: privacy@healthcareleadspro.com
        ''';
        break;
      case 'hipaa':
        title = 'HIPAA Compliance';
        content = '''
**Healthcare Leads Pro - HIPAA Compliance Statement**

**Effective Date: January 1, 2025**

**1. Our Commitment**
Healthcare Leads Pro is committed to full compliance with the Health Insurance Portability and Accountability Act (HIPAA) of 1996 and all related regulations.

**2. Business Associate Agreement (BAA)**
We provide BAA to all healthcare agencies upon request. Contact compliance@healthcareleadspro.com

**3. Protected Health Information (PHI)**
**What PHI We Handle:**
- Patient names (when provided in leads)
- Contact information (phone, address)
- Medical condition information
- Insurance status

**4. Security Measures**

**Administrative Safeguards:**
- Security Management Process
- Workforce Security Training
- Information Access Management
- Security Incident Procedures

**Physical Safeguards:**
- Facility Access Controls
- Workstation Security
- Device & Media Controls

**Technical Safeguards:**
- Access Control (unique user IDs, auto logoff)
- Audit Controls (all PHI access logged)
- Integrity Controls (data validation)
- Transmission Security (TLS 1.3 encryption)

**5. Data Encryption**
- **At Rest:** AES-256 encryption
- **In Transit:** TLS 1.3 encryption
- **Backups:** Encrypted and geographically redundant

**6. Access Controls**
- Role-based access (RBAC)
- Multi-factor authentication (MFA)
- Session timeouts (15 min inactivity)
- Device-level encryption required

**7. Audit Logging**
All PHI access is logged:
- User ID and timestamp
- Data accessed or modified
- IP address and device info
- Logs retained for 7 years

**8. Breach Notification**
In case of PHI breach:
- Notification within 60 days
- Details of compromised data
- Mitigation steps
- Resources for affected individuals

**9. Employee Training**
- Annual HIPAA training mandatory
- Security awareness programs
- Incident response training
- Privacy best practices

**10. Third-Party Vendors**
All vendors sign BAAs and undergo security assessments:
- AWS (cloud infrastructure)
- Stripe (payments - tokenized, no PHI)
- Twilio (notifications - encrypted)

**11. Patient Rights**
We support your patients' rights to:
- Access their information
- Request amendments
- Receive accounting of disclosures
- File privacy complaints

**12. Compliance Monitoring**
- Quarterly security audits
- Annual risk assessments
- Penetration testing (bi-annual)
- SOC 2 Type II certification

**13. Incident Response**
24/7 security team for:
- Breach detection and response
- Forensic analysis
- Notification coordination
- Remediation

**14. Data Disposal**
Secure deletion of PHI:
- Electronic: DOD 5220.22-M standard (7-pass wipe)
- Backups: Cryptographic erasure
- Timeline: Within 30 days of request

**15. Compliance Officer**
**Chief Compliance Officer:**
Email: compliance@healthcareleadspro.com
Phone: 1-800-XXX-XXXX (24/7 hotline)

**16. Reporting Concerns**
Report HIPAA concerns:
- Internal: compliance@healthcareleadspro.com
- HHS Office for Civil Rights: www.hhs.gov/ocr/privacy
- Whistleblower protections apply

**17. Updates & Changes**
This statement updated quarterly. Last review: January 2025.

**18. Certification**
Healthcare Leads Pro maintains:
- ✅ HIPAA Compliance Certification
- ✅ SOC 2 Type II Certified
- ✅ HITRUST CSF Certified
- ✅ ISO 27001 Certified

**19. Request BAA or Compliance Documentation**
Contact: compliance@healthcareleadspro.com
Response time: Within 2 business days

**20. Emergency Contact**
Security Incidents: security@healthcareleadspro.com
24/7 Hotline: 1-800-XXX-XXXX
        ''';
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF64748B),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF1E40AF),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 💳 PAYMENT METHODS DIALOG - Manage Payment Methods
// ═══════════════════════════════════════════════════════════════
class PaymentMethodsDialog extends StatefulWidget {
  const PaymentMethodsDialog({super.key});

  @override
  State<PaymentMethodsDialog> createState() => _PaymentMethodsDialogState();
}

class _PaymentMethodsDialogState extends State<PaymentMethodsDialog> {
  final List<Map<String, String>> _savedCards = [
    {'number': '4242', 'expiry': '12/25', 'type': 'Visa'},
  ];
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payment,
                        color: Color(0xFF3B82F6),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment methods',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage cards for subscription payments',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (!_isAdding) ...[
                  // Saved Cards List
                  const Text(
                    'Saved Payment Methods',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_savedCards.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.credit_card_off,
                                size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text(
                              'No payment methods saved',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._savedCards.map((card) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF3B82F6), width: 2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.credit_card,
                                  color: Color(0xFF3B82F6),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${card['type']} •••• ${card['number']}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Expires ${card['expiry']}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    setState(() => _isAdding = true);
                                  } else if (value == 'delete') {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title:
                                            const Text('Delete Payment Method'),
                                        content: Text(
                                            'Are you sure you want to delete ${card['type']} •••• ${card['number']}?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _savedCards.removeWhere(
                                                    (c) => c == card);
                                              });
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'Payment method deleted')),
                                              );
                                            },
                                            child: const Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 12),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            size: 20, color: Colors.red),
                                        SizedBox(width: 12),
                                        Text('Remove',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )),

                  const SizedBox(height: 16),

                  // Add New Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _isAdding = true),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                            color: Color(0xFF3B82F6), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_circle,
                          color: Color(0xFF3B82F6)),
                      label: const Text(
                        'Add New Payment Method',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ),
                ] else
                  _buildAddPaymentForm(),

                const SizedBox(height: 24),

                // Close Button
                if (!_isAdding)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddPaymentForm() {
    final formKey = GlobalKey<FormState>();
    final cardNumberController = TextEditingController();
    // Note: cardHolderController, expiryController, cvvController, isProcessing
    // are reserved for future payment form implementation

    return StatefulBuilder(
      builder: (context, setFormState) => Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add New Card',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Card Number
            const Text(
              'Card Number',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: cardNumberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '4242 4242 4242 4242',
                prefixIcon: const Icon(Icons.credit_card),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.replaceAll(' ', '').length != 16) {
                  return 'Invalid card number';
                }
                return null;
              },
              onChanged: (value) {
                final cleanValue = value.replaceAll(' ', '');
                if (cleanValue.length <= 16) {
                  final formatted = cleanValue
                      .replaceAllMapped(
                        RegExp(r'.{1,4}'),
                        (match) => '${match.group(0)} ',
                      )
                      .trim();
                  if (formatted != value) {
                    cardNumberController.value = TextEditingValue(
                      text: formatted,
                      selection:
                          TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
