import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/data/auth_repository.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _authRepo = AuthRepository();

  // ── Edit Name ──────────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isSavingName = false;

  // ── Change Password ────────────────────────────────────────────────────────
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _isSavingPassword = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = _authRepo.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Nama tidak boleh kosong.', isError: true);
      return;
    }
    setState(() => _isSavingName = true);
    try {
      await _authRepo.updateDisplayName(name);
      setState(() => _isEditingName = false);
      _showSnack('Nama berhasil diperbarui.');
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _savePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isSavingPassword = true);
    try {
      await _authRepo.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnack('Kata sandi berhasil diperbarui.');
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Konfirmasi Keluar',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceDark,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.textPrimary, width: 1),
              ),
            ),
            child: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _authRepo.signOut();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = _authRepo.currentUser;
    final isEmailProvider =
        user?.providerData.any((p) => p.providerId == 'password') ?? false;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        // ── Avatar ───────────────────────────────────────────────────────────
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textPrimary, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              _getInitials(user?.displayName ?? user?.email ?? 'U'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Name below avatar
        Center(
          child: Text(
            user?.displayName?.isNotEmpty == true
                ? user!.displayName!
                : user?.email ?? '-',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Section: Informasi Pribadi ────────────────────────────────────────
        _sectionHeader('Informasi Pribadi'),
        _card(children: [
          // Nama
          _fieldRow(
            icon: Icons.person_outline,
            child: _isEditingName
                ? TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 6),
                      hintText: 'Masukkan nama',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 1),
                      ),
                      filled: false,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nama',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.displayName?.isNotEmpty == true
                            ? user!.displayName!
                            : '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
            trailing: _isEditingName
                ? (_isSavingName
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline,
                                color: Colors.white),
                            onPressed: _saveName,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(Icons.cancel_outlined,
                                color: Colors.white.withValues(alpha: 0.6)),
                            onPressed: () => setState(() {
                              _isEditingName = false;
                              _nameController.text =
                                  user?.displayName ?? '';
                            }),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ))
                : IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: Colors.white),
                    onPressed: () => setState(() => _isEditingName = true),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
          ),

          Divider(height: 20, color: Colors.white.withValues(alpha: 0.2)),

          // Email
          _fieldRow(
            icon: Icons.email_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // ── Section: Keamanan ─────────────────────────────────────────────────
        _sectionHeader('Keamanan'),
        if (!isEmailProvider)
          _card(children: [
            _fieldRow(
              icon: Icons.lock_outline,
              child: Text(
                'Ubah kata sandi tidak tersedia untuk akun Google.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ])
        else
          _card(children: [
            Form(
              key: _passwordFormKey,
              child: Column(
                children: [
                  _buildPasswordField(
                    controller: _currentPasswordController,
                    label: 'Kata Sandi Saat Ini',
                    icon: Icons.lock_outline,
                    obscure: !_showCurrentPassword,
                    onToggle: () => setState(
                        () => _showCurrentPassword = !_showCurrentPassword),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Masukkan kata sandi saat ini'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildPasswordField(
                    controller: _newPasswordController,
                    label: 'Kata Sandi Baru',
                    icon: Icons.lock_reset_outlined,
                    obscure: !_showNewPassword,
                    onToggle: () =>
                        setState(() => _showNewPassword = !_showNewPassword),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Masukkan kata sandi baru';
                      if (v.length < 6) return 'Minimal 6 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: 'Konfirmasi Kata Sandi Baru',
                    icon: Icons.verified_outlined,
                    obscure: !_showConfirmPassword,
                    onToggle: () => setState(
                        () => _showConfirmPassword = !_showConfirmPassword),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Konfirmasi kata sandi baru';
                      if (v != _newPasswordController.text) return 'Kata sandi tidak cocok';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isSavingPassword ? null : _savePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        disabledBackgroundColor:
                            Colors.white.withValues(alpha: 0.4),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                              color: AppColors.textPrimary, width: 1.2),
                        ),
                      ),
                      child: _isSavingPassword
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textPrimary),
                            )
                          : const Text(
                              'Simpan Kata Sandi',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ]),

        const SizedBox(height: 12),

        // ── Tombol Keluar ─────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _handleSignOut,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceDark,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(
                    color: AppColors.textPrimary, width: 1.2),
              ),
            ),
            child: const Text(
              'Keluar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  /// Box biru dengan outline hitam.
  Widget _card({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textPrimary, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// Row dengan ikon + konten + optional trailing.
  Widget _fieldRow({
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 12),
        Expanded(child: child),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }

  /// Password field styled untuk background biru.
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
        prefixIcon:
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.white.withValues(alpha: 0.7),
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      ),
      validator: validator,
    );
  }
}
