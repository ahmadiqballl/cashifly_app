import '../database_helper.dart';
import '../models/asset_platform_model.dart';
import '../models/transaction_model.dart';

/// ============================================================================
/// TransactionRepository
/// ============================================================================
/// Repository utama untuk mengelola seluruh operasi CRUD transaksi keuangan
/// (Pemasukan, Pengeluaran, dan Transfer Antar-Platform).
///
/// Setiap kueri wajib menyertakan [userId] (UID Firebase Auth) sehingga data 
/// transaksi terisolasi sepenuhnya per pengguna.
class TransactionRepository {
  final DatabaseHelper _db;

  TransactionRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Menyimpan satu baris data transaksi ke tabel SQLite.
  /// Mengembalikan nilai primary key [id] transaksi yang baru dibuat.
  Future<int> insert(TransactionModel transaction) async {
    final db = await _db.database;
    return db.insert(
      DatabaseHelper.tableTransactions,
      transaction.toMap(),
    );
  }

  /// Menyimpan transaksi sekaligus memperbarui saldo dompet secara **atomik**
  /// dalam satu blok transaksi database (`db.transaction`).
  ///
  /// - Jika bertipe [TransactionType.income]: menambah saldo platform.
  /// - Jika bertipe [TransactionType.expense]: mengurangi saldo platform.
  Future<int> insertWithBalanceUpdate({
    required TransactionModel transaction,
    required AssetPlatform platform,
  }) async {
    final db = await _db.database;
    late int txId;
    await db.transaction((txn) async {
      // 1. Simpan baris transaksi
      txId = await txn.insert(
        DatabaseHelper.tableTransactions,
        transaction.toMap(),
      );

      // 2. Hitung selisih perubahan saldo
      final delta = transaction.type == TransactionType.income
          ? transaction.amount
          : -transaction.amount;

      // 3. Mutasi saldo platform
      await txn.update(
        DatabaseHelper.tableAssetPlatforms,
        {'balance': platform.balance + delta},
        where: 'id = ? AND user_id = ?',
        whereArgs: [platform.id, platform.userId],
      );
    });
    return txId;
  }

  /// Memindahkan saldo antar dua platform dompet secara **atomik (ACID-compliant)**
  /// dalam satu transaksi database SQLite tunggal.
  ///
  /// Menjamin integritas data:
  /// - Mengurangi saldo [fromPlatform] sebesar `transaction.amount`.
  /// - Menambah saldo [toPlatform] sebesar `transaction.amount`.
  /// - Mencatat riwayat transaksi bertipe `TransactionType.transfer`.
  /// Jika terjadi kegagalan sistem, seluruh mutasi dibatalkan (*rollback*).
  Future<int> transferWithBalanceUpdate({
    required TransactionModel transaction,
    required AssetPlatform fromPlatform,
    required AssetPlatform toPlatform,
  }) async {
    final db = await _db.database;
    late int txId;
    await db.transaction((txn) async {
      // 1. Catat riwayat transfer di tabel transaksi
      txId = await txn.insert(
        DatabaseHelper.tableTransactions,
        transaction.toMap(),
      );

      // 2. Kurangi saldo dari platform sumber/pengirim
      await txn.update(
        DatabaseHelper.tableAssetPlatforms,
        {'balance': fromPlatform.balance - transaction.amount},
        where: 'id = ? AND user_id = ?',
        whereArgs: [fromPlatform.id, fromPlatform.userId],
      );

      // 3. Tambahkan saldo ke platform tujuan/penerima
      await txn.update(
        DatabaseHelper.tableAssetPlatforms,
        {'balance': toPlatform.balance + transaction.amount},
        where: 'id = ? AND user_id = ?',
        whereArgs: [toPlatform.id, toPlatform.userId],
      );
    });
    return txId;
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Mengambil transaksi milik [userId] dalam 14 hari terakhir, diurutkan dari yang terbaru.
  Future<List<TransactionModel>> getRecent14Days(String userId) async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 14));
    final fromStr =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final toStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return getByDateRange(userId, from: fromStr, to: toStr);
  }

  /// Mengambil seluruh data transaksi milik [userId], diurutkan tanggal & id terbaru di atas.
  Future<List<TransactionModel>> getAll(String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableTransactions,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Mengambil transaksi milik [userId] dalam rentang tanggal tertentu ([from] s/d [to]).
  /// Format tanggal: "YYYY-MM-DD".
  Future<List<TransactionModel>> getByDateRange(
    String userId, {
    required String from,
    required String to,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableTransactions,
      where: 'user_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [userId, from, to],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Mengambil satu transaksi berdasarkan [id] spesifik milik [userId].
  Future<TransactionModel?> getById(int id, String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableTransactions,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TransactionModel.fromMap(rows.first);
  }

  // ── Summary & Agregasi ─────────────────────────────────────────────────────

  /// Menghitung akumulasi seluruh nominal pemasukan milik [userId].
  Future<double> totalIncome(String userId) async {
    return _sumByType(userId, TransactionType.income);
  }

  /// Menghitung akumulasi seluruh nominal pengeluaran milik [userId].
  Future<double> totalExpense(String userId) async {
    return _sumByType(userId, TransactionType.expense);
  }

  /// Menghitung saldo bersih total (Total Pemasukan - Total Pengeluaran).
  Future<double> balance(String userId) async {
    final income = await totalIncome(userId);
    final expense = await totalExpense(userId);
    return income - expense;
  }

  /// Fungsi utilitas internal untuk menjumlahkan nominal transaksi berdasarkan tipenya.
  Future<double> _sumByType(String userId, TransactionType type) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM ${DatabaseHelper.tableTransactions} '
      'WHERE user_id = ? AND type = ?',
      [userId, type.name],
    );
    return (result.first['total'] as num).toDouble();
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Memperbarui informasi transaksi yang sudah ada.
  /// Mengembalikan jumlah baris di database yang berhasil diperbarui.
  Future<int> update(TransactionModel transaction) async {
    assert(transaction.id != null, 'id harus ada untuk update');
    final db = await _db.database;
    return db.update(
      DatabaseHelper.tableTransactions,
      transaction.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [transaction.id, transaction.userId],
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  /// Menghapus satu transaksi tertentu berdasarkan [id] milik [userId].
  Future<int> delete(int id, String userId) async {
    final db = await _db.database;
    return db.delete(
      DatabaseHelper.tableTransactions,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  /// Menghapus seluruh transaksi milik [userId] (digunakan saat opsi reset data).
  Future<int> deleteAll(String userId) async {
    final db = await _db.database;
    return db.delete(
      DatabaseHelper.tableTransactions,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
