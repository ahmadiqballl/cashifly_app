import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/auth_repository.dart';
import '../widgets/cashifly_logo.dart';
import '../widgets/legal_bottom_sheet.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepo = AuthRepository();

  bool _showPasswordField = false;
  bool _obscurePassword = true;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _handleContinue() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _snack('Masukkan alamat email terlebih dahulu.', isError: true);
      return;
    }
    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _snack('Format email tidak valid.', isError: true);
      return;
    }

    if (!_showPasswordField) {
      setState(() => _showPasswordField = true);
      return;
    }

    if (_passwordController.text.isEmpty) {
      _snack('Masukkan kata sandi.', isError: true);
      return;
    }

    setState(() => _isEmailLoading = true);
    try {
      await _authRepo.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
    } catch (e) {
      if (mounted) _snack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _authRepo.signInWithGoogle();
    } catch (e) {
      if (mounted) _snack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 72),

              // ── Logo PNG ──────────────────────────────────────────────────
              const CashiflyLogo(height: 64),
              const SizedBox(height: 12),

              // Tagline — satu baris, warna hitam
              const Text(
                'Mulai kelola keuangan pribadi dengan lebih terstruktur dan aman',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),

              // ── Tombol Google ─────────────────────────────────────────────
              _AuthButton(
                onPressed: _isGoogleLoading ? null : _handleGoogle,
                isLoading: _isGoogleLoading,
                label: 'Google',
                leadingIcon: Image.asset(
                  'assets/icons/logogoogle.png',
                  height: 24,
                  width: 24,
                ),
              ),
              const SizedBox(height: 12),

              // ── Tombol Email ──────────────────────────────────────────────
              _AuthButton(
                onPressed: () =>
                    setState(() => _showPasswordField = !_showPasswordField),
                label: 'Email',
                leadingIcon: const Icon(
                  Icons.mail_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 28),

              // ── Divider ───────────────────────────────────────────────────
              const Divider(
                color: AppColors.textPrimary,
                thickness: 1.2,
                height: 1,
              ),
              const SizedBox(height: 24),

              // ── Form ──────────────────────────────────────────────────────
              _buildForm(),
              const SizedBox(height: 24),

              // ── Link daftar ───────────────────────────────────────────────
              _buildSignupLink(),
              const SizedBox(height: 18),

              // ── Legal ─────────────────────────────────────────────────────
              _buildLegal(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _InputField(
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: _showPasswordField
                ? TextInputAction.next
                : TextInputAction.done,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Masukan alamat email anda...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: false,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use an organization email to easily collaborate with teammates',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),

        if (_showPasswordField) ...[
          const SizedBox(height: 18),
          const Text(
            'Kata Sandi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _InputField(
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleContinue(),
              style:
                  const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Masukan kata sandi anda...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                filled: false,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        _AuthButton(
          onPressed: _isEmailLoading ? null : _handleContinue,
          isLoading: _isEmailLoading,
          label: _showPasswordField ? 'Masuk' : 'Continue',
        ),
      ],
    );
  }

  Widget _buildSignupLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Pengguna Baru? ',
          style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          child: const Text(
            'Daftar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.textPrimary,
              decorationThickness: 1.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegal() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'By continuing, you acknowledge that you understand\nand agree to the ',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12, color: AppColors.textSecondary, height: 1.6),
        ),
        GestureDetector(
          onTap: () => LegalBottomSheet.show(context, LegalType.terms),
          child: const Text('Terms & Conditions',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                  height: 1.6)),
        ),
        const Text(' and ',
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary, height: 1.6)),
        GestureDetector(
          onTap: () => LegalBottomSheet.show(context, LegalType.privacy),
          child: const Text('Privacy Policy.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                  height: 1.6)),
        ),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

/// Tombol utama: fill biru, outline hitam, no shadow.
class _AuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? leadingIcon;
  final bool isLoading;

  const _AuthButton({
    required this.onPressed,
    required this.label,
    this.leadingIcon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(
              color: AppColors.textPrimary,
              width: 1.2,
            ),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: leadingIcon != null
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (leadingIcon != null) ...[
                    const SizedBox(width: 16),
                    leadingIcon!,
                    const Spacer(),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 54), // balance dengan icon area
                  ] else
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Input field: border hitam, no shadow.
class _InputField extends StatelessWidget {
  final Widget child;
  const _InputField({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textPrimary, width: 1.2),
      ),
      child: child,
    );
  }
}

