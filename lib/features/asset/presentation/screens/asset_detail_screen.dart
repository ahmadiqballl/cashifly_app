import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/models/asset_platform_model.dart';
import '../../../../core/database/repositories/asset_repository.dart';
import '../widgets/add_platform_sheet.dart';

class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({super.key});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  final _repo = AssetRepository();
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<AssetPlatform> _platforms = [];
  double _totalBalance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_userId.isEmpty) return;
    await _repo.initDefaultCash(_userId);
    final platforms = await _repo.getAll(_userId);
    final total = await _repo.totalBalance(_userId);
    if (mounted) {
      setState(() {
        _platforms = platforms;
        _totalBalance = total;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAddPlatform() async {
    final existingNames = _platforms.map((p) => p.name).toList();
    final added = await AddPlatformSheet.show(
      context,
      userId: _userId,
      existingNames: existingNames,
    );
    if (added == true) await _load();
  }

  Future<void> _handleDelete(AssetPlatform platform) async {
    if (platform.balance != 0) {
      _showSnack(
          'Tidak bisa menghapus platform yang masih memiliki saldo.');
      return;
    }
    if (platform.type == PlatformType.cash) {
      _showSnack('Platform Uang Cash tidak dapat dihapus.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Platform'),
        content: Text(
            'Hapus platform "${platform.name}"? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && platform.id != null) {
      final success = await _repo.delete(platform.id!, _userId);
      if (success) {
        await _load();
      } else {
        _showSnack('Gagal menghapus platform.');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Format rupiah ──────────────────────────────────────────────────────────
  String _formatRupiah(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    // Bangun bagian integer dengan pemisah titik ribuan
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // ── AppBar dengan back + logo ─────────────────────────────────────────
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
          : Column(
              children: [
                // ── Total aset ───────────────────────────────────────────────
                _buildTotalHeader(),

                // ── Daftar platform ──────────────────────────────────────────
                Expanded(
                  child: _platforms.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                          itemCount: _platforms.length,
                          itemBuilder: (_, i) =>
                              _PlatformCard(
                                platform: _platforms[i],
                                formatRupiah: _formatRupiah,
                                onDelete: () =>
                                    _handleDelete(_platforms[i]),
                              ),
                        ),
                ),
              ],
            ),

      // ── Tombol Tambah Platform ─────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _handleAddPlatform,
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
              child: const Text(
                '+ Tambah Platform Baru',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Total Aset Keseluruhan',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatRupiah(_totalBalance),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, thickness: 1, height: 1),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text(
        'Belum ada platform aset.',
        style: TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}

// ── Platform Card ──────────────────────────────────────────────────────────────

class _PlatformCard extends StatelessWidget {
  final AssetPlatform platform;
  final String Function(double) formatRupiah;
  final VoidCallback onDelete;

  const _PlatformCard({
    required this.platform,
    required this.formatRupiah,
    required this.onDelete,
  });

  /// Buat label singkat untuk ditampilkan di kotak warna.
  /// "Bank BRI" → "BRI", "GoPay" → "GoPay", "Uang Cash" → "Cash"
  String _shortLabel(String name) {
    if (name == 'Uang Cash') return 'Cash';
    // Kalau diawali "Bank ", ambil bagian setelahnya
    if (name.startsWith('Bank ')) return name.substring(5);
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(platform.colorValue);
    final label = _shortLabel(platform.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Kotak warna platform dengan nama singkat ──────────────────────
          Container(
            width: 110,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // ── Info platform ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Total Aset Keseluruhan',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatRupiah(platform.balance),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // ── Tombol hapus (hanya muncul jika bukan cash & balance = 0) ─────
          if (platform.type != PlatformType.cash && platform.balance == 0)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 22),
              onPressed: onDelete,
              tooltip: 'Hapus platform',
            ),
        ],
      ),
    );
  }
}
