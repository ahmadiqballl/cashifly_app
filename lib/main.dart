import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_colors.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar: ikon & teks hitam (cocok untuk layar putih)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,   // Android
    statusBarBrightness: Brightness.light,       // iOS
  ));

  // Inisialisasi notifikasi lokal
  await NotificationService.instance.init();

  String? initError;
  try {
    await FirebaseService.initialize();
  } catch (e) {
    initError = e.toString();
  }

  runApp(CashiflyApp(initializationError: initError));
}

class CashiflyApp extends StatelessWidget {
  final String? initializationError;

  const CashiflyApp({super.key, this.initializationError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cashifly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: initializationError != null
          ? _buildErrorScreen(initializationError!)
          : const AuthGate(),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Perhatian Platform / Konfigurasi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kIsWeb
                        ? 'Untuk Web, pastikan web credentials di lib/firebase_options.dart sudah aktif.'
                        : (defaultTargetPlatform == TargetPlatform.linux ||
                                defaultTargetPlatform == TargetPlatform.windows ||
                                defaultTargetPlatform == TargetPlatform.macOS)
                            ? 'Aplikasi ini adalah Praktikum Pemrograman Aplikasi Mobile yang menggunakan Firebase Auth untuk Android/iOS.\n\n'
                                'Linux Desktop tidak memiliki runtime native Firebase. Silakan jalankan aplikasi pada:\n'
                                '1. Android Emulator (AVD)\n'
                                '2. Perangkat Android fisik via USB Debugging (flutter run -d <device-id>)\n'
                                '3. Google Chrome (flutter run -d chrome)\n\n'
                                'Detail error:\n$error'
                            : 'Pastikan file google-services.json telah diletakkan di folder android/app/ dan package name cocok.\n\nDetail:\n$error',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
