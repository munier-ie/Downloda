import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

extension ThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // Light: #F8F5F2 bg, #385144 accent/text | Dark: #385144 bg, #F8F5F2 accent/text
  Color get colorBackground => isDarkMode ? const Color(0xFF385144) : const Color(0xFFF8F5F2);
  Color get colorSurface => isDarkMode ? const Color(0xFF2E4238) : const Color(0xFFFFFFFF);
  Color get colorElevated => isDarkMode ? const Color(0xFF26382F) : const Color(0xFFEDE8E3);
  Color get colorAccent => isDarkMode ? const Color(0xFFF8F5F2) : const Color(0xFF385144);
  Color get colorAccentDim => isDarkMode ? const Color(0x26F8F5F2) : const Color(0x1F385144);
  Color get colorSuccess => isDarkMode ? const Color(0xFF5DBE8A) : const Color(0xFF2D7A4F);
  Color get colorFailure => isDarkMode ? const Color(0xFFE57373) : const Color(0xFFC0392B);
  Color get colorWarning => isDarkMode ? const Color(0xFFFFB74D) : const Color(0xFFD4870A);
  
  Color get colorTextPrimary => isDarkMode ? const Color(0xFFF8F5F2) : const Color(0xFF385144);
  Color get colorTextSecondary => isDarkMode ? const Color(0xFFBFD4C8) : const Color(0xFF5C7A6B);
  Color get colorTextTertiary => isDarkMode ? const Color(0xFF7AA38E) : const Color(0xFF8AAB9A);
  
  Color get colorDivider => isDarkMode ? const Color(0xFF26382F) : const Color(0xFFD9D2CA);
  Color get colorRingTrack => isDarkMode ? const Color(0x14F8F5F2) : const Color(0x14385144);

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
    // Light: #F8F5F2 bg, #385144 text/accent | Dark: inverted
    final bg = isDark ? const Color(0xFF385144) : const Color(0xFFF8F5F2);
    final surface = isDark ? const Color(0xFF2E4238) : const Color(0xFFFFFFFF);
    final text = isDark ? const Color(0xFFF8F5F2) : const Color(0xFF385144);
    final elevated = isDark ? const Color(0xFF26382F) : const Color(0xFFEDE8E3);
    final divider = isDark ? const Color(0xFF26382F) : const Color(0xFFD9D2CA);
    final accent = isDark ? const Color(0xFFF8F5F2) : const Color(0xFF385144);
    final textTertiary = isDark ? const Color(0xFF7AA38E) : const Color(0xFF8AAB9A);
    final accentDim = isDark ? const Color(0x26F8F5F2) : const Color(0x1F385144);

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
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: bg,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: text,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(
          color: isDark ? const Color(0xFFBFD4C8) : const Color(0xFF5C7A6B),
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
