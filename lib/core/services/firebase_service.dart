import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

class FirebaseService {
  static Future<void> initialize() async {
    try {
      // First try native config (e.g. google-services.json on Android)
      await Firebase.initializeApp();
    } catch (_) {
      try {
        // Fallback to Dart FirebaseOptions if native config is not yet placed
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        debugPrint('Firebase initialization warning: $e');
        rethrow;
      }
    }
  }
}
