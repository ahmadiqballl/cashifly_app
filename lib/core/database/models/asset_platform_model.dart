/// Tipe platform aset
enum PlatformType { cash, bank, ewallet }

/// Daftar bank yang tersedia
enum BankOption {
  bri('Bank BRI'),
  bca('Bank BCA'),
  mandiri('Bank Mandiri'),
  bni('Bank BNI'),
  cimb('Bank CIMB Niaga'),
  danamon('Bank Danamon'),
  permata('Bank Permata'),
  btn('Bank BTN'),
  ocbc('Bank OCBC'),
  panin('Bank Panin');

  final String label;
  const BankOption(this.label);
}

/// Daftar e-wallet yang tersedia
enum EWalletOption {
  gopay('GoPay'),
  ovo('OVO'),
  dana('DANA'),
  shopeepay('ShopeePay'),
  linkaja('LinkAja'),
  jenius('Jenius'),
  sakuku('Sakuku'),
  isaku('iSaku');

  final String label;
  const EWalletOption(this.label);
}

/// Model satu platform aset (Cash / Bank / E-Wallet)
class AssetPlatform {
  final int? id;

  /// UID Firebase Auth — pemisah data antar pengguna
  final String userId;

  final PlatformType type;

  /// Nama tampilan (misal: "Bank BRI", "GoPay", "Uang Cash")
  final String name;

  /// Saldo platform (default 0)
  final double balance;

  /// Warna kartu — disimpan sebagai ARGB integer (Color.value)
  final int colorValue;

  const AssetPlatform({
    this.id,
    required this.userId,
    required this.type,
    required this.name,
    this.balance = 0,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'type': type.name,
        'name': name,
        'balance': balance,
        'color_value': colorValue,
      };

  factory AssetPlatform.fromMap(Map<String, dynamic> map) => AssetPlatform(
        id: map['id'] as int?,
        userId: map['user_id'] as String,
        type: PlatformType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => PlatformType.cash,
        ),
        name: map['name'] as String,
        balance: (map['balance'] as num).toDouble(),
        colorValue: map['color_value'] as int,
      );

  AssetPlatform copyWith({
    int? id,
    String? userId,
    PlatformType? type,
    String? name,
    double? balance,
    int? colorValue,
  }) =>
      AssetPlatform(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        type: type ?? this.type,
        name: name ?? this.name,
        balance: balance ?? this.balance,
        colorValue: colorValue ?? this.colorValue,
      );
}

/// Warna per brand platform (ARGB) — berdasarkan identitas visual nyata
class PlatformColors {
  // Cash
  static const int cash = 0xFF72B9FF; // biru aksen cashifly

  // Bank — warna identitas masing-masing bank
  static const Map<String, int> bank = {
    'Bank BRI':        0xFF003087, // biru tua BRI
    'Bank BCA':        0xFF005BAA, // biru BCA
    'Bank Mandiri':    0xFF003087, // biru tua Mandiri
    'Bank BNI':        0xFFFF6B00, // oranye BNI
    'Bank CIMB Niaga': 0xFF8B0000, // merah tua CIMB
    'Bank Danamon':    0xFFE31837, // merah Danamon
    'Bank Permata':    0xFF0057A8, // biru Permata
    'Bank BTN':        0xFF005BAA, // biru BTN
    'Bank OCBC':       0xFFE63329, // merah OCBC
    'Bank Panin':      0xFF003087, // biru Panin
  };

  // E-Wallet — warna identitas masing-masing dompet digital
  static const Map<String, int> ewallet = {
    'GoPay':     0xFF00AA13, // hijau Gojek/GoPay
    'OVO':       0xFF4C3494, // ungu OVO
    'DANA':      0xFF118EEA, // biru DANA
    'ShopeePay': 0xFFEE4D2D, // oranye Shopee
    'LinkAja':   0xFFE82529, // merah LinkAja
    'Jenius':    0xFF1A73E8, // biru Jenius
    'Sakuku':    0xFF0066CC, // biru Sakuku BCA
    'iSaku':     0xFFFF6600, // oranye iSaku
  };

  /// Kembalikan warna untuk platform tertentu berdasarkan nama.
  static int colorFor(PlatformType type, String name) {
    if (type == PlatformType.cash) return cash;
    if (type == PlatformType.bank) {
      return bank[name] ?? 0xFF0D1F3C;
    }
    return ewallet[name] ?? 0xFF2E9E44;
  }
}
