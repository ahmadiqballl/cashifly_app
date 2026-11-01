import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum LegalType { terms, privacy }

/// Bottom sheet gelap untuk menampilkan Terms & Conditions atau Privacy Policy.
class LegalBottomSheet extends StatelessWidget {
  final LegalType type;

  const LegalBottomSheet({super.key, required this.type});

  static Future<void> show(BuildContext context, LegalType type) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LegalBottomSheet(type: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTerms = type == LegalType.terms;
    final title = isTerms ? 'Terms & Conditions' : 'Privacy Policy';
    final content = isTerms ? _termsContent : _privacyContent;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Judul
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Konten scrollable
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Text(
                    content,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const String _termsContent = '''
Selamat datang di Cashifly. Dengan menggunakan aplikasi ini, Anda menyetujui syarat dan ketentuan berikut.

1. Penggunaan Layanan
Aplikasi Cashifly dirancang untuk membantu Anda mencatat dan mengelola keuangan pribadi. Anda bertanggung jawab atas semua aktivitas yang dilakukan melalui akun Anda.

2. Akun Pengguna
Anda wajib menjaga kerahasiaan kredensial akun Anda. Cashifly tidak bertanggung jawab atas kerugian akibat penyalahgunaan akun yang disebabkan kelalaian pengguna.

3. Data Keuangan
Data keuangan yang Anda masukkan disimpan secara lokal di perangkat Anda. Cashifly tidak mengakses atau menyimpan data keuangan Anda di server kami.

4. Perubahan Layanan
Kami berhak mengubah fitur, tampilan, atau kebijakan layanan sewaktu-waktu dengan pemberitahuan sebelumnya melalui aplikasi.

5. Batasan Tanggung Jawab
Cashifly tidak bertanggung jawab atas keputusan keuangan yang dibuat berdasarkan data dalam aplikasi ini.
''';

  static const String _privacyContent = '''
Kebijakan Privasi ini menjelaskan bagaimana Cashifly mengumpulkan, menggunakan, dan melindungi informasi Anda.

1. Informasi yang Dikumpulkan
Kami mengumpulkan alamat email Anda untuk keperluan autentikasi melalui layanan Firebase Authentication. Data keuangan Anda disimpan sepenuhnya secara lokal di perangkat Anda.

2. Penggunaan Informasi
Email Anda digunakan hanya untuk proses masuk dan verifikasi akun. Kami tidak menjual atau berbagi informasi pribadi Anda kepada pihak ketiga.

3. Keamanan Data
Kami menggunakan enkripsi standar industri untuk melindungi data autentikasi Anda. Password Anda tidak pernah disimpan dalam bentuk teks biasa.

4. Hak Pengguna
Anda memiliki hak untuk menghapus akun Anda kapan saja. Penghapusan akun akan menghapus data autentikasi Anda dari sistem kami.

5. Perubahan Kebijakan
Kebijakan privasi ini dapat diperbarui. Kami akan memberitahu Anda melalui aplikasi jika ada perubahan yang signifikan.

6. Kontak
Jika Anda memiliki pertanyaan mengenai kebijakan privasi ini, silakan hubungi kami melalui aplikasi.
''';
}
