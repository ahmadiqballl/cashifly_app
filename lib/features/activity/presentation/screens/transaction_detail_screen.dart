import 'dart:io';

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/models/asset_platform_model.dart';
import '../../../../core/database/models/transaction_model.dart';
import '../../../../core/database/repositories/asset_repository.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _assetRepo = AssetRepository();

  AssetPlatform? _platform;
  AssetPlatform? _toPlatform;
  bool _isLoadingPlatforms = true;

  @override
  void initState() {
    super.initState();
    _loadPlatforms();
  }

  Future<void> _loadPlatforms() async {
    final tx = widget.transaction;
    AssetPlatform? fromP;
    AssetPlatform? toP;

    if (tx.platformId != null) {
      fromP = await _assetRepo.getById(tx.platformId!, tx.userId);
    }
    if (tx.toPlatformId != null) {
      toP = await _assetRepo.getById(tx.toPlatformId!, tx.userId);
    }

    if (mounted) {
      setState(() {
        _platform = fromP;
        _toPlatform = toP;
        _isLoadingPlatforms = false;
      });
    }
  }

  String _formatRupiah(double amount) {
    final intPart = amount.toInt().toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
      count++;
    }
    return 'Rp${buf.toString().split('').reversed.join()}';
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = [
        '',
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _shortLabel(String name) {
    if (name == 'Uang Cash') return 'Cash';
    if (name.startsWith('Bank ')) return name.substring(5);
    return name;
  }

  void _openImagePreview(String path) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
            title: const Text(
              'Bukti Transaksi',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final isIncome = tx.type == TransactionType.income;
    final isTransfer = tx.type == TransactionType.transfer;

    final typeColor = isTransfer
        ? AppColors.accentDark
        : (isIncome ? AppColors.success : AppColors.error);

    final typeLabel = isTransfer
        ? 'Pindah Saldo'
        : (isIncome ? 'Pemasukan' : 'Pengeluaran');

    final prefix = isTransfer ? '' : (isIncome ? '+' : '-');

    final hasImage = tx.imagePath != null && tx.imagePath!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.accent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Detail Riwayat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Card Jumlah & Status ────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
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
                  // Badge tipe transaksi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: typeColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            isTransfer
                                ? 'assets/icons/transfer_saldo.png'
                                : (isIncome
                                    ? 'assets/icons/pemasukan.png'
                                    : 'assets/icons/pengeluaran.png'),
                            width: 18,
                            height: 18,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nominal utama
                  Text(
                    '$prefix${_formatRupiah(tx.amount)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: typeColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Kategori
                  Text(
                    tx.category,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Informasi Transaksi ──────────────────────────────────────────
            const Text(
              'Informasi Transaksi',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: Column(
                children: [
                  // Tanggal & Waktu
                  _buildDetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Waktu Transaksi',
                    value: tx.time.isNotEmpty
                        ? '${_formatDate(tx.date)} · ${tx.time.replaceAll(':', '.')}'
                        : _formatDate(tx.date),
                    isFirst: true,
                  ),

                  // Platform / Akun
                  if (isTransfer) ...[
                    _buildDetailRow(
                      icon: Icons.arrow_outward_rounded,
                      label: 'Platform Asal',
                      customWidget: _isLoadingPlatforms
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : (_platform != null
                              ? _buildPlatformBadge(_platform!)
                              : const Text(
                                  '-',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )),
                    ),
                    _buildDetailRow(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Platform Tujuan',
                      customWidget: _isLoadingPlatforms
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : (_toPlatform != null
                              ? _buildPlatformBadge(_toPlatform!)
                              : const Text(
                                  '-',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )),
                      isLast: tx.note == null || tx.note!.isEmpty,
                    ),
                  ] else ...[
                    _buildDetailRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Platform Aset',
                      customWidget: _isLoadingPlatforms
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : (_platform != null
                              ? _buildPlatformBadge(_platform!)
                              : const Text(
                                  '-',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )),
                      isLast: tx.note == null || tx.note!.isEmpty,
                    ),
                  ],

                  // Catatan / Keterangan (jika ada)
                  if (tx.note != null && tx.note!.isNotEmpty)
                    _buildDetailRow(
                      icon: Icons.notes_rounded,
                      label: 'Keterangan',
                      value: tx.note!,
                      isLast: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Foto / Bukti Transaksi ───────────────────────────────────────
            if (hasImage) ...[
              const Text(
                'Bukti Transaksi / Resi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: () => _openImagePreview(tx.imagePath!),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.file(
                        File(tx.imagePath!),
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Container(
                          height: 120,
                          color: AppColors.inputBackground,
                          alignment: Alignment.center,
                          child: const Text(
                            'Gagal memuat gambar',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Ketuk untuk memperbesar foto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.zoom_in_rounded,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformBadge(AssetPlatform p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Color(p.colorValue),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            _shortLabel(p.name),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? customWidget,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: customWidget ??
                  Text(
                    value ?? '-',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 14,
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
}
