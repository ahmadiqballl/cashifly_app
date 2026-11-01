import '../database_helper.dart';
import '../models/asset_platform_model.dart';

/// Repository untuk operasi CRUD platform aset.
///
/// Setiap operasi **wajib** menyertakan [userId] sehingga
/// data antar pengguna tidak pernah bercampur.
class AssetRepository {
  final DatabaseHelper _db;

  AssetRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Simpan platform baru. Mengembalikan id yang di-generate SQLite.
  Future<int> insert(AssetPlatform platform) async {
    final db = await _db.database;
    return db.insert(
      DatabaseHelper.tableAssetPlatforms,
      platform.toMap(),
    );
  }

  /// Inisialisasi platform Cash default untuk user baru (jika belum ada).
  Future<void> initDefaultCash(String userId) async {
    final existing = await getAll(userId);
    if (existing.isEmpty) {
      await insert(AssetPlatform(
        userId: userId,
        type: PlatformType.cash,
        name: 'Uang Cash',
        balance: 0,
        colorValue: PlatformColors.cash,
      ));
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Ambil semua platform milik [userId], urut berdasarkan id (urutan tambah).
  Future<List<AssetPlatform>> getAll(String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableAssetPlatforms,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id ASC',
    );
    return rows.map(AssetPlatform.fromMap).toList();
  }

  /// Total seluruh aset (jumlah semua balance) milik [userId].
  Future<double> totalBalance(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(balance), 0) AS total '
      'FROM ${DatabaseHelper.tableAssetPlatforms} '
      'WHERE user_id = ?',
      [userId],
    );
    return (result.first['total'] as num).toDouble();
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Perbarui balance platform (misalnya setelah transaksi).
  Future<int> updateBalance(int id, String userId, double balance) async {
    final db = await _db.database;
    return db.update(
      DatabaseHelper.tableAssetPlatforms,
      {'balance': balance},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  /// Hapus platform jika balance = 0 (tidak ada aset di sana).
  /// Mengembalikan true jika berhasil dihapus, false jika balance > 0.
  Future<bool> delete(int id, String userId) async {
    final db = await _db.database;

    // Cek apakah balance masih ada
    final rows = await db.query(
      DatabaseHelper.tableAssetPlatforms,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final balance = (rows.first['balance'] as num).toDouble();
    if (balance != 0) return false; // ada aset, tidak bisa dihapus

    await db.delete(
      DatabaseHelper.tableAssetPlatforms,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    return true;
  }

  /// Cek apakah nama platform sudah ada untuk user ini (hindari duplikat).
  Future<bool> nameExists(String userId, String name) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableAssetPlatforms,
      where: 'user_id = ? AND LOWER(name) = LOWER(?)',
      whereArgs: [userId, name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
