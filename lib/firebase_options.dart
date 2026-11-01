// File generated or configured for Firebase options.
// Configured with credentials from android/app/google-services.json

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
        // Fallback for desktop testing environments to prevent crashing
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDZjDyR7yTRnrzQjo_wuX0bE0FciRNI2j0',
    appId: '1:767120884210:android:a7f5664958295bb1c1ab6b',
    messagingSenderId: '767120884210',
    projectId: 'cashifly-id',
    storageBucket: 'cashifly-id.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDZjDyR7yTRnrzQjo_wuX0bE0FciRNI2j0',
    appId: '1:767120884210:ios:a7f5664958295bb1c1ab6b',
    messagingSenderId: '767120884210',
    projectId: 'cashifly-id',
    storageBucket: 'cashifly-id.firebasestorage.app',
    iosBundleId: 'com.id.cashifly',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDZjDyR7yTRnrzQjo_wuX0bE0FciRNI2j0',
    appId: '1:767120884210:web:a7f5664958295bb1c1ab6b',
    messagingSenderId: '767120884210',
    projectId: 'cashifly-id',
    storageBucket: 'cashifly-id.firebasestorage.app',
  );
}
