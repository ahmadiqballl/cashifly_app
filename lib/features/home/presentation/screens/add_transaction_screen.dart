import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/models/asset_platform_model.dart';
import '../../../../core/database/models/transaction_model.dart';
import '../../../../core/database/repositories/asset_repository.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/services/notification_service.dart';
import '../../../asset/presentation/screens/asset_detail_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  /// [initialType] menentukan apakah layar dibuka untuk pengeluaran atau pemasukan.
  final TransactionType initialType;

  const AddTransactionScreen({
    super.key,
    required this.initialType,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _assetRepo = AssetRepository();
  final _txRepo = TransactionRepository();
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocus = FocusNode();

  late TransactionType _type;
  List<AssetPlatform> _platforms = [];
  AssetPlatform? _selectedPlatform;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _loadPlatforms();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPlatforms() async {
    if (_userId.isEmpty) return;
    final platforms = await _assetRepo.getAll(_userId);
    if (mounted) {
      setState(() {
        _platforms = platforms;
        _selectedPlatform = platforms.isNotEmpty ? platforms.first : null;
        _isLoading = false;
      });
    }
  }

  // ── Format rupiah tanpa "Rp" prefix untuk tampilan di field ────────────────
  String _formatRupiah(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
      count++;
    }
    final formattedInt = buffer.toString().split('').reversed.join();
    return 'Rp$formattedInt,$decPart';
  }

  Future<void> _handleSave() async {
    final rawText = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(rawText);

    if (amount == null || amount <= 0) {
      _showSnack('Masukkan nominal yang valid (harus lebih dari 0).');
      return;
    }
    if (_selectedPlatform == null) {
      _showSnack('Pilih platform aset terlebih dahulu.');
      return;
    }

    // Cek saldo cukup untuk pengeluaran
    if (_type == TransactionType.expense &&
        _selectedPlatform!.balance < amount) {
      _showInsufficientBalanceDialog(_selectedPlatform!.balance, amount);
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Ambil total sebelum transaksi
      final totalSebelum = await _assetRepo.totalBalance(_userId);

      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${today.hour.toString().padLeft(2, '0')}:${today.minute.toString().padLeft(2, '0')}';

      final tx = TransactionModel(
        userId: _userId,
        type: _type,
        amount: amount,
        category: _type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran',
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        date: dateStr,
        time: timeStr,
        platformId: _selectedPlatform!.id,
      );

      await _txRepo.insertWithBalanceUpdate(
        transaction: tx,
        platform: _selectedPlatform!,
      );

      // Ambil total sesudah transaksi
      final totalSesudah = await _assetRepo.totalBalance(_userId);

      // Cek apakah ada kelipatan 100.000 yang dilewati
      await _checkMilestone(totalSebelum, totalSesudah);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showSnack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  /// Cek apakah total aset melewati kelipatan 100.000 antara [sebelum] dan [sesudah].
  /// Jika iya, tampilkan notifikasi dengan total terbaru.
  Future<void> _checkMilestone(double sebelum, double sesudah) async {
    const step = 100000.0;
    // Kelipatan 100rb tertinggi yang sudah dicapai sebelum transaksi
    final batasSebelum = sebelum <= 0 ? 0 : (sebelum / step).floor() * step;
    // Kelipatan 100rb tertinggi setelah transaksi
    final batasSesudah = (sesudah / step).floor() * step;

    if (batasSesudah > batasSebelum) {
      // Ada kelipatan baru yang terlewati — kirim notifikasi
      await NotificationService.instance
          .showMilestone(sesudah, userId: _userId);
    }
  }

  void _showInsufficientBalanceDialog(double currentBalance, double requested) {
    final platformName = _selectedPlatform?.name ?? 'platform ini';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Saldo Tidak Cukup',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Saldo $platformName saat ini ${_formatRupiah(currentBalance)}, '
          'kurang dari nominal pengeluaran ${_formatRupiah(requested)}. '
          'Tambahkan pemasukan terlebih dahulu.',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(
                    color: AppColors.textPrimary, width: 1.2),
              ),
            ),
            child: const Text(
              'Mengerti',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Singkat nama platform untuk kotak warna ────────────────────────────────
  String _shortLabel(String name) {
    if (name == 'Uang Cash') return 'Cash';
    if (name.startsWith('Bank ')) return name.substring(5);
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _type == TransactionType.expense;
    final iconColor = isExpense ? AppColors.error : AppColors.success;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.accent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/icons/logo.png',
              height: 26,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Judul halaman ──────────────────────────────────────
                    Text(
                      isExpense ? 'Tambah Pengeluaran' : 'Tambah Pemasukan',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isExpense
                          ? 'Kurangi saldo dari platform aset'
                          : 'Tambah saldo ke platform aset',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Toggle Pengeluaran / Pemasukan ─────────────────────
                    _buildTypeToggle(),
                    const SizedBox(height: 28),

                    // ── Label Nominal ─────────────────────────────────────
                    _buildSectionLabel('Nominal'),
                    const SizedBox(height: 10),
                    _buildAmountField(iconColor),
                    const SizedBox(height: 22),

                    // ── Label Pilih Platform ───────────────────────────────
                    _buildSectionLabel('Platform Aset'),
                    const SizedBox(height: 10),
                    _platforms.isEmpty
                        ? _buildNoPlatformBanner()
                        : _buildPlatformList(),
                    const SizedBox(height: 22),

                    // ── Label Keterangan ───────────────────────────────────
                    _buildSectionLabel('Keterangan (opsional)'),
                    const SizedBox(height: 10),
                    _buildNoteField(),
                    const SizedBox(height: 36),

                    // ── Tombol Simpan ──────────────────────────────────────
                    _buildSaveButton(isExpense, iconColor),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textPrimary, width: 1.2),
      ),
      child: Row(
        children: [
          _TypeChip(
            label: 'Pengeluaran',
            icon: Icons.arrow_upward_rounded,
            iconColor: AppColors.error,
            isSelected: _type == TransactionType.expense,
            onTap: () => setState(() => _type = TransactionType.expense),
          ),
          _TypeChip(
            label: 'Pemasukan',
            icon: Icons.arrow_downward_rounded,
            iconColor: AppColors.success,
            isSelected: _type == TransactionType.income,
            onTap: () => setState(() => _type = TransactionType.income),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField(Color iconColor) {
    return TextFormField(
      controller: _amountController,
      focusNode: _amountFocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
      ],
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.normal,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.normal,
          color: AppColors.textMuted,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 18, right: 12),
          child: Icon(
            _type == TransactionType.expense
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: iconColor,
            size: 22,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        filled: true,
        fillColor: AppColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderInput, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildNoPlatformBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Belum ada platform aset.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tambahkan bank atau e-wallet terlebih dahulu di halaman Rincian Aset.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const AssetDetailScreen()),
                );
                await _loadPlatforms();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                      color: AppColors.textPrimary, width: 1.2),
                ),
              ),
              child: const Text(
                'Buka Rincian Aset',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformList() {
    return Column(
      children: _platforms.map((p) {
        final isSelected = _selectedPlatform?.id == p.id;
        final color = Color(p.colorValue);
        return GestureDetector(
          onTap: () => setState(() => _selectedPlatform = p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // ── Kotak warna platform ──────────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _shortLabel(p.name),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Nama + saldo ──────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatRupiah(p.balance),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Indikator terpilih ────────────────────────────────────
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.accent, size: 22),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      maxLines: 3,
      minLines: 2,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w400,
      ),
      decoration: const InputDecoration(
        hintText: 'Tambahkan keterangan...',
        contentPadding:
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        filled: true,
        fillColor: AppColors.surface,
      ),
    );
  }

  Widget _buildSaveButton(bool isExpense, Color iconColor) {
    final isEmpty = _platforms.isEmpty;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: (_isSaving || isEmpty) ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEmpty ? AppColors.border : AppColors.accent,
          foregroundColor: isEmpty ? AppColors.textMuted : Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isEmpty ? AppColors.border : AppColors.textPrimary,
              width: 1.2,
            ),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpense
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: isEmpty ? AppColors.textMuted : iconColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExpense ? 'Simpan Pengeluaran' : 'Simpan Pemasukan',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Type chip ──────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.all(4),
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: AppColors.textPrimary, width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? iconColor : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
