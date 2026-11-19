import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service untuk mengelola gambar transaksi:
/// - Ambil dari kamera atau galeri
/// - Kompresi (max 800px, quality 75)
/// - Simpan ke direktori privat app (bukan BLOB)
/// - Cleanup otomatis: hapus file lama & file orphan
class ImageService {
  ImageService._();
  static final ImageService instance = ImageService._();

  static const int _maxDimension = 800;
  static const int _quality = 75;

  /// Nama subdirektori di dalam app documents directory
  static const String _subDir = 'transaction_images';

  // ── Direktori ──────────────────────────────────────────────────────────────

  /// Kembalikan direktori penyimpanan gambar, buat jika belum ada.
  Future<Directory> _getImagesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _subDir));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // ── Pick & Compress ────────────────────────────────────────────────────────

  /// Buka picker (kamera atau galeri), kompresi, dan simpan.
  /// Mengembalikan path absolut file yang telah dikompresi, atau null jika batal.
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

  /// Kompresi file dari [sourcePath] dan simpan ke direktori app.
  Future<String?> _compressAndSave(String sourcePath) async {
    final dir = await _getImagesDir();
    final fileName =
        'tx_${DateTime.now().millisecondsSinceEpoch}.jpg';
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

  // ── Delete single ──────────────────────────────────────────────────────────

  /// Hapus file gambar berdasarkan path. No-op jika file tidak ada.
  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    final file = File(imagePath);
    if (file.existsSync()) file.deleteSync();
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  /// Hapus semua gambar di direktori yang tidak ada di [knownPaths].
  ///
  /// Panggil ini setelah memuat daftar transaksi, sehingga file orphan
  /// (gambar dari transaksi yang sudah dihapus) ikut dibersihkan.
  Future<void> cleanupOrphans(Set<String> knownPaths) async {
    final dir = await _getImagesDir();
    final files = dir.listSync().whereType<File>();
    for (final file in files) {
      if (!knownPaths.contains(file.path)) {
        file.deleteSync();
      }
    }
  }

  /// Hapus gambar yang lebih tua dari [maxAge] (default 30 hari).
  ///
  /// Berguna sebagai safety net untuk file yang terlupa.
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
        // Abaikan error per-file agar tidak menghentikan proses
      }
    }
  }
}
