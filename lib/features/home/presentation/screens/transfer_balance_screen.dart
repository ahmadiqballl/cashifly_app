import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/models/asset_platform_model.dart';
import '../../../../core/database/models/transaction_model.dart';
import '../../../../core/database/repositories/asset_repository.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/services/image_service.dart';
import '../../../asset/presentation/widgets/add_platform_sheet.dart';

class TransferBalanceScreen extends StatefulWidget {
  const TransferBalanceScreen({super.key});

  @override
  State<TransferBalanceScreen> createState() => _TransferBalanceScreenState();
}

class _TransferBalanceScreenState extends State<TransferBalanceScreen> {
  final _assetRepo = AssetRepository();
  final _txRepo = TransactionRepository();
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocus = FocusNode();

  List<AssetPlatform> _platforms = [];
  AssetPlatform? _fromPlatform;
  AssetPlatform? _toPlatform;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
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
    await _assetRepo.initDefaultCash(_userId);
    final platforms = await _assetRepo.getAll(_userId);
    if (!mounted) return;

    setState(() {
      _platforms = platforms;
      if (platforms.length >= 2) {
        _fromPlatform = platforms[0];
        _toPlatform = platforms[1];
      } else if (platforms.length == 1) {
        _fromPlatform = platforms[0];
        _toPlatform = null;
      }
      _isLoading = false;
    });
  }

  String _formatRupiah(double amount) {
    final intPart = amount.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
      count++;
    }
    return 'Rp${buffer.toString().split('').reversed.join()}';
  }

  String _shortLabel(String name) {
    if (name == 'Uang Cash') return 'Cash';
    if (name.startsWith('Bank ')) return name.substring(5);
    return name;
  }

  void _swapPlatforms() {
    if (_fromPlatform == null || _toPlatform == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      final temp = _fromPlatform;
      _fromPlatform = _toPlatform;
      _toPlatform = temp;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final path = await ImageService.instance.pickAndCompress(source);
    if (path != null && mounted) {
      setState(() => _imagePath = path);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Pilih sumber bukti transfer',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.accentDark),
                title: const Text('Kamera',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.accentDark),
                title: const Text('Galeri Foto',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage() {
    ImageService.instance.deleteImage(_imagePath);
    setState(() => _imagePath = null);
  }

  void _selectPlatform({required bool isFrom}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isFrom ? 'Pilih Platform Asal (Sumber)' : 'Pilih Platform Tujuan',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _platforms.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = _platforms[i];
                    final isCurrentSelected = isFrom
                        ? _fromPlatform?.id == p.id
                        : _toPlatform?.id == p.id;
                    final isOppositeSelected = isFrom
                        ? _toPlatform?.id == p.id
                        : _fromPlatform?.id == p.id;

                    return ListTile(
                      onTap: () {
                        setState(() {
                          if (isFrom) {
                            if (_toPlatform?.id == p.id) {
                              // Tukar jika memilih platform yang sama dengan tujuan
                              _toPlatform = _fromPlatform;
                            }
                            _fromPlatform = p;
                          } else {
                            if (_fromPlatform?.id == p.id) {
                              // Tukar jika memilih platform yang sama dengan asal
                              _fromPlatform = _toPlatform;
                            }
                            _toPlatform = p;
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(p.colorValue),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _shortLabel(p.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Saldo: ${_formatRupiah(p.balance)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: isCurrentSelected
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.accent, size: 22)
                          : (isOppositeSelected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isFrom ? 'Tujuan' : 'Sumber',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                )
                              : null),
                      tileColor: isCurrentSelected
                          ? AppColors.primaryLight.withValues(alpha: 0.5)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isCurrentSelected
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTransfer() async {
    if (_fromPlatform == null || _toPlatform == null) {
      _showSnack('Pilih platform asal dan tujuan terlebih dahulu.');
      return;
    }

    if (_fromPlatform!.id == _toPlatform!.id) {
      _showSnack('Platform asal dan tujuan tidak boleh sama.');
      return;
    }

    final rawText = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(rawText);

    if (amount == null || amount <= 0) {
      _showSnack('Masukkan nominal pindah saldo yang valid.');
      return;
    }

    if (_fromPlatform!.balance < amount) {
      _showInsufficientBalanceDialog(_fromPlatform!.balance, amount);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final userNote = _noteController.text.trim();
      final noteCombined = userNote.isNotEmpty
          ? 'Dari ${_fromPlatform!.name} ke ${_toPlatform!.name} · $userNote'
          : 'Dari ${_fromPlatform!.name} ke ${_toPlatform!.name}';

      final tx = TransactionModel(
        userId: _userId,
        type: TransactionType.transfer,
        amount: amount,
        category: 'Pindah Saldo',
        note: noteCombined,
        date: dateStr,
        time: timeStr,
        imagePath: _imagePath,
        platformId: _fromPlatform!.id,
        toPlatformId: _toPlatform!.id,
      );

      await _txRepo.transferWithBalanceUpdate(
        transaction: tx,
        fromPlatform: _fromPlatform!,
        toPlatform: _toPlatform!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil memindahkan ${_formatRupiah(amount)} ke ${_toPlatform!.name}',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) _showSnack('Gagal memindahkan saldo: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showInsufficientBalanceDialog(double balance, double amount) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saldo Tidak Mencukupi'),
        content: Text(
          'Saldo di "${_fromPlatform!.name}" adalah ${_formatRupiah(balance)}, '
          'sedangkan nominal yang ingin dipindahkan adalah ${_formatRupiah(amount)}.\n\n'
          'Silakan kurangi nominal atau pilih platform sumber lainnya.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Layar ───────────────────────────────────────
                    Row(
                      children: [
                        Image.asset(
                          'assets/icons/transfer_saldo.png',
                          width: 28,
                          height: 28,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Pindah Saldo',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pindahkan saldo antar akun bank, dompet digital, atau uang cash.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Jika user punya kurang dari 2 platform
                    if (_platforms.length < 2)
                      _buildNeedMorePlatformsBanner()
                    else ...[
                      // ── Platform Selector (Dari → Ke) ────────────────────
                      _buildTransferPlatformCard(),
                      const SizedBox(height: 24),

                      // ── Nominal ──────────────────────────────────────────
                      _buildSectionLabel('Nominal Pindah Saldo'),
                      const SizedBox(height: 10),
                      _buildAmountField(),
                      const SizedBox(height: 10),
                      _buildQuickAmountChips(),
                      const SizedBox(height: 22),

                      // ── Keterangan ───────────────────────────────────────
                      _buildSectionLabel('Keterangan (opsional)'),
                      const SizedBox(height: 10),
                      _buildNoteField(),
                      const SizedBox(height: 22),

                      // ── Bukti Transfer ───────────────────────────────────
                      _buildSectionLabel('Bukti Transfer / Struk (opsional)'),
                      const SizedBox(height: 10),
                      _buildImagePicker(),
                      const SizedBox(height: 32),

                      // ── Tombol Simpan ────────────────────────────────────
                      _buildTransferButton(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

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

  Widget _buildTransferPlatformCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Sumber (Dari) ────────────────────────────────────────────────
          _buildPlatformTile(
            title: 'Dari Platform (Sumber Saldo)',
            platform: _fromPlatform,
            isFrom: true,
          ),

          // ── Divider dengan Tombol Swap ───────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              const Divider(color: AppColors.border, height: 1, thickness: 1),
              GestureDetector(
                onTap: _swapPlatforms,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),

          // ── Tujuan (Ke) ──────────────────────────────────────────────────
          _buildPlatformTile(
            title: 'Ke Platform (Tujuan)',
            platform: _toPlatform,
            isFrom: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformTile({
    required String title,
    required AssetPlatform? platform,
    required bool isFrom,
  }) {
    final color = platform != null ? Color(platform.colorValue) : AppColors.textMuted;

    return InkWell(
      onTap: () => _selectPlatform(isFrom: isFrom),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                platform != null ? _shortLabel(platform.name) : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    platform?.name ?? 'Pilih Platform',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (platform != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      'Saldo: ${_formatRupiah(platform.balance)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isFrom ? AppColors.accentDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
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
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Image.asset(
            'assets/icons/transfer_saldo.png',
            width: 26,
            height: 26,
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

  Widget _buildQuickAmountChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('50.000', 50000),
          const SizedBox(width: 8),
          _buildChip('100.000', 100000),
          const SizedBox(width: 8),
          _buildChip('250.000', 250000),
          const SizedBox(width: 8),
          _buildChip('500.000', 500000),
          const SizedBox(width: 8),
          if (_fromPlatform != null && _fromPlatform!.balance > 0)
            GestureDetector(
              onTap: () {
                _amountController.text =
                    _fromPlatform!.balance.toInt().toString();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent, width: 1),
                ),
                child: const Text(
                  'Semua Saldo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, int amount) {
    return GestureDetector(
      onTap: () {
        _amountController.text = amount.toString();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Text(
          'Rp $label',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      maxLines: 2,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: 'Misal: Tarik tunai, kirim ke tabungan...',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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

  Widget _buildImagePicker() {
    if (_imagePath != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(_imagePath!),
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _removeImage,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.borderInput,
            width: 1,
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: AppColors.accentDark,
            ),
            SizedBox(height: 8),
            Text(
              'Unggah Bukti Transfer / Resi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Kamera atau galeri foto',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _handleTransfer,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.textPrimary, width: 1.2),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/transfer_saldo.png',
                    width: 22,
                    height: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Pindah Saldo Sekarang',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildNeedMorePlatformsBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.accentDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Perlu Minimal 2 Platform',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Untuk memindahkan saldo (misalnya dari Bank BRI ke Uang Cash), kamu perlu memiliki minimal 2 platform aset aktif.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final existingNames = _platforms.map((p) => p.name).toList();
                    final added = await AddPlatformSheet.show(
                      context,
                      userId: _userId,
                      existingNames: existingNames,
                    );
                    if (added == true) {
                      await _loadPlatforms();
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Tambah Platform Baru'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: AppColors.textPrimary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
