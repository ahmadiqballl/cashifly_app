/// Tipe transaksi: pemasukan atau pengeluaran
enum TransactionType { income, expense }

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

  const TransactionModel({
    this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
  });

  // ── Serialisasi ────────────────────────────────────────────────────────────

  /// Konversi ke Map untuk disimpan ke SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'type': type.name, // "income" atau "expense"
      'amount': amount,
      'category': category,
      'note': note,
      'date': date,
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
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }

  @override
  String toString() =>
      'TransactionModel(id: $id, userId: $userId, type: ${type.name}, '
      'amount: $amount, category: $category, date: $date)';
}
