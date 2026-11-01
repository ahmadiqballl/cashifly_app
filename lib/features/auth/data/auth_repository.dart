import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  static const String _webClientId =
      '767120884210-k1s6715ogk55l3ivfd2gghi4vehkculu.apps.googleusercontent.com';

  AuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: _webClientId,
            );

  User? get currentUser => _auth.currentUser;

  /// Stream of user state changes (detects login, logout, and email verification updates)
  Stream<User?> get authStateChanges => _auth.userChanges();

  /// Register user with Email and Password, and automatically send an email verification link
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Automatically dispatch verification link to the newly registered email
      try {
        await credential.user?.sendEmailVerification();
        debugPrint('Email verifikasi berhasil dikirim ke: ${credential.user?.email}');
      } catch (emailErr) {
        debugPrint('Gagal mengirim email verifikasi otomatis: $emailErr');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      throw 'Terjadi kesalahan saat pendaftaran: $e';
    }
  }

  /// Resend email verification link to current user
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      throw 'Gagal mengirim ulang email verifikasi: $e';
    }
  }

  /// Reload current user profile to verify whether email has been verified
  Future<bool> checkEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        return _auth.currentUser?.emailVerified ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error reloading user: $e');
      return false;
    }
  }

  /// Sign In with Email and Password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      throw 'Terjadi kesalahan saat login: $e';
    }
  }

  /// Sign In via Google OAuth using Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in flow
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw 'Token autentikasi Google kosong. Pastikan SHA-1 sidik jari debug telah terdaftar di Firebase Console.';
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException on Google Sign In: ${e.code} - ${e.message}');
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      final err = e.toString();
      if (err.contains('10') || err.contains('DEVELOPER_ERROR')) {
        throw 'Google Sign-In Error 10 (DEVELOPER_ERROR): SHA-1 sidik jari debug belum ditambahkan di Firebase Console atau google-services.json belum diperbarui.';
      }
      throw 'Login Google gagal: $e';
    }
  }

  /// Sign Out current user from Firebase & Google
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw 'Gagal keluar: $e';
    }
  }

  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Akun dengan email ini tidak ditemukan.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Kata sandi atau email salah.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan gunakan email lain atau login.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan gagal. Silakan coba lagi nanti.';
      default:
        return e.message ?? 'Terjadi kesalahan autentikasi.';
    }
  }
}
