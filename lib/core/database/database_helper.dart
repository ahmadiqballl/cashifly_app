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
  static const int _dbVersion = 8; // v8: tabel monthly_reports

  // Nama tabel
  static const String tableTransactions = 'transactions';
  static const String tableAssetPlatforms = 'asset_platforms';
  static const String tableNotificationLog = 'notification_log';
  static const String tableMonthlyReports = 'monthly_reports';

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
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id        TEXT    NOT NULL,
        type           TEXT    NOT NULL CHECK(type IN ('income', 'expense', 'transfer')),
        amount         REAL    NOT NULL,
        category       TEXT    NOT NULL,
        note           TEXT,
        date           TEXT    NOT NULL,
        time           TEXT    NOT NULL DEFAULT '',
        image_path     TEXT,
        platform_id    INTEGER REFERENCES $tableAssetPlatforms(id) ON DELETE SET NULL,
        to_platform_id INTEGER REFERENCES $tableAssetPlatforms(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_user_date
      ON $tableTransactions (user_id, date)
    ''');

    await _createAssetPlatformsTable(db);
    await _createNotificationLogTable(db);
    await _createMonthlyReportsTable(db);
  }

  Future<void> _createMonthlyReportsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableMonthlyReports (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id           TEXT    NOT NULL,
        year              INTEGER NOT NULL,
        month             INTEGER NOT NULL,
        month_name        TEXT    NOT NULL,
        total_income      REAL    NOT NULL DEFAULT 0,
        total_expense     REAL    NOT NULL DEFAULT 0,
        total_transfer    REAL    NOT NULL DEFAULT 0,
        net_balance       REAL    NOT NULL DEFAULT 0,
        transaction_count INTEGER NOT NULL DEFAULT 0,
        created_at        TEXT    NOT NULL,
        UNIQUE(user_id, year, month) ON CONFLICT REPLACE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_monthly_reports_user_year
      ON $tableMonthlyReports (user_id, year, month)
    ''');
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

  Future<void> _createNotificationLogTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableNotificationLog (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    TEXT    NOT NULL,
        title      TEXT    NOT NULL,
        body       TEXT    NOT NULL,
        created_at TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_notification_log_user_created
      ON $tableNotificationLog (user_id, created_at)
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
    if (oldVersion < 4) {
      // Migrasi v3 → v4: tambah tabel notification_log
      await _createNotificationLogTable(db);
    }
    if (oldVersion < 5) {
      // Migrasi v4 → v5: tambah kolom time ke transactions
      await db.execute(
        "ALTER TABLE $tableTransactions ADD COLUMN time TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 6) {
      // Migrasi v5 → v6: tambah kolom image_path ke transactions
      await db.execute(
        'ALTER TABLE $tableTransactions ADD COLUMN image_path TEXT',
      );
    }
    if (oldVersion < 7) {
      // Migrasi v6 → v7: update CHECK constraint type agar dukung 'transfer' dan tambah to_platform_id
      await db.execute('''
        CREATE TABLE transactions_temp (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id        TEXT    NOT NULL,
          type           TEXT    NOT NULL CHECK(type IN ('income', 'expense', 'transfer')),
          amount         REAL    NOT NULL,
          category       TEXT    NOT NULL,
          note           TEXT,
          date           TEXT    NOT NULL,
          time           TEXT    NOT NULL DEFAULT '',
          image_path     TEXT,
          platform_id    INTEGER REFERENCES $tableAssetPlatforms(id) ON DELETE SET NULL,
          to_platform_id INTEGER REFERENCES $tableAssetPlatforms(id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        INSERT INTO transactions_temp (id, user_id, type, amount, category, note, date, time, image_path, platform_id)
        SELECT id, user_id, type, amount, category, note, date, time, image_path, platform_id FROM $tableTransactions
      ''');
      await db.execute('DROP TABLE $tableTransactions');
      await db.execute('ALTER TABLE transactions_temp RENAME TO $tableTransactions');
      await db.execute('''
        CREATE INDEX idx_transactions_user_date
        ON $tableTransactions (user_id, date)
      ''');
    }
    if (oldVersion < 8) {
      // Migrasi v7 → v8: tambah tabel monthly_reports
      await _createMonthlyReportsTable(db);
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
