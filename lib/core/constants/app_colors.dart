import 'package:flutter/material.dart';

class AppColors {
  // ── Brand palette ──────────────────────────────────────────────────────────
  /// Biru aksen utama
  static const Color accent = Color(0xFF72B9FF);

  /// Biru lebih gelap untuk hover/pressed state
  static const Color accentDark = Color(0xFF4FA3F5);

  // ── Text ───────────────────────────────────────────────────────────────────
  /// Teks utama (hampir hitam navy)
  static const Color textPrimary = Color(0xFF101C28);

  /// Teks sekunder (abu medium)
  static const Color textSecondary = Color(0xFF6B7A8D);

  /// Teks muted/placeholder
  static const Color textMuted = Color(0xFFADB8C4);

  /// Teks di atas background gelap (putih)
  static const Color textOnDark = Colors.white;

  // ── Background & Surface ───────────────────────────────────────────────────
  /// Background utama layar
  static const Color background = Color(0xFFFFFFFF);

  /// Surface card / input (putih bersih)
  static const Color surface = Colors.white;

  /// Dark surface (untuk bottom sheet, dll)
  static const Color surfaceDark = Color(0xFF101C28);

  // ── Border ─────────────────────────────────────────────────────────────────
  static const Color border = Color(0xFFD6E4F0);
  static const Color borderInput = Color(0xFFBDD4E8);

  // ── Status ─────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  // ── Legacy aliases (dipertahankan agar layar lain tidak break) ─────────────
  static const Color primary = accent;
  static const Color primaryDark = accentDark;
  static const Color primaryLight = Color(0xFFDCEEFD);
  static const Color inputBackground = Color(0xFFF0F7FF);
}
