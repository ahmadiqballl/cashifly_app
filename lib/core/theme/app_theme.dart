// app_theme.dart
// This file defines the app's visual theme. Adjust the values below to customize colors, fonts, and component styles.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class AppTheme {
  // Font family: SF Pro Display (lokal OTF di assets/font/).
  static const String _fontFamily = 'SFProDisplay';

  // Light theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true, // Enable Material 3 design
      fontFamily: _fontFamily, // Font family applied globally
      // Seed color defines the primary color palette for Material 3
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent, // Primary accent color
        primary: AppColors.accent, // Primary color (same as accent)
        secondary: AppColors.accentDark, // Secondary color, usually a darker accent
        surface: AppColors.surface, // Background for cards, sheets, etc.
        error: AppColors.error, // Error color used for validation, etc.
        brightness: Brightness.light, // Light mode
      ),
      scaffoldBackgroundColor: AppColors.background, // Overall app background

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        // Status bar icons hitam untuk AppBar transparan di atas bg putih
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // ── Input fields ───────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface, // Fill color for input fields
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(
          color: AppColors.textMuted, // Hint text color
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), // Rounded corners
          borderSide: const BorderSide(color: AppColors.borderInput, width: 1), // Default border color
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderInput, width: 1), // Border when enabled
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5), // Border when focused
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2), // Border for errors
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5), // Border for focused error state
        ),
      ),

      // ── Elevated button ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent, // Button background color
          foregroundColor: Colors.white, // Text/Icon color
          elevation: 0, // No shadow
          shadowColor: Colors.transparent, // Transparent shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), // Rounded corners
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          minimumSize: const Size(double.infinity, 54), // Full-width button, height 54
        ),
      ),

      // ── Outlined button ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary, // Text/icon color
          side: const BorderSide(color: AppColors.border, width: 1.2), // Outline border
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), // Rounded corners
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(double.infinity, 54), // Full-width, height 54
        ),
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.border, // Divider line color
        thickness: 1,
        space: 1,
      ),
    );
  }
}
