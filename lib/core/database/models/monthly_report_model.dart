/// Model satu baris arsip laporan keuangan bulanan otomatis
class MonthlyReport {
  final int? id;
  final String userId;
  final int year;
  final int month;
  final String monthName;
  final double totalIncome;
  final double totalExpense;
  final double totalTransfer;
  final double netBalance;
  final int transactionCount;
  final String createdAt;

  const MonthlyReport({
    this.id,
    required this.userId,
    required this.year,
    required this.month,
    required this.monthName,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalTransfer,
    required this.netBalance,
    required this.transactionCount,
    required this.createdAt,
  });

  /// Singkatan nama bulan (misal: "Jan", "Feb", "Mar")
  String get monthShort {
    const shorts = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    if (month >= 1 && month <= 12) return shorts[month];
    return monthName;
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'year': year,
        'month': month,
        'month_name': monthName,
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'total_transfer': totalTransfer,
        'net_balance': netBalance,
        'transaction_count': transactionCount,
        'created_at': createdAt,
      };

  factory MonthlyReport.fromMap(Map<String, dynamic> map) => MonthlyReport(
        id: map['id'] as int?,
        userId: map['user_id'] as String,
        year: map['year'] as int,
        month: map['month'] as int,
        monthName: map['month_name'] as String,
        totalIncome: (map['total_income'] as num).toDouble(),
        totalExpense: (map['total_expense'] as num).toDouble(),
        totalTransfer: (map['total_transfer'] as num).toDouble(),
        netBalance: (map['net_balance'] as num).toDouble(),
        transactionCount: map['transaction_count'] as int,
        createdAt: map['created_at'] as String,
      );
}
