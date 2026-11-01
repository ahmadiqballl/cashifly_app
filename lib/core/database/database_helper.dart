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
  static const int _dbVersion = 1;

  // Nama tabel
  static const String tableTransactions = 'transactions';

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
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id   TEXT    NOT NULL,
        type      TEXT    NOT NULL CHECK(type IN ('income', 'expense')),
        amount    REAL    NOT NULL,
        category  TEXT    NOT NULL,
        note      TEXT,
        date      TEXT    NOT NULL
      )
    ''');

    // Index agar query per user_id + date lebih cepat
    await db.execute('''
      CREATE INDEX idx_transactions_user_date
      ON $tableTransactions (user_id, date)
    ''');
  }

  /// Dipanggil saat versi database meningkat — untuk migrasi skema ke depan
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
        'DatabaseHelper: upgrade dari versi $oldVersion ke $newVersion');
    // Tambahkan blok migrasi di sini jika skema berubah di versi mendatang
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
