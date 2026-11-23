import '../database_helper.dart';
import '../models/monthly_report_model.dart';
import '../models/transaction_model.dart';
import 'transaction_repository.dart';

/// ============================================================================
/// MonthlyReportRepository
/// ============================================================================
/// Repository untuk mengelola arsip laporan keuangan bulanan.
///
/// Bertanggung jawab untuk:
/// 1. Menyimpan atau memperbarui rekapitulasi bulanan ke SQLite.
/// 2. Mengambil daftar arsip laporan bulanan terurut berdasarkan waktu.
/// 3. Menjalankan sinkronisasi otomatis (`syncAutoMonthlyReports`) setiap tanggal 1
///    tanpa memerlukan cron job server eksternal.
class MonthlyReportRepository {
  final DatabaseHelper _db;
  final TransactionRepository _txRepo;

  MonthlyReportRepository({DatabaseHelper? db, TransactionRepository? txRepo})
      : _db = db ?? DatabaseHelper.instance,
        _txRepo = txRepo ?? TransactionRepository();

  /// Daftar nama bulan dalam Bahasa Indonesia untuk representasi data.
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

  // ── Create / Insert ────────────────────────────────────────────────────────
  /// Menyimpan atau memperbarui data arsip laporan bulanan ke tabel `monthly_reports`.
  /// Menggunakan constraint SQLite `ON CONFLICT REPLACE` dari DDL database.
  Future<int> insert(MonthlyReport report) async {
    final db = await _db.database;
    return db.insert(
      DatabaseHelper.tableMonthlyReports,
      report.toMap(),
    );
  }

  // ── Read ───────────────────────────────────────────────────────────────────
  /// Mengambil seluruh arsip laporan bulanan milik [userId], 
  /// diurutkan dari tahun dan bulan terbaru ke yang terlama.
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

  /// Mengambil data laporan satu bulan tertentu berdasarkan [year] dan [month].
  /// Mengembalikan `null` jika arsip bulan tersebut belum ada di database.
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

  // ── Otomasi Tanggal 1 (Auto Archiving) ──────────────────────────────────────
  /// Logika otomatisasi arsip bulanan lokal:
  ///
  /// Dipanggil setiap kali halaman laporan dibuka.
  /// Memeriksa semua bulan yang telah berakhir (mencapai tanggal 1 di bulan berikutnya).
  /// Mengagregasi total pemasukan, pengeluaran, transfer, dan saldo bersih (netto)
  /// lalu menyimpannya secara otomatis ke tabel `monthly_reports`.
  Future<List<MonthlyReport>> syncAutoMonthlyReports(String userId) async {
    final db = await _db.database;
    final now = DateTime.now();

    // 1. Kueri semua variasi tahun-bulan (YYYY-MM) dari tabel transaksi pengguna
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

    // 2. Tambahkan bulan lalu ke daftar antrean pemeriksaan jika sudah masuk tanggal 1 bulan ini
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final prevYm =
        '${prevMonthDate.year}-${prevMonthDate.month.toString().padLeft(2, '0')}';
    monthsToProcess.add(prevYm);

    // 3. Iterasi setiap bulan yang telah tuntas
    for (final ym in monthsToProcess) {
      final parts = ym.split('-');
      if (parts.length < 2) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year == null || month == null || month < 1 || month > 12) continue;

      // Bulan dianggap tuntas jika tanggal 1 bulan berikutnya <= tanggal hari ini
      final nextMonthFirstDay = DateTime(year, month + 1, 1);
      final isCompleted = !nextMonthFirstDay.isAfter(DateTime(now.year, now.month, now.day));

      if (isCompleted) {
        // Periksa apakah bulan ini sudah pernah dicatat sebelumnya
        final existing = await getByMonth(userId, year, month);

        final firstDayStr = '$year-${month.toString().padLeft(2, '0')}-01';
        final lastDay = DateTime(year, month + 1, 0);
        final lastDayStr =
            '$year-${month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

        // Ambil transaksi dalam periode 1 bulan penuh
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

          // Agregasi total mutasi keuangan
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
