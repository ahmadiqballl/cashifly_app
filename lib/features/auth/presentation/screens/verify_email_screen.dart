import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/auth_repository.dart';
import '../widgets/custom_button.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _authRepo = AuthRepository();
  bool _isChecking = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  Timer? _countdownTimer;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();

    // Periodically poll Firebase Auth every 4 seconds to detect when user clicks the email link
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkVerificationStatus(showFeedback: false);
    });
  }

  void _startCountdown() {
    setState(() => _resendCountdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerificationStatus({bool showFeedback = true}) async {
    if (_isChecking) return;
    if (showFeedback) setState(() => _isChecking = true);

    final isVerified = await _authRepo.checkEmailVerified();

    if (mounted) {
      if (showFeedback) setState(() => _isChecking = false);

      if (isVerified) {
        _autoCheckTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email berhasil diverifikasi! Selamat datang di Cashifly.'),
            backgroundColor: AppColors.success,
          ),
        );
        // AuthGate will automatically detect the user emailVerified change
      } else if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email belum diverifikasi. Silakan klik link di inbox email Anda.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      await _authRepo.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link verifikasi baru telah dikirimkan ke email Anda.'),
            backgroundColor: AppColors.success,
          ),
        );
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authRepo.currentUser;
    final userEmail = user?.email ?? 'email Anda';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            tooltip: 'Ganti Akun / Keluar',
            onPressed: () => _authRepo.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 46,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Periksa Email Anda',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kami telah mengirimkan link verifikasi akun ke:',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                userEmail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Buka email Anda dan klik link verifikasi tersebut. Halaman ini akan otomatis beralih setelah terverifikasi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Catatan: Email dikirim oleh noreply@cashifly-id.firebaseapp.com. Jika tidak muncul di Kotak Masuk utama, harap cek folder Spam, Junk, atau tab Promosi.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Button: Manual Check
              CustomButton(
                text: 'Saya Sudah Klik Link Verifikasi',
                onPressed: () => _checkVerificationStatus(showFeedback: true),
                isLoading: _isChecking,
              ),
              const SizedBox(height: 16),

              // Button: Resend Email
              OutlinedButton.icon(
                onPressed: _resendCountdown > 0 ? null : _resendVerificationEmail,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  _resendCountdown > 0
                      ? 'Kirim Ulang Link ($_resendCountdown s)'
                      : (_isResending ? 'Mengirim...' : 'Kirim Ulang Email Verifikasi'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Sign Out option
              TextButton(
                onPressed: () => _authRepo.signOut(),
                child: const Text(
                  'Gunakan Email Lain (Keluar)',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
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
