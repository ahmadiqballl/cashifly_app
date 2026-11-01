import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/repositories/asset_repository.dart';
import '../../../asset/presentation/screens/asset_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = AssetRepository();
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  double _totalBalance = 0;
  bool _isVisible = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_userId.isEmpty) return;
    await _repo.initDefaultCash(_userId);
    final total = await _repo.totalBalance(_userId);
    if (mounted) {
      setState(() {
        _totalBalance = total;
        _isLoading = false;
      });
    }
  }

  // ── Format rupiah ──────────────────────────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Kartu total aset ────────────────────────────────────────────
              _buildAssetCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.textPrimary, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Inner card putih ───────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Aset Keseluruhan',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _isLoading
                          ? const SizedBox(
                              height: 28,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              _isVisible
                                  ? _formatRupiah(_totalBalance)
                                  : 'Rp ••••••••',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                    ],
                  ),
                ),

                // Ikon mata
                GestureDetector(
                  onTap: () =>
                      setState(() => _isVisible = !_isVisible),
                  child: Icon(
                    _isVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // ── Tombol Rincian Aset ────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AssetDetailScreen()),
              );
              // Refresh saat kembali
              _load();
            },
            child: const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 14, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rincian Aset',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
