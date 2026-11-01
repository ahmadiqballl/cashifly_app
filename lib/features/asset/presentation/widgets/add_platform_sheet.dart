import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/models/asset_platform_model.dart';
import '../../../../core/database/repositories/asset_repository.dart';

/// Bottom sheet untuk menambah platform baru (Bank atau E-Wallet).
/// Cash tidak bisa ditambah ulang karena sudah default.
class AddPlatformSheet extends StatefulWidget {
  final String userId;

  /// Nama-nama platform yang sudah ada (untuk cek duplikat)
  final List<String> existingNames;

  const AddPlatformSheet({
    super.key,
    required this.userId,
    required this.existingNames,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String userId,
    required List<String> existingNames,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddPlatformSheet(
        userId: userId,
        existingNames: existingNames,
      ),
    );
  }

  @override
  State<AddPlatformSheet> createState() => _AddPlatformSheetState();
}

class _AddPlatformSheetState extends State<AddPlatformSheet> {
  final _repo = AssetRepository();

  PlatformType _selectedType = PlatformType.bank;
  BankOption? _selectedBank = BankOption.bri;
  EWalletOption? _selectedEWallet = EWalletOption.gopay;
  bool _isSaving = false;

  Future<void> _handleAdd() async {
    final name = _selectedType == PlatformType.bank
        ? _selectedBank?.label
        : _selectedEWallet?.label;

    if (name == null) return;

    // Cek duplikat
    if (widget.existingNames
        .any((n) => n.toLowerCase() == name.toLowerCase())) {
      _showSnack('Platform "$name" sudah ditambahkan.');
      return;
    }

    // Warna berdasarkan brand platform
    final colorValue = PlatformColors.colorFor(_selectedType, name);

    setState(() => _isSaving = true);
    try {
      await _repo.insert(AssetPlatform(
        userId: widget.userId,
        type: _selectedType,
        name: name,
        balance: 0,
        colorValue: colorValue,
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showSnack('Gagal menambahkan: $e');
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Judul
          const Text(
            'Tambah Platform Baru',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Toggle tipe: Bank / E-Wallet
          Row(
            children: [
              Expanded(
                child: _TypeToggle(
                  label: 'Bank',
                  isSelected: _selectedType == PlatformType.bank,
                  onTap: () =>
                      setState(() => _selectedType = PlatformType.bank),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TypeToggle(
                  label: 'E-Wallet',
                  isSelected: _selectedType == PlatformType.ewallet,
                  onTap: () =>
                      setState(() => _selectedType = PlatformType.ewallet),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Label pilihan
          Text(
            _selectedType == PlatformType.bank
                ? 'Pilih Bank'
                : 'Pilih E-Wallet',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // Dropdown
          if (_selectedType == PlatformType.bank)
            _buildBankDropdown()
          else
            _buildEWalletDropdown(),

          const SizedBox(height: 28),

          // Tombol Tambahkan
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(
                      color: AppColors.textPrimary, width: 1.2),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'Tambahkan',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textPrimary, width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BankOption>(
          value: _selectedBank,
          isExpanded: true,
          style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontFamily: 'SFProDisplay'),
          items: BankOption.values
              .map((b) => DropdownMenuItem(
                    value: b,
                    child: Text(b.label),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedBank = v),
        ),
      ),
    );
  }

  Widget _buildEWalletDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textPrimary, width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<EWalletOption>(
          value: _selectedEWallet,
          isExpanded: true,
          style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontFamily: 'SFProDisplay'),
          items: EWalletOption.values
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.label),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedEWallet = v),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.textPrimary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
