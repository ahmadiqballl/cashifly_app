import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// ============================================================================
/// DatabaseHelper
/// ============================================================================
/// Kelas pengelola (helper) database lokal SQLite untuk seluruh aplikasi Cashifly.
/// 
/// Menerapkan pola **Singleton Pattern** agar hanya ada satu koneksi database 
/// yang aktif dan digunakan bersama oleh seluruh repository.
/// 
/// Pemisahan data antar akun pengguna dilakukan secara aman melalui filter 
/// kolom `user_id` (UID Firebase Auth) di setiap tabel.
class DatabaseHelper {
  // ── Konstruktor Privat & Singleton ─────────────────────────────────────────
  /// Konstruktor privat untuk mencegah pembuatan instance baru dari luar kelas.
  DatabaseHelper._internal();

  /// Instance tunggal global yang dapat diakses di seluruh aplikasi (DatabaseHelper.instance).
  static final DatabaseHelper instance = DatabaseHelper._internal();

  // ── Konfigurasi Database ────────────────────────────────────────────────────
  /// Nama file fisik database SQLite yang disimpan di memori internal perangkat.
  static const String _dbName = 'cashifly.db';

  /// Nomor versi skema database saat ini (v8).
  /// Setiap kali struktur tabel diubah/ditambah, versi ini dinaikkan agar _onUpgrade terpanggil.
  static const int _dbVersion = 8; // v8: tabel monthly_reports

  // ── Konstanta Nama Tabel ───────────────────────────────────────────────────
  /// Tabel riwayat transaksi (pemasukan, pengeluaran, transfer).
  static const String tableTransactions = 'transactions';

  /// Tabel akun/platform dompet aset (Uang Cash, Rekening Bank, E-Wallet).
  static const String tableAssetPlatforms = 'asset_platforms';

  /// Tabel riwayat pengiriman notifikasi lokal ke perangkat.
  static const String tableNotificationLog = 'notification_log';

  /// Tabel arsip otomatis laporan keuangan bulanan per tanggal 1.
  static const String tableMonthlyReports = 'monthly_reports';

  /// Variabel penampung instance database SQLite yang sedang aktif.
  Database? _database;

  // ── Getter Database ────────────────────────────────────────────────────────
  /// Mengembalikan instance koneksi [Database].
  /// Menggunakan teknik *Lazy Initialization*: jika koneksi belum terbuka, 
  /// fungsi akan memanggil [_initDatabase] terlebih dahulu sebelum mengembalikannya.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // ── Inisialisasi Database ───────────────────────────────────────────────────
  /// Menginisialisasi file database pada path direktori lokal aplikasi.
  /// Memanggil [openDatabase] yang otomatis memicu [_onCreate] saat pertama dibuat
  /// atau [_onUpgrade] jika terjadi kenaikan versi skema.
  Future<Database> _initDatabase() async {
    // Mengambil direktori sistem tempat penyimpanan database lokal perangkat
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

  // ── Pembuatan Tabel Pertama Kali (_onCreate) ───────────────────────────────
  /// Callback yang dipanggil sekali saja saat file database pertama kali dibuat di HP.
  /// Berfungsi mengeksekusi DDL (Data Definition Language) seluruh tabel awal.
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('DatabaseHelper: membuat tabel awal (versi $version)');

    // 1. Membuat tabel 'transactions' untuk mencatat mutasi keuangan
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

    // Indeks untuk mempercepat pencarian transaksi berdasarkan user dan tanggal
    await db.execute('''
      CREATE INDEX idx_transactions_user_date
      ON $tableTransactions (user_id, date)
    ''');

    // 2. Membuat tabel-tabel pendukung lainnya
    await _createAssetPlatformsTable(db);
    await _createNotificationLogTable(db);
    await _createMonthlyReportsTable(db);
  }

  // ── DDL Tabel Monthly Reports ──────────────────────────────────────────────
  /// Membuat tabel [tableMonthlyReports] untuk mengarsipkan rekapitulasi 
  /// keuangan bulanan otomatis per tanggal 1.
  /// Dilengkapi constraint `UNIQUE(user_id, year, month) ON CONFLICT REPLACE` 
  /// agar data rekapitulasi bulan yang sama otomatis ter-update dan tidak terduplikasi.
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

    // Indeks untuk pencarian laporan berdasarkan user dan tahun
    await db.execute('''
      CREATE INDEX idx_monthly_reports_user_year
      ON $tableMonthlyReports (user_id, year, month)
    ''');
  }

  // ── DDL Tabel Asset Platforms ──────────────────────────────────────────────
  /// Membuat tabel [tableAssetPlatforms] untuk menyimpan dompet/platform aset 
  /// milik pengguna (Cash, Bank, E-Wallet) beserta saldo terbarunya.
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

    // Indeks untuk mempercepat pengambilan daftar dompet milik pengguna tertentu
    await db.execute('''
      CREATE INDEX idx_asset_platforms_user
      ON $tableAssetPlatforms (user_id)
    ''');
  }

  // ── DDL Tabel Notification Log ─────────────────────────────────────────────
  /// Membuat tabel [tableNotificationLog] untuk mencatat seluruh riwayat notifikasi lokal
  /// yang pernah dikirimkan ke status bar perangkat pengguna.
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

    // Indeks pencarian riwayat notifikasi berdasarkan urutan waktu pembuatan
    await db.execute('''
      CREATE INDEX idx_notification_log_user_created
      ON $tableNotificationLog (user_id, created_at)
    ''');
  }

  // ── Migrasi Database (_onUpgrade) ──────────────────────────────────────────
  /// Callback yang otomatis dieksekusi saat nomor [_dbVersion] lebih tinggi dari 
  /// versi database yang terpasang di HP pengguna.
  /// 
  /// Pola migrasi berurutan (incremental migration) digunakan agar data pengguna
  /// yang sudah tersimpan sebelumnya TIDAK HILANG atau terhapus.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
        'DatabaseHelper: upgrade skema dari versi $oldVersion ke $newVersion');

    if (oldVersion < 2) {
      // Migrasi v1 → v2: Penambahan fitur manajemen dompet aset (asset_platforms)
      await _createAssetPlatformsTable(db);
    }
    if (oldVersion < 3) {
      // Migrasi v2 → v3: Menghubungkan transaksi dengan platform dompet asal
      await db.execute(
        'ALTER TABLE $tableTransactions ADD COLUMN platform_id INTEGER',
      );
    }
    if (oldVersion < 4) {
      // Migrasi v3 → v4: Penambahan fitur pencatatan log notifikasi
      await _createNotificationLogTable(db);
    }
    if (oldVersion < 5) {
      // Migrasi v4 → v5: Penambahan informasi jam/waktu transaksi (HH:mm)
      await db.execute(
        "ALTER TABLE $tableTransactions ADD COLUMN time TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 6) {
      // Migrasi v5 → v6: Penambahan path attachment foto bukti struk belanja
      await db.execute(
        'ALTER TABLE $tableTransactions ADD COLUMN image_path TEXT',
      );
    }
    if (oldVersion < 7) {
      // Migrasi v6 → v7: Penambahan fitur transfer saldo antar-akun
      // Karena SQLite tidak mendukung ALTER CHECK constraint secara langsung,
      // digunakan teknik tabel sementara (transactions_temp) untuk migrasi data yang aman.
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
      // Salin seluruh data transaksi lama ke tabel sementara
      await db.execute('''
        INSERT INTO transactions_temp (id, user_id, type, amount, category, note, date, time, image_path, platform_id)
        SELECT id, user_id, type, amount, category, note, date, time, image_path, platform_id FROM $tableTransactions
      ''');
      // Hapus tabel lama dan ganti nama tabel sementara menjadi tabel utama
      await db.execute('DROP TABLE $tableTransactions');
      await db.execute('ALTER TABLE transactions_temp RENAME TO $tableTransactions');
      await db.execute('''
        CREATE INDEX idx_transactions_user_date
        ON $tableTransactions (user_id, date)
      ''');
    }
    if (oldVersion < 8) {
      // Migrasi v7 → v8: Penambahan tabel arsip laporan keuangan bulanan otomatis
      await _createMonthlyReportsTable(db);
    }
  }

  // ── Penutupan Koneksi Database ─────────────────────────────────────────────
  /// Menutup koneksi database yang sedang terbuka (biasanya digunakan saat unit testing atau reset).
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
