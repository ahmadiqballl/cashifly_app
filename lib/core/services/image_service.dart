import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// ============================================================================
/// ImageService
/// ============================================================================
/// Layanan (Service) untuk mengelola file gambar attachment bukti struk transaksi:
/// 1. Mengambil foto dari Kamera atau Galeri perangkat (`image_picker`).
/// 2. Mengompresi resolusi gambar (max 800px, kualitas 75%) agar hemat ruang memori.
/// 3. Menyimpan file gambar ke direktori privat aplikasi (bukan disimpan mentah sebagai BLOB SQLite).
/// 4. Menyediakan fitur *housekeeping* / *cleanup* otomatis untuk menghapus gambar tak terpakai (*orphan files*).
class ImageService {
  ImageService._();
  static final ImageService instance = ImageService._();

  /// Batas resolusi maksimal sisi terpanjang gambar (dalam piksel).
  static const int _maxDimension = 800;

  /// Kualitas kompresi JPEG (0-100%). Nilai 75 memberikan rasio ukuran/kualitas optimal.
  static const int _quality = 75;

  /// Nama subdirektori di dalam folder documents aplikasi untuk menyimpan gambar.
  static const String _subDir = 'transaction_images';

  // ── Akses Direktori Lokal ──────────────────────────────────────────────────

  /// Mengembalikan objek [Directory] tempat penyimpanan gambar di HP.
  /// Otomatis membuat folder tersebut jika belum ada.
  Future<Directory> _getImagesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _subDir));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // ── Ambil Gambar & Kompresi ────────────────────────────────────────────────

  /// Membuka dialog pemilih gambar (Kamera atau Galeri), melakukan kompresi,
  /// dan menyimpannya ke penyimpanan lokal aplikasi.
  ///
  /// Mengembalikan path absolut file hasil kompresi, atau `null` jika pengguna membatalkan aksi.
  Future<String?> pickAndCompress(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: _maxDimension.toDouble(),
      maxHeight: _maxDimension.toDouble(),
    );
    if (picked == null) return null;

    return _compressAndSave(picked.path);
  }

  /// Melakukan kompresi dari path file mentah [sourcePath] dan menyimpannya dengan nama unik.
  Future<String?> _compressAndSave(String sourcePath) async {
    final dir = await _getImagesDir();
    // Penamaan file menggunakan timestamp untuk menjamin keunikan nama
    final fileName = 'tx_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destPath = p.join(dir.path, fileName);

    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      destPath,
      minWidth: _maxDimension,
      minHeight: _maxDimension,
      quality: _quality,
      format: CompressFormat.jpeg,
    );

    return result?.path;
  }

  // ── Hapus Gambar Tunggal ───────────────────────────────────────────────────

  /// Menghapus satu file gambar fisik berdasarkan path absolutnya.
  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    final file = File(imagePath);
    if (file.existsSync()) file.deleteSync();
  }

  // ── Pembersihan Sampah File (Housekeeping) ─────────────────────────────────

  /// Membersihkan file gambar *orphan* (file foto yang ada di folder tetapi transaksinya sudah terhapus di database).
  ///
  /// Parameter:
  /// - [knownPaths]: Himpunan seluruh path gambar transaksi yang saat ini masih valid di SQLite.
  Future<void> cleanupOrphans(Set<String> knownPaths) async {
    final dir = await _getImagesDir();
    final files = dir.listSync().whereType<File>();
    for (final file in files) {
      if (!knownPaths.contains(file.path)) {
        file.deleteSync();
      }
    }
  }

  /// Menghapus file gambar yang usianya sudah melebihi batas waktu [maxAge] (default: 30 hari).
  Future<void> cleanupOldFiles({
    Duration maxAge = const Duration(days: 30),
  }) async {
    final dir = await _getImagesDir();
    final cutoff = DateTime.now().subtract(maxAge);
    final files = dir.listSync().whereType<File>();
    for (final file in files) {
      try {
        final stat = file.statSync();
        if (stat.modified.isBefore(cutoff)) {
          file.deleteSync();
        }
      } catch (_) {
        // Abaikan error per-file agar proses pembersihan tidak terputus
      }
    }
  }
}
