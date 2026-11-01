import '../database_helper.dart';
import '../models/asset_platform_model.dart';
import '../models/transaction_model.dart';

/// Repository untuk operasi CRUD transaksi keuangan.
///
/// Setiap operasi **wajib** menyertakan [userId] (UID Firebase Auth)
/// sehingga data antar pengguna tidak pernah bercampur.
class TransactionRepository {
  final DatabaseHelper _db;

  TransactionRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Simpan transaksi baru. Mengembalikan id yang di-generate SQLite.
  Future<int> insert(TransactionModel transaction) async {
    final db = await _db.database;
    return db.insert(
      DatabaseHelper.tableTransactions,
      transaction.toMap(),
    );
  }

  /// Simpan transaksi dan perbarui saldo platform secara atomik dalam satu transaksi DB.
  ///
  /// - [income]: menambah saldo platform
  /// - [expense]: mengurangi saldo platform (boleh negatif jika dikehendaki)
  Future<int> insertWithBalanceUpdate({
    required TransactionModel transaction,
    required AssetPlatform platform,
  }) async {
    final db = await _db.database;
    late int txId;
    await db.transaction((txn) async {
      txId = await txn.insert(
        DatabaseHelper.tableTransactions,
        transaction.toMap(),
      );

      final delta = transaction.type == TransactionType.income
          ? transaction.amount
          : -transaction.amount;

      await txn.update(
        DatabaseHelper.tableAssetPlatforms,
        {'balance': platform.balance + delta},
        where: 'id = ? AND user_id = ?',
        whereArgs: [platform.id, platform.userId],
      );
    });
    return txId;
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Ambil semua transaksi milik [userId], diurutkan terbaru di atas.
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

  /// Ambil transaksi milik [userId] dalam rentang tanggal tertentu.
  ///
  /// [from] dan [to] dalam format "YYYY-MM-DD".
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

  /// Ambil satu transaksi berdasarkan [id], pastikan milik [userId].
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

  // ── Summary ────────────────────────────────────────────────────────────────

  /// Total pemasukan milik [userId].
  Future<double> totalIncome(String userId) async {
    return _sumByType(userId, TransactionType.income);
  }

  /// Total pengeluaran milik [userId].
  Future<double> totalExpense(String userId) async {
    return _sumByType(userId, TransactionType.expense);
  }

  /// Saldo = pemasukan - pengeluaran
  Future<double> balance(String userId) async {
    final income = await totalIncome(userId);
    final expense = await totalExpense(userId);
    return income - expense;
  }

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

  /// Perbarui transaksi yang sudah ada. Mengembalikan jumlah baris yang terpengaruh.
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

  /// Hapus satu transaksi berdasarkan [id], pastikan milik [userId].
  Future<int> delete(int id, String userId) async {
    final db = await _db.database;
    return db.delete(
      DatabaseHelper.tableTransactions,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  /// Hapus semua transaksi milik [userId] (misal saat akun dihapus).
  Future<int> deleteAll(String userId) async {
    final db = await _db.database;
    return db.delete(
      DatabaseHelper.tableTransactions,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
