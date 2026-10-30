import 'package:flutter/material.dart';

class AppTheme {
  // ── Color Palette ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2E7D32);      // Deep green
  static const Color primaryLight = Color(0xFF4CAF50); // Medium green
  static const Color primaryDark = Color(0xFF1B5E20);  // Dark green
  static const Color accent = Color(0xFF00BCD4);       // Teal accent
  static const Color warning = Color(0xFFF57C00);      // Amber
  static const Color error = Color(0xFFD32F2F);        // Red
  static const Color success = Color(0xFF388E3C);      // Green
  static const Color surface = Color(0xFFF5F5F5);
  static const Color cardBg = Colors.white;

  // Status colors
  static const Color statusPending = Color(0xFFE65100);
  static const Color statusAssigned = Color(0xFF1565C0);
  static const Color statusAccepted = Color(0xFF6A1B9A);
  static const Color statusCollected = Color(0xFF00838F);
  static const Color statusVerified = Color(0xFF2E7D32);
  static const Color statusCompleted = Color(0xFF1B5E20);
  static const Color statusCancelled = Color(0xFF757575);

  static Color statusColor(String status) {
    switch (status) {
      case 'Pending': return statusPending;
      case 'Assigned': return statusAssigned;
      case 'Accepted': return statusAccepted;
      case 'Collected': return statusCollected;
      case 'Verified': return statusVerified;
      case 'Completed': return statusCompleted;
      case 'Cancelled': return statusCancelled;
      default: return Colors.grey;
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: surface,
      textTheme: TextTheme(
        displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: primaryDark),
        displayMedium: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: primaryDark),
        headlineLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        headlineMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        titleMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
        bodyMedium: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: Color(0xFF757575)),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF9E9E9E),
        backgroundColor: Colors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE8F5E9),
        labelStyle: const TextStyle(color: primary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFEEEEEE), thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
