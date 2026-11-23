import '../database_helper.dart';
import '../models/asset_platform_model.dart';

/// ============================================================================
/// AssetRepository
/// ============================================================================
/// Repository untuk operasi CRUD platform dompet aset (Cash, Bank, E-Wallet).
///
/// Setiap operasi **wajib** menyertakan [userId] (UID Firebase Auth) sehingga
/// data aset antar pengguna terisolasi dan tidak pernah bercampur.
class AssetRepository {
  final DatabaseHelper _db;

  AssetRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Menyimpan platform baru ke database SQLite.
  /// Mengembalikan nilai primary key [id] yang di-generate otomatis.
  Future<int> insert(AssetPlatform platform) async {
    final db = await _db.database;
    return db.insert(
      DatabaseHelper.tableAssetPlatforms,
      platform.toMap(),
    );
  }

  /// Menginisialisasi platform dompet "Uang Cash" default untuk pengguna baru
  /// saat pertama kali mendaftar, jika daftar platformnya masih kosong.
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

  /// Mengambil seluruh platform aset milik [userId], diurutkan secara ascending berdasarkan [id].
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

  /// Mengambil satu platform aset berdasarkan [id] dan [userId].
  /// Mengembalikan `null` jika platform tidak ditemukan.
  Future<AssetPlatform?> getById(int id, String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableAssetPlatforms,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AssetPlatform.fromMap(rows.first);
  }

  /// Menghitung akumulasi total saldo seluruh aset yang dimiliki oleh [userId].
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

  /// Memperbarui nominal saldo pada platform tertentu berdasarkan [id] dan [userId].
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

  /// Menghapus platform aset dengan validasi saldo.
  /// Hanya dapat dihapus jika saldonya bernilai 0 untuk menjaga integritas data keuangan.
  /// Mengembalikan `true` jika berhasil dihapus, `false` jika masih terdapat saldo (> 0).
  Future<bool> delete(int id, String userId) async {
    final db = await _db.database;

    // Validasi apakah saldo pada platform masih tersisa
    final rows = await db.query(
      DatabaseHelper.tableAssetPlatforms,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final balance = (rows.first['balance'] as num).toDouble();
    if (balance != 0) return false; // Masih ada aset, cegah penghapusan

    await db.delete(
      DatabaseHelper.tableAssetPlatforms,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    return true;
  }

  /// Memeriksa apakah nama platform sudah pernah digunakan oleh [userId]
  /// untuk mencegah duplikasi nama dompet (case-insensitive).
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
