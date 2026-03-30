import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.negro,
      primaryColor: AppColors.verde,

      colorScheme: const ColorScheme.dark(
        primary:    AppColors.verde,
        secondary:  AppColors.azul,
        surface:    AppColors.negro2,
        error:      AppColors.rojo,
        onPrimary:  AppColors.negro,
        onSurface:  AppColors.texto,
      ),

      // DM Sans como en el HTML (--font-body)
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
        bodyMedium:   GoogleFonts.dmSans(color: AppColors.texto, fontSize: 14),
        bodySmall:    GoogleFonts.dmSans(color: AppColors.texto2, fontSize: 12),
        labelSmall:   GoogleFonts.dmSans(color: AppColors.texto2, fontSize: 11, letterSpacing: 0.5),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.negro2,
        foregroundColor: AppColors.texto,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // Inputs — idéntico al form-group del HTML
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.negro3,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.verde, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.rojo),
        ),
        labelStyle: const TextStyle(color: AppColors.texto2, fontSize: 12, letterSpacing: 0.5),
        hintStyle:  const TextStyle(color: AppColors.texto2),
      ),

      // Botón primario — .btn-primary del HTML
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.verde,
          foregroundColor: AppColors.negro,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),

      // Botón outline — .btn-outline del HTML
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.texto,
          side: const BorderSide(color: AppColors.borde),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borde),
        ),
      ),

      dividerTheme: const DividerThemeData(color: AppColors.borde, thickness: 1),
      dividerColor: AppColors.borde,
    );
  }
}
