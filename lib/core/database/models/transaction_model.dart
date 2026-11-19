/// Tipe transaksi: pemasukan, pengeluaran, atau transfer/pindah saldo
enum TransactionType { income, expense, transfer }

// Sentinel untuk membedakan "tidak di-pass" vs "null disengaja" di copyWith
const Object _sentinel = Object();

/// Model satu baris transaksi keuangan
class TransactionModel {
  final int? id;

  /// UID dari Firebase Auth — digunakan untuk memisahkan data antar akun
  final String userId;

  final TransactionType type;
  final double amount;
  final String category;
  final String? note;

  /// Format ISO-8601: "2026-11-01"
  final String date;

  /// Format "HH:mm", contoh: "08:30"
  final String time;

  /// Path absolut file gambar yang sudah dikompresi, atau null jika tidak ada
  final String? imagePath;

  /// ID platform aset yang terkait (sumber jika transfer, atau akun untuk pemasukan/pengeluaran)
  final int? platformId;

  /// ID platform tujuan (khusus untuk tipe transfer)
  final int? toPlatformId;

  const TransactionModel({
    this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
    this.time = '',
    this.imagePath,
    this.platformId,
    this.toPlatformId,
  });

  // ── Serialisasi ────────────────────────────────────────────────────────────

  /// Konversi ke Map untuk disimpan ke SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'type': type.name, // "income", "expense", atau "transfer"
      'amount': amount,
      'category': category,
      'note': note,
      'date': date,
      'time': time,
      'image_path': imagePath,
      'platform_id': platformId,
      'to_platform_id': toPlatformId,
    };
  }

  /// Buat TransactionModel dari baris SQLite
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      note: map['note'] as String?,
      date: map['date'] as String,
      time: (map['time'] as String?) ?? '',
      imagePath: map['image_path'] as String?,
      platformId: map['platform_id'] as int?,
      toPlatformId: map['to_platform_id'] as int?,
    );
  }

  /// Salin model dengan perubahan field tertentu
  TransactionModel copyWith({
    int? id,
    String? userId,
    TransactionType? type,
    double? amount,
    String? category,
    String? note,
    String? date,
    String? time,
    Object? imagePath = _sentinel,
    int? platformId,
    int? toPlatformId,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      time: time ?? this.time,
      imagePath: imagePath == _sentinel
          ? this.imagePath
          : imagePath as String?,
      platformId: platformId ?? this.platformId,
      toPlatformId: toPlatformId ?? this.toPlatformId,
    );
  }

  @override
  String toString() =>
      'TransactionModel(id: $id, userId: $userId, type: ${type.name}, '
      'amount: $amount, category: $category, date: $date, platformId: $platformId, toPlatformId: $toPlatformId)';
}
