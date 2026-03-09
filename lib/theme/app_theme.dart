import 'package:flutter/material.dart';

class AppTheme {
  // ===== COLOR SYSTEM =====
  static const Color bgLight = Color.fromARGB(255, 249, 250, 252); // background
  static const Color cardLight = Color(0xFFFFFFFF); // card / surface
  static const Color borderLight = Color(0xFFE5E7EB); // border subtle

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color brandBlue = Color(0xFF3B82F6);
  static const Color danger = Color(0xFFDC2626);

  // ===== TEXT SYSTEM =====
  static const TextStyle heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(fontSize: 14, color: textSecondary);

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: bgLight,
    fontFamily: "SF Pro",

    colorScheme: const ColorScheme.light(
      primary: brandBlue,
      secondary: brandBlue,
      error: danger,
      surface: cardLight,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0.6,
      shadowColor: Colors.black12,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),

    cardTheme: CardThemeData(
      color: cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderLight),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),

      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderLight),
      ),

      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: brandBlue, width: 1.6),
      ),

      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: borderLight),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: brandBlue,
      unselectedItemColor: Color(0xFF9CA3AF),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
