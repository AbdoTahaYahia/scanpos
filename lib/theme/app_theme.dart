import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ScanPos Design System — Organic Minimalist B&W
/// Based on DESIGN.md specification
class AppTheme {
  AppTheme._();

  // ─── Colors ────────────────────────────────────────────────────────
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF9F9F9);
  static const Color surfaceContainer = Color(0xFFEEEEEE);
  static const Color surfaceContainerHigh = Color(0xFFE8E8E8);
  static const Color onSurface = Color(0xFF1B1B1B);
  static const Color onSurfaceVariant = Color(0xFF4C4546);
  static const Color outline = Color(0xFF7E7576);
  static const Color outlineVariant = Color(0xFFCFC4C5);
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // ─── Border Widths ─────────────────────────────────────────────────
  static const double borderLevel1 = 2.0;
  static const double borderFocus = 4.0;

  // ─── Border Radius ─────────────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusDefault = 16.0;
  static const double radiusMd = 24.0;
  static const double radiusLg = 32.0;
  static const double radiusXl = 48.0;
  static const double radiusFull = 9999.0;

  // ─── Spacing (8px grid) ────────────────────────────────────────────
  static const double spacingUnit = 8.0;
  static const double containerPadding = 24.0;
  static const double gutter = 16.0;
  static const double touchTargetMin = 48.0;
  static const double elementGap = 12.0;

  // ─── Typography ────────────────────────────────────────────────────
  static TextStyle get display => GoogleFonts.spaceGrotesk(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.04 * 48,
        color: onSurface,
      );

  static TextStyle get headlineLg => GoogleFonts.spaceGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.02 * 32,
        color: onSurface,
      );

  static TextStyle get headlineMd => GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: onSurface,
      );

  static TextStyle get bodyLg => GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: onSurface,
      );

  static TextStyle get bodySm => GoogleFonts.spaceGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: onSurface,
      );

  static TextStyle get labelBold => GoogleFonts.spaceGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: 0.05 * 12,
        color: onSurface,
      );

  static TextStyle get priceDisplay => GoogleFonts.spaceGrotesk(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: -0.02 * 40,
        color: onSurface,
      );

  // ─── Borders ───────────────────────────────────────────────────────
  static BorderSide get borderDefault => const BorderSide(
        color: black,
        width: borderLevel1,
      );

  static BorderSide get borderFocused => const BorderSide(
        color: black,
        width: borderFocus,
      );

  // ─── Shapes ────────────────────────────────────────────────────────
  static RoundedRectangleBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        side: borderDefault,
      );

  static RoundedRectangleBorder get containerShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: borderDefault,
      );

  static StadiumBorder get pillShape => const StadiumBorder(
        side: BorderSide(color: black, width: borderLevel1),
      );

  // ─── ThemeData ─────────────────────────────────────────────────────
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.light(
        primary: black,
        onPrimary: white,
        secondary: Color(0xFF5D5F5F),
        onSecondary: white,
        surface: surface,
        onSurface: onSurface,
        error: error,
        onError: onError,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      textTheme: TextTheme(
        displayLarge: display,
        headlineLarge: headlineLg,
        headlineMedium: headlineMd,
        bodyLarge: bodyLg,
        bodySmall: bodySm,
        labelSmall: labelBold,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: headlineMd,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: black,
        unselectedItemColor: outline,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: black,
        foregroundColor: white,
        elevation: 0,
        shape: CircleBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: borderDefault,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: black,
        contentTextStyle: bodySm.copyWith(color: white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: outlineVariant,
        thickness: 1,
        space: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusFull),
          borderSide: borderDefault,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusFull),
          borderSide: borderDefault,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusFull),
          borderSide: borderFocused,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusFull),
          borderSide: const BorderSide(color: error, width: borderLevel1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusFull),
          borderSide: const BorderSide(color: error, width: borderFocus),
        ),
        hintStyle: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: outline,
        ),
        labelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: onSurfaceVariant,
        ),
      ),
    );
  }
}
