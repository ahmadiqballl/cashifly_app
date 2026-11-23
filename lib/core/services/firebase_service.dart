import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// ============================================================================
/// FirebaseService
/// ============================================================================
/// Layanan inisialisasi awal Firebase Core untuk seluruh aplikasi.
///
/// Menggunakan pendekatan *fail-safe initialization*:
/// 1. Mencoba inisialisasi native (menggunakan file `google-services.json` di Android).
/// 2. Jika konfigurasi native belum terpasang atau berjalan di platform lain,
///    sistem melakukan fallback ke `DefaultFirebaseOptions.currentPlatform`.
class FirebaseService {
  /// Menginisialisasi koneksi SDK Firebase saat bootstrap aplikasi di `main.dart`.
  static Future<void> initialize() async {
    try {
      // Prioritas 1: Inisialisasi otomatis membaca konfigurasi native Android/iOS
      await Firebase.initializeApp();
    } catch (_) {
      try {
        // Prioritas 2: Fallback membaca konfigurasi dari Dart options (firebase_options.dart)
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
