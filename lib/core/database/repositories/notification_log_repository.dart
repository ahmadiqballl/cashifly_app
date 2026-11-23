import '../database_helper.dart';
import '../models/notification_log_model.dart';

/// ============================================================================
/// NotificationLogRepository
/// ============================================================================
/// Repository untuk mengelola riwayat log notifikasi lokal di perangkat.
///
/// Mengimplementasikan kebijakan retensi data otomatis:
/// Setiap entri log hanya disimpan selama 14 hari. Entri yang lebih tua dari itu
/// akan otomatis dihapus (*auto purge*) saat fungsi [insert] atau [getAll] dipanggil.
class NotificationLogRepository {
  final DatabaseHelper _db;

  NotificationLogRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  /// Batas masa simpan log notifikasi (14 hari).
  static const int _retentionDays = 14;

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Menyimpan log notifikasi baru ke database SQLite, 
  /// sekaligus membersihkan entri notifikasi lama yang sudah melewati batas retensi.
  Future<void> insert(NotificationLog log) async {
    final db = await _db.database;
    await db.insert(DatabaseHelper.tableNotificationLog, log.toMap());
    await _deleteExpired(db, log.userId);
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Mengambil seluruh riwayat log notifikasi milik [userId] dalam 14 hari terakhir,
  /// diurutkan dari waktu terbaru ke terlama.
  Future<List<NotificationLog>> getAll(String userId) async {
    final db = await _db.database;
    await _deleteExpired(db, userId);
    final rows = await db.query(
      DatabaseHelper.tableNotificationLog,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(NotificationLog.fromMap).toList();
  }

  // ── Delete (Pembersihan Otomatis) ──────────────────────────────────────────

  /// Menghapus seluruh entri log milik [userId] yang berusia lebih dari [_retentionDays] hari.
  Future<void> _deleteExpired(dynamic db, String userId) async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _retentionDays))
        .toIso8601String();
    await db.delete(
      DatabaseHelper.tableNotificationLog,
      where: 'user_id = ? AND created_at < ?',
      whereArgs: [userId, cutoff],
    );
  }
}
