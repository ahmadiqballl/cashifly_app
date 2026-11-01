import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../data/auth_repository.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

/// AuthGate serves as the security guard for routing.
/// Unauthenticated users are routed to LoginScreen.
/// Users whose email is not yet verified are directed to VerifyEmailScreen.
/// Verified users are directed straight to DashboardScreen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepo = AuthRepository();

    return StreamBuilder<User?>(
      stream: authRepo.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        // If user logged in via password and hasn't verified email yet,
        // route them to verify email screen
        if (!user.emailVerified) {
          return const VerifyEmailScreen();
        }

        return const DashboardScreen();
      },
    );
  }
}
