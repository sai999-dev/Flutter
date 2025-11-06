// Stripe configuration for the mobile app
// IMPORTANT: Only publishable key is stored here. Secret keys must NEVER be in the client app.

class StripeConfig {
  // Dummy test publishable key (replace in production)
  // This is a sample format; update to your real test key when available.
  static const String publishableKey =
      'pk_test_51NXXXXXXXXXXXXXXdummypublishablekeyXXXXXXXXXXXXXX';

  // Optional: Used for Apple Pay merchant ID on iOS
  static const String merchantIdentifier = 'merchant.com.example.app';

  // Toggle to enable/disable Stripe test mode banners in UI
  static const bool showTestModeBanners = true;
}
