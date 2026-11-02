/// Model satu entri log notifikasi milestone
class NotificationLog {
  final int? id;

  /// UID Firebase Auth
  final String userId;

  /// Judul notifikasi yang ditampilkan
  final String title;

  /// Isi notifikasi yang ditampilkan
  final String body;

  /// Waktu notifikasi dikirim — format ISO-8601: "2026-11-01T08:00:00.000"
  final DateTime createdAt;

  const NotificationLog({
    this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'title': title,
        'body': body,
        'created_at': createdAt.toIso8601String(),
      };

  factory NotificationLog.fromMap(Map<String, dynamic> map) => NotificationLog(
        id: map['id'] as int?,
        userId: map['user_id'] as String,
        title: map['title'] as String,
        body: map['body'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
