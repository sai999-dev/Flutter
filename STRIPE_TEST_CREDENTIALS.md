# 💳 Stripe Test Credentials and Setup

This app is wired for Stripe test mode. Only the publishable key is included in the mobile app. All secret-key operations happen on the middleware server.

## Keys (Test Mode)

- Publishable key (mobile): `pk_test_51NXXXXXXXXXXXXXXdummypublishablekeyXXXXXXXXXXXXXX`
- Secret key (server only): Keep in middleware environment, never in the app.
- Apple Pay merchant identifier (iOS): `merchant.com.example.app`

Update `flutter-frontend/lib/stripe_config.dart` to change these values.

## Test Cards

Use any of these cards while in test mode:

- Success: 4242 4242 4242 4242
- Decline: 4000 0000 0000 0002
- Expired card: 4000 0000 0000 0069
- Insufficient funds: 4000 0000 0000 9995

Use any future expiry (e.g., 12/30) and any 3-digit CVC.

## Mobile Flow

1) App collects card details using Stripe CardField
2) App creates a PaymentMethod (client-only)
3) App includes `payment_method_id` in the registration payload (or saves it and updates later)
4) Middleware attaches the PaymentMethod to the customer and creates the subscription

## Server Responsibilities (Middleware)

- Store Stripe secret keys securely
- Create Customer/Subscription/PaymentIntent
- Attach PaymentMethods and handle webhooks
- Return subscription state and invoices to the app endpoints

## Switching to Live

1) Replace publishable key in `stripe_config.dart`
2) Switch secret keys in middleware environment
3) Verify Apple Pay / Google Pay configurations
4) Run end-to-end test on production-like environment

Last Updated: 2025-11-05
