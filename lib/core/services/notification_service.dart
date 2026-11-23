import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/models/notification_log_model.dart';
import '../database/repositories/notification_log_repository.dart';

/// ============================================================================
/// NotificationService
/// ============================================================================
/// Layanan (Service) sentral untuk mengelola notifikasi lokal pada perangkat.
///
/// Menerapkan pola **Singleton Pattern** agar inisialisasi plugin hanya dilakukan
/// sekali saat startup di `main.dart`, kemudian dapat dipicu dari mana saja.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Plugin resmi flutter_local_notifications untuk komunikasi dengan OS Android & iOS.
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final _logRepo = NotificationLogRepository();

  bool _initialized = false;

  /// Konfigurasi Channel Notifikasi Android (Wajib untuk Android 8.0 Oreo ke atas)
  static const _channelId = 'cashifly_milestone';
  static const _channelName = 'Pencapaian Aset';
  static const _channelDesc =
      'Notifikasi saat total aset mencapai kelipatan Rp100.000';

  // ── Inisialisasi Service ───────────────────────────────────────────────────

  /// Menginisialisasi pengaturan notifikasi untuk Android dan iOS.
  /// Wajib dipanggil sekali di fungsi `main()` setelah `WidgetsFlutterBinding.ensureInitialized()`.
  Future<void> init() async {
    if (_initialized) return;

    // Pengaturan icon launcher di Android (res/mipmap/ic_launcher)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    // Meminta izin runtime notifikasi khusus untuk Android 13+ (API level 33 ke atas)
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('NotificationService: inisialisasi berhasil');
  }

  // ── Pemicu Notifikasi Milestone ────────────────────────────────────────────

  /// Menampilkan notifikasi pencapaian (*milestone*) saat saldo bertambah,
  /// sekaligus mencatatnya ke tabel riwayat notifikasi lokal SQLite.
  ///
  /// Parameter:
  /// - [totalBaru]: Nominal total aset terkini setelah mutasi transaksi.
  /// - [userId]: UID akun pengguna yang sedang aktif.
  Future<void> showMilestone(double totalBaru, {required String userId}) async {
    if (!_initialized) return;

    final formatted = _formatRupiah(totalBaru);
    const title = 'Wahh, pencapaian baru! 🎉';
    final body = 'Uangmu sekarang sudah mencapai $formatted lho, keren banget!';

    // Konfigurasi prioritas tinggi agar banner notifikasi muncul di layar atas (heads-up)
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Tampilkan notifikasi ke status bar
    await _plugin.show(
      0, // ID notifikasi tetap 0 agar notifikasi baru memperbarui yang lama
      title,
      body,
      details,
    );

    // Simpan ke log database SQLite agar pengguna bisa melihat riwayatnya di aplikasi
    await _logRepo.insert(NotificationLog(
      userId: userId,
      title: title,
      body: body,
      createdAt: DateTime.now(),
    ));
  }

  // ── Formatter Rupiah ───────────────────────────────────────────────────────

  /// Memformat angka nominal menjadi representasi mata uang Rupiah tanpa desimal
  /// Contoh: 110000.0 → "Rp110.000"
  static String _formatRupiah(double amount) {
    final intPart = amount.toInt().toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
      count++;
    }
    return 'Rp${buf.toString().split('').reversed.join()}';
  }
}
