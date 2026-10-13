import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const forest = Color(0xFF06322C),
      teal = Color(0xFF3A7B72),
      mint = Color(0xFF7ED3C4),
      canvas = Color(0xFFF6F8F7),
      ink = Color(0xFF17211F),
      muted = Color(0xFF7B8784),
      line = Color(0xFFE6ECEA),
      softMint = Color(0xFFE7F5F1),
      orange = Color(0xFFFF8A52),
      amber = Color(0xFFF4C95D);
}

ThemeData schoolTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.forest,
    primary: AppColors.forest,
    secondary: AppColors.mint,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: AppColors.canvas,
  fontFamily: GoogleFonts.instrumentSans().fontFamily,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.canvas,
    foregroundColor: AppColors.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.teal, width: 2),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.forest,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.softMint,
    side: BorderSide.none,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    labelStyle: const TextStyle(
      color: AppColors.forest,
      fontWeight: FontWeight.w700,
    ),
  ),
  textTheme: GoogleFonts.instrumentSansTextTheme(
    const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
      ),
      headlineMedium: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -.7,
      ),
      headlineSmall: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -.4,
      ),
      titleLarge: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
      bodyMedium: TextStyle(color: AppColors.muted, height: 1.45),
    ),
  ),
);
