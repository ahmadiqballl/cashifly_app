import '../database_helper.dart';
import '../models/notification_log_model.dart';

/// Repository untuk log notifikasi milestone.
///
/// Setiap entry hanya disimpan selama 14 hari — lebih dari itu otomatis dihapus
/// saat [insert] atau [getAll] dipanggil.
class NotificationLogRepository {
  final DatabaseHelper _db;

  NotificationLogRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  static const int _retentionDays = 14;

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Simpan log notifikasi baru, sekaligus bersihkan entri yang sudah kadaluarsa.
  Future<void> insert(NotificationLog log) async {
    final db = await _db.database;
    await db.insert(DatabaseHelper.tableNotificationLog, log.toMap());
    await _deleteExpired(db, log.userId);
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Ambil semua log notifikasi milik [userId] dalam 14 hari terakhir,
  /// diurutkan terbaru di atas. Sekaligus bersihkan yang kadaluarsa.
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

  // ── Delete ─────────────────────────────────────────────────────────────────

  /// Hapus semua log milik [userId] yang lebih tua dari [_retentionDays] hari.
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
