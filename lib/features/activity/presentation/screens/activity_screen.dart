import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/models/notification_log_model.dart';
import '../../../../core/database/models/transaction_model.dart';
import '../../../../core/database/repositories/notification_log_repository.dart';
import '../../../../core/database/repositories/transaction_repository.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _txRepo = TransactionRepository();
  final _logRepo = NotificationLogRepository();
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<TransactionModel> _transactions = [];
  List<NotificationLog> _notifications = [];
  bool _loadingTx = true;
  bool _loadingNotif = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (_userId.isEmpty) return;
    await Future.wait([_loadTransactions(), _loadNotifications()]);
  }

  Future<void> _loadTransactions() async {
    final data = await _txRepo.getRecent14Days(_userId);
    if (mounted) setState(() { _transactions = data; _loadingTx = false; });
  }

  Future<void> _loadNotifications() async {
    final data = await _logRepo.getAll(_userId);
    if (mounted) setState(() { _notifications = data; _loadingNotif = false; });
  }

  // ── Format helpers ─────────────────────────────────────────────────────────

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

  /// "2026-11-01" → "1 Nov 2026"
  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  /// DateTime → "1 Nov 2026, 08:00"
  String _formatDateTime(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month]} ${dt.year}, $h:$m';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.accent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: const Text(
          'Aktivitas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          tabs: const [
            Tab(text: 'Aktivitas'),
            Tab(text: 'Notifikasi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityTab(),
          _buildNotificationTab(),
        ],
      ),
    );
  }

  // ── Tab Aktivitas ──────────────────────────────────────────────────────────

  Widget _buildActivityTab() {
    if (_loadingTx) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_transactions.isEmpty) {
      return _buildEmpty(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada aktivitas',
        subtitle: 'Transaksi 14 hari terakhir akan muncul di sini.',
      );
    }

    // Kelompokkan berdasarkan tanggal
    final Map<String, List<TransactionModel>> grouped = {};
    for (final tx in _transactions) {
      grouped.putIfAbsent(tx.date, () => []).add(tx);
    }
    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: sortedDates.length,
        itemBuilder: (context, i) {
          final date = sortedDates[i];
          final txs = grouped[date]!;
          return _buildDateGroup(date, txs);
        },
      ),
    );
  }

  Widget _buildDateGroup(String date, List<TransactionModel> txs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            _formatDate(date),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: List.generate(txs.length, (j) {
              final tx = txs[j];
              final isLast = j == txs.length - 1;
              return _buildTransactionTile(tx, isLast: isLast);
            }),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildTransactionTile(TransactionModel tx, {required bool isLast}) {
    final isIncome = tx.type == TransactionType.income;
    final color = isIncome ? AppColors.success : AppColors.error;
    final icon = isIncome
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final prefix = isIncome ? '+' : '-';

    // Baris subtitle: tampilkan waktu + catatan (jika ada)
    final hasTime = tx.time.isNotEmpty;
    final hasNote = tx.note != null && tx.note!.isNotEmpty;
    // Ganti ":" jadi "." untuk tampilan waktu (14:23 → 14.23)
    final timeDisplay = tx.time.replaceAll(':', '.');
    final subtitleParts = [
      if (hasTime) timeDisplay,
      if (hasNote) tx.note!,
    ];
    final subtitleText = subtitleParts.join('  ·  ');

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          tx.category,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.normal,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: subtitleText.isNotEmpty
            ? Text(
                subtitleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.normal,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
        trailing: Text(
          '$prefix${_formatRupiah(tx.amount)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  // ── Tab Notifikasi ─────────────────────────────────────────────────────────

  Widget _buildNotificationTab() {
    if (_loadingNotif) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_notifications.isEmpty) {
      return _buildEmpty(
        icon: Icons.notifications_none_rounded,
        title: 'Belum ada notifikasi',
        subtitle: 'Notifikasi pencapaian aset akan tersimpan di sini\nselama 14 hari.',
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _notifications.length,
        itemBuilder: (context, i) {
          return _buildNotificationTile(_notifications[i]);
        },
      ),
    );
  }

  Widget _buildNotificationTile(NotificationLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  log.body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDateTime(log.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
