// File: lib/core/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF6366f1); // Indigo
  static const Color primaryLight = Color(0xFF8b5cf6); // Violet
  static const Color secondary = Color(0xFFec4899); // Pink
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color surfaceLight = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        background: backgroundLight,
        surface: surfaceLight,
      ),
      scaffoldBackgroundColor: backgroundLight,
      cardColor: surfaceLight,
      dividerColor: Colors.grey[200],
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
        bodyLarge: GoogleFonts.outfit(color: const Color(0xFF334155)),
        bodyMedium: GoogleFonts.outfit(color: const Color(0xFF64748B)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        background: backgroundDark,
        surface: surfaceDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      cardColor: surfaceDark,
      dividerColor: Colors.white.withOpacity(0.1),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: GoogleFonts.outfit(color: Colors.grey[300]),
        bodyMedium: GoogleFonts.outfit(color: Colors.grey[400]),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
