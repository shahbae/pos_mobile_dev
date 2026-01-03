import 'package:flutter/material.dart';

class AppTheme {
  // ===== COLOR SYSTEM =====
  static const Color navy900 = Color(0xFF0D1923);
  static const Color navy800 = Color(0xFF152634);
  static const Color navy700 = Color(0xFF1F2937);

  static const Color brandBlue = Color(0xFF0081F5);
  static const Color greyText = Colors.white70;
  static const Color danger = Color(0xFFDC2626);

  // ===== TEXT SYSTEM =====
  static const TextStyle heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle body = TextStyle(fontSize: 14, color: Colors.white70);

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: navy900,
    fontFamily: "SF Pro", // opsional

    colorScheme: const ColorScheme.dark(
      primary: brandBlue,
      secondary: brandBlue,
      error: danger,
      background: navy900,
      surface: navy800,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: navy900,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F172A), // 🔥 warna isi field

      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),

      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),

      suffixIconColor: Color(0xFFCBD5E1),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFF2B3A55), width: 1.2),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFF3B82F6), width: 1.6),
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFF2B3A55), width: 1.2),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    cardTheme: CardThemeData(
      color: navy800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
    ),
  );
}
