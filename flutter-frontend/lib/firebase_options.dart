// File: lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Web Firebase configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCu_A28oTprIh7cdibGpmTRjrbmXbKsYbY",
    authDomain: "leadsmarketplace-21a96.firebaseapp.com",
    projectId: "leadsmarketplace-21a96",
    storageBucket: "leadsmarketplace-21a96.firebasestorage.app",
    messagingSenderId: "695100379940",
    appId: "1:695100379940:web:934baffa63561956c3d9b1",
    measurementId: "G-VEQCV6EJ5T",
  );

  /// Android (fill if needed)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "",
    appId: "",
    messagingSenderId: "",
    projectId: "",
    storageBucket: "",
  );

  /// iOS (fill if needed)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "",
    appId: "",
    messagingSenderId: "",
    projectId: "",
    storageBucket: "",
    iosBundleId: "",
  );
}
