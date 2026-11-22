import '../database_helper.dart';
import '../models/monthly_report_model.dart';
import '../models/transaction_model.dart';
import 'transaction_repository.dart';

class MonthlyReportRepository {
  final DatabaseHelper _db;
  final TransactionRepository _txRepo;

  MonthlyReportRepository({DatabaseHelper? db, TransactionRepository? txRepo})
      : _db = db ?? DatabaseHelper.instance,
        _txRepo = txRepo ?? TransactionRepository();

  static const List<String> monthNames = [
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

  /// Simpan atau perbarui arsip laporan bulanan
  Future<int> insert(MonthlyReport report) async {
    final db = await _db.database;
    return db.insert(
      DatabaseHelper.tableMonthlyReports,
      report.toMap(),
    );
  }

  /// Ambil semua laporan keuangan bulanan milik [userId], diurutkan terbaru ke terlama
  Future<List<MonthlyReport>> getAll(String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableMonthlyReports,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'year DESC, month DESC',
    );
    return rows.map(MonthlyReport.fromMap).toList();
  }

  /// Ambil satu laporan bulanan spesifik
  Future<MonthlyReport?> getByMonth(String userId, int year, int month) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableMonthlyReports,
      where: 'user_id = ? AND year = ? AND month = ?',
      whereArgs: [userId, year, month],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MonthlyReport.fromMap(rows.first);
  }

  /// Sinkronisasi otomatis:
  /// Setiap tanggal 1 (atau setelah bulan selesai), sistem otomatis merekap dan mencatat
  /// laporan bulan yang telah tuntas ke dalam tabel `monthly_reports`.
  Future<List<MonthlyReport>> syncAutoMonthlyReports(String userId) async {
    final db = await _db.database;
    final now = DateTime.now();

    // 1. Ambil seluruh bulan yang memiliki transaksi
    final ymRows = await db.rawQuery(
      'SELECT DISTINCT SUBSTR(date, 1, 7) AS ym '
      'FROM ${DatabaseHelper.tableTransactions} '
      'WHERE user_id = ? AND LENGTH(date) >= 7 '
      'ORDER BY ym ASC',
      [userId],
    );

    final Set<String> monthsToProcess = {};
    for (final row in ymRows) {
      final ym = row['ym'] as String?;
      if (ym != null && ym.contains('-')) {
        monthsToProcess.add(ym);
      }
    }

    // 2. Tambahkan juga bulan lalu secara otomatis jika tanggal >= 1 bulan ini
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final prevYm =
        '${prevMonthDate.year}-${prevMonthDate.month.toString().padLeft(2, '0')}';
    monthsToProcess.add(prevYm);

    // 3. Proses setiap bulan yang telah tuntas (tanggal 1 bulan berikutnya sudah tiba)
    for (final ym in monthsToProcess) {
      final parts = ym.split('-');
      if (parts.length < 2) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year == null || month == null || month < 1 || month > 12) continue;

      // Bulan dianggap tuntas jika tanggal 1 bulan berikutnya <= sekarang
      final nextMonthFirstDay = DateTime(year, month + 1, 1);
      final isCompleted = !nextMonthFirstDay.isAfter(DateTime(now.year, now.month, now.day));

      if (isCompleted) {
        // Cek apakah laporan sudah ada
        final existing = await getByMonth(userId, year, month);

        final firstDayStr = '$year-${month.toString().padLeft(2, '0')}-01';
        final lastDay = DateTime(year, month + 1, 0);
        final lastDayStr =
            '$year-${month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

        // Hitung transaksi dalam bulan tersebut
        final txs = await _txRepo.getByDateRange(
          userId,
          from: firstDayStr,
          to: lastDayStr,
        );

        // Hanya catat jika ada transaksi ATAU laporan sudah pernah tersimpan sebelumnya
        if (txs.isNotEmpty || existing != null) {
          double income = 0;
          double expense = 0;
          double transfer = 0;

          for (final tx in txs) {
            if (tx.type == TransactionType.income) {
              income += tx.amount;
            } else if (tx.type == TransactionType.expense) {
              expense += tx.amount;
            } else if (tx.type == TransactionType.transfer) {
              transfer += tx.amount;
            }
          }

          final mName = month >= 1 && month <= 12 ? monthNames[month] : 'Bulan $month';
          final report = MonthlyReport(
            id: existing?.id,
            userId: userId,
            year: year,
            month: month,
            monthName: mName,
            totalIncome: income,
            totalExpense: expense,
            totalTransfer: transfer,
            netBalance: income - expense,
            transactionCount: txs.length,
            createdAt: existing?.createdAt ?? nextMonthFirstDay.toIso8601String(),
          );

          await insert(report);
        }
      }
    }

    return getAll(userId);
  }
}
