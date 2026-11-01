import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Singleton helper untuk membuka dan mengelola database SQLite.
///
/// Satu file database digunakan untuk seluruh aplikasi.
/// Pemisahan data antar pengguna dilakukan via kolom [user_id] di setiap tabel.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'cashifly.db';
  static const int _dbVersion = 3; // v3: tambah kolom platform_id di transactions

  // Nama tabel
  static const String tableTransactions = 'transactions';
  static const String tableAssetPlatforms = 'asset_platforms';

  Database? _database;

  /// Mengembalikan instance database, membukanya terlebih dahulu jika belum ada
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    debugPrint('DatabaseHelper: membuka database di $path');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Dipanggil sekali saat database pertama kali dibuat
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('DatabaseHelper: membuat tabel (versi $version)');

    await db.execute('''
      CREATE TABLE $tableTransactions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT    NOT NULL,
        type        TEXT    NOT NULL CHECK(type IN ('income', 'expense')),
        amount      REAL    NOT NULL,
        category    TEXT    NOT NULL,
        note        TEXT,
        date        TEXT    NOT NULL,
        platform_id INTEGER REFERENCES $tableAssetPlatforms(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_user_date
      ON $tableTransactions (user_id, date)
    ''');

    await _createAssetPlatformsTable(db);
  }

  Future<void> _createAssetPlatformsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableAssetPlatforms (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT    NOT NULL,
        type        TEXT    NOT NULL CHECK(type IN ('cash', 'bank', 'ewallet')),
        name        TEXT    NOT NULL,
        balance     REAL    NOT NULL DEFAULT 0,
        color_value INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_asset_platforms_user
      ON $tableAssetPlatforms (user_id)
    ''');
  }

  /// Dipanggil saat versi database meningkat — untuk migrasi skema ke depan
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
        'DatabaseHelper: upgrade dari versi $oldVersion ke $newVersion');

    if (oldVersion < 2) {
      // Migrasi v1 → v2: tambah tabel asset_platforms
      await _createAssetPlatformsTable(db);
    }
    if (oldVersion < 3) {
      // Migrasi v2 → v3: tambah kolom platform_id ke transactions
      await db.execute(
        'ALTER TABLE $tableTransactions ADD COLUMN platform_id INTEGER',
      );
    }
  }

  /// Tutup koneksi database (opsional, untuk testing)
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
