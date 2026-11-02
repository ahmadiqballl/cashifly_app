import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/models/notification_log_model.dart';
import '../database/repositories/notification_log_repository.dart';

/// Layanan notifikasi lokal — singleton sederhana.
/// Inisialisasi sekali di main(), lalu panggil [showMilestone] kapan saja.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final _logRepo = NotificationLogRepository();

  bool _initialized = false;

  static const _channelId = 'cashifly_milestone';
  static const _channelName = 'Pencapaian Aset';
  static const _channelDesc =
      'Notifikasi saat total aset mencapai kelipatan Rp100.000';

  /// Inisialisasi plugin. Panggil sekali dari main() setelah
  /// WidgetsFlutterBinding.ensureInitialized().
  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    // Minta izin notifikasi di Android 13+ (API 33)
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('NotificationService: initialized');
  }

  /// Tampilkan notifikasi milestone dan simpan ke log.
  /// [totalBaru] adalah total aset setelah transaksi (dalam Rupiah).
  /// [userId] dibutuhkan untuk menyimpan log per pengguna.
  Future<void> showMilestone(double totalBaru, {required String userId}) async {
    if (!_initialized) return;

    final formatted = _formatRupiah(totalBaru);
    const title = 'Wahh, pencapaian baru! 🎉';
    final body = 'Uangmu sekarang sudah mencapai $formatted lho, keren banget!';

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

    await _plugin.show(
      0, // id tetap 0 — satu notif, di-replace jika muncul lagi
      title,
      body,
      details,
    );

    // Simpan ke log agar bisa ditampilkan di tab Notifikasi
    await _logRepo.insert(NotificationLog(
      userId: userId,
      title: title,
      body: body,
      createdAt: DateTime.now(),
    ));
  }

  /// Format: 110000.0 → "Rp110.000"  (tanpa desimal)
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
