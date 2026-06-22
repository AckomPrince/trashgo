import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary
  static const primary     = Color(0xFF2E7D32);
  static const primaryDark = Color(0xFF1B5E20);
  static const primaryLight= Color(0xFF4CAF50);
  static const primaryBg   = Color(0xFFE8F5E9);

  // App surfaces
  static const background  = Color(0xFFF5F7F5);
  static const surface     = Colors.white;
  static const cardBg      = Colors.white;

  // Status — error
  static const error       = Color(0xFFD32F2F);
  static const errorBg     = Color(0xFFFFEBEE);

  // Status — warning / pending
  static const warning     = Color(0xFFF57C00);
  static const warningBg   = Color(0xFFFFF3E0);

  // Status — info / in-transit
  static const info        = Color(0xFF1565C0);
  static const infoBg      = Color(0xFFE3F2FD);

  // Status — teal / arrived
  static const teal        = Color(0xFF00796B);
  static const tealBg      = Color(0xFFE0F2F1);

  // Status — purple / admin
  static const purple      = Color(0xFF7B1FA2);
  static const purpleBg    = Color(0xFFF3E5F5);

  // Text
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textMuted     = Color(0xFF9A9A9A);

  // Borders / dividers
  static const divider      = Color(0xFFE0E0E0);
  static const dividerLight = Color(0xFFF2F2F2);

  // Waste-type icon palette
  static const wasteGeneralBg    = Color(0xFFEEF1EE);
  static const wasteGeneralFg    = Color(0xFF4B635E);
  static const wasteRecyclableBg = Color(0xFFE8F5E9);
  static const wasteRecyclableFg = Color(0xFF2E7D32);
  static const wasteOrganicBg    = Color(0xFFE0F2F1);
  static const wasteOrganicFg    = Color(0xFF00796B);
  static const wasteHazardousBg  = Color(0xFFFFEBEE);
  static const wasteHazardousFg  = Color(0xFFD32F2F);
  static const wasteBulkyBg      = Color(0xFFFFF3E0);
  static const wasteBulkyFg      = Color(0xFFF57C00);

  // Rider availability
  static const riderOnline  = Color(0xFF2E7D32);
  static const riderOffline = Color(0xFFCFCFCF);

  // Legacy aliases kept for backward compatibility
  static const accent = Color(0xFF81C784);
}

/// Reusable shadow tokens
class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const primaryButton = [
    BoxShadow(color: Color(0x472E7D32), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const bottomSheet = [
    BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6)),
  ];
  static const modal = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 50, offset: Offset(0, 20)),
  ];
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary:    AppColors.primary,
        surface:    AppColors.surface,
        error:      AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor:    AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        color: AppColors.cardBg,
        shadowColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Color(0xFFB0B0B0),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
