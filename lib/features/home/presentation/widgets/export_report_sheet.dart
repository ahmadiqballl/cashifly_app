import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/models/transaction_model.dart';
import '../../../../core/database/repositories/asset_repository.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/services/pdf_export_service.dart';

class ExportReportSheet extends StatefulWidget {
  const ExportReportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExportReportSheet(),
    );
  }

  @override
  State<ExportReportSheet> createState() => _ExportReportSheetState();
}

class _ExportReportSheetState extends State<ExportReportSheet> {
  final _txRepo = TransactionRepository();
  final _assetRepo = AssetRepository();
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  ExportPeriodType _periodType = ExportPeriodType.monthly;

  late DateTime _selectedDate;
  late int _selectedMonth;
  late int _selectedYear;

  bool _isLoading = true;
  bool _isGenerating = false;

  List<TransactionModel> _transactions = [];
  Map<int, String> _platformNames = {};

  static const List<String> _monthNames = [
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadData();
  }

  String _formatDateIso(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDateShort(DateTime dt) {
    return '${dt.day} ${_monthNames[dt.month].substring(0, 3)} ${dt.year}';
  }

  /// Hitung rentang tanggal (from, to, periodLabel, dateRangeDisplay)
  ({String from, String to, String label, String display}) _calculateRange() {
    switch (_periodType) {
      case ExportPeriodType.daily:
        final str = _formatDateIso(_selectedDate);
        return (
          from: str,
          to: str,
          label: 'HARIAN',
          display: '${_selectedDate.day} ${_monthNames[_selectedDate.month]} ${_selectedDate.year}',
        );

      case ExportPeriodType.weekly:
        final fromDate = _selectedDate.subtract(const Duration(days: 6));
        return (
          from: _formatDateIso(fromDate),
          to: _formatDateIso(_selectedDate),
          label: 'MINGGUAN',
          display: '${_formatDateShort(fromDate)} - ${_formatDateShort(_selectedDate)}',
        );

      case ExportPeriodType.monthly:
        final firstDay = DateTime(_selectedYear, _selectedMonth, 1);
        final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0);
        return (
          from: _formatDateIso(firstDay),
          to: _formatDateIso(lastDay),
          label: 'BULANAN',
          display: '${_monthNames[_selectedMonth]} $_selectedYear',
        );

      case ExportPeriodType.yearly:
        return (
          from: '$_selectedYear-01-01',
          to: '$_selectedYear-12-31',
          label: 'TAHUNAN',
          display: 'Tahun $_selectedYear',
        );
    }
  }

  Future<void> _loadData() async {
    if (_userId.isEmpty) return;
    setState(() => _isLoading = true);

    final range = _calculateRange();
    final results = await Future.wait([
      _txRepo.getByDateRange(_userId, from: range.from, to: range.to),
      _assetRepo.getAll(_userId),
    ]);

    if (!mounted) return;

    final txs = results[0] as List<TransactionModel>;
    final platforms = results[1] as List<dynamic>;

    final map = <int, String>{};
    for (final p in platforms) {
      if (p.id != null) map[p.id as int] = p.name as String;
    }

    setState(() {
      _transactions = txs;
      _platformNames = map;
      _isLoading = false;
    });
  }

  String _formatRupiah(double amount) {
    final intPart = amount.toInt().abs().toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
      count++;
    }
    final formatted = buf.toString().split('').reversed.join();
    return 'Rp$formatted';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  Future<void> _handlePrint() async {
    setState(() => _isGenerating = true);
    try {
      final range = _calculateRange();
      await PdfExportService.instance.printReceipt(
        periodLabel: range.label,
        dateRangeDisplay: range.display,
        transactions: _transactions,
        platformNames: _platformNames,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak PDF: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleShare() async {
    setState(() => _isGenerating = true);
    try {
      final range = _calculateRange();
      await PdfExportService.instance.shareReceipt(
        periodLabel: range.label,
        dateRangeDisplay: range.display,
        transactions: _transactions,
        platformNames: _platformNames,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan PDF: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double income = 0;
    double expense = 0;
    for (final tx in _transactions) {
      if (tx.type == TransactionType.income) income += tx.amount;
      if (tx.type == TransactionType.expense) expense += tx.amount;
    }
    final net = income - expense;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle bar ─────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header Box ─────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Laporan PDF',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Struk monokrom thermal print Cashifly',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Pilihan Periode (Tabs) ─────────────────────────────────────────
          Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                _buildPeriodTab('Harian', ExportPeriodType.daily),
                _buildPeriodTab('Mingguan', ExportPeriodType.weekly),
                _buildPeriodTab('Bulanan', ExportPeriodType.monthly),
                _buildPeriodTab('Tahunan', ExportPeriodType.yearly),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Filter Selector Kontrol ────────────────────────────────────────
          _buildFilterControl(),
          const SizedBox(height: 16),

          // ── Ringkasan Transaksi dalam Periode ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Transaksi',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${_transactions.length} Transaksi',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.border, height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pemasukan (+)',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '+${_formatRupiah(income)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pengeluaran (-)',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '-${_formatRupiah(expense)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Arus Bersih (Net)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${net >= 0 ? '+' : '-'}${_formatRupiah(net.abs())}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: net >= 0 ? AppColors.accentDark : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // ── Tombol Cetak & Bagikan ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGenerating ? null : _handleShare,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Bagikan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _handlePrint,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print_rounded, size: 18),
                  label: Text(_isGenerating ? 'Menyiapkan...' : 'Lihat & Cetak PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  Widget _buildPeriodTab(String label, ExportPeriodType type) {
    final isSelected = _periodType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_periodType != type) {
            setState(() => _periodType = type);
            _loadData();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterControl() {
    switch (_periodType) {
      case ExportPeriodType.daily:
        return _buildSelectorCard(
          icon: Icons.calendar_today_rounded,
          title: 'Tanggal Laporan',
          subtitle: '${_selectedDate.day} ${_monthNames[_selectedDate.month]} ${_selectedDate.year}',
          trailingText: 'Ubah',
          onTap: _pickDate,
        );

      case ExportPeriodType.weekly:
        final fromDate = _selectedDate.subtract(const Duration(days: 6));
        return _buildSelectorCard(
          icon: Icons.date_range_rounded,
          title: 'Rentang 7 Hari',
          subtitle: '${_formatDateShort(fromDate)} - ${_formatDateShort(_selectedDate)}',
          trailingText: 'Ubah Tanggal',
          onTap: _pickDate,
        );

      case ExportPeriodType.monthly:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth == 1) {
                      _selectedMonth = 12;
                      _selectedYear--;
                    } else {
                      _selectedMonth--;
                    }
                  });
                  _loadData();
                },
              ),
              Column(
                children: [
                  Text(
                    _monthNames[_selectedMonth],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$_selectedYear',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth == 12) {
                      _selectedMonth = 1;
                      _selectedYear++;
                    } else {
                      _selectedMonth++;
                    }
                  });
                  _loadData();
                },
              ),
            ],
          ),
        );

      case ExportPeriodType.yearly:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() => _selectedYear--);
                  _loadData();
                },
              ),
              Text(
                'Tahun $_selectedYear',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() => _selectedYear++);
                  _loadData();
                },
              ),
            ],
          ),
        );
    }
  }

  Widget _buildSelectorCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailingText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
