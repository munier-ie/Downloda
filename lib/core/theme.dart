import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

extension ThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get colorBackground => isDarkMode ? const Color(0xFF0F1115) : const Color(0xFFF8FAFC);
  Color get colorSurface => isDarkMode ? const Color(0xFF171A20) : const Color(0xFFFFFFFF);
  Color get colorElevated => isDarkMode ? const Color(0xFF1E222B) : const Color(0xFFF1F5F9);
  Color get colorAccent => const Color(0xFF8B5CF6);
  Color get colorAccentDim => const Color(0x338B5CF6);
  Color get colorSuccess => const Color(0xFF22C55E);
  Color get colorFailure => const Color(0xFFEF4444);
  Color get colorWarning => const Color(0xFFF59E0B);
  
  Color get colorTextPrimary => isDarkMode ? const Color(0xFFE8EAF0) : const Color(0xFF0F1115);
  Color get colorTextSecondary => isDarkMode ? const Color(0xFF8A8FA8) : const Color(0xFF64748B);
  Color get colorTextTertiary => isDarkMode ? const Color(0xFF4A4F63) : const Color(0xFF94A3B8);
  
  Color get colorDivider => isDarkMode ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0);
  Color get colorRingTrack => isDarkMode ? const Color(0x14FFFFFF) : const Color(0x14000000);

  TextStyle get typographyH1 => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.52,
        height: 1.1,
        color: colorTextPrimary,
      );

  TextStyle get typographyH2 => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.2,
        color: colorTextPrimary,
      );

  TextStyle get typographyH3 => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: colorTextPrimary,
      );

  TextStyle get typographyBody => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: colorTextPrimary,
      );

  TextStyle get typographyMeta => GoogleFonts.robotoMono(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: colorTextSecondary,
      );

  TextStyle get typographyGreeting => GoogleFonts.robotoMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.96,
        color: colorTextSecondary,
      );

  TextStyle get typographyTab => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      );
}

class DwldrTheme {
  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1115) : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF171A20) : const Color(0xFFFFFFFF);
    final text = isDark ? const Color(0xFFE8EAF0) : const Color(0xFF0F1115);
    final elevated = isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F5F9);
    final divider = isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0);
    final accent = const Color(0xFF8B5CF6);
    final textTertiary = isDark ? const Color(0xFF4A4F63) : const Color(0xFF94A3B8);
    final accentDim = const Color(0x338B5CF6);

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
        surface: surface,
        primary: accent,
        onSurface: text,
      ),
      textTheme: GoogleFonts.interTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).apply(
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: text,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(
          color: isDark ? const Color(0xFF8A8FA8) : const Color(0xFF64748B),
          size: 20,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentDim;
          return elevated;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: text,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        behavior: SnackBarBehavior.floating,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);
}
