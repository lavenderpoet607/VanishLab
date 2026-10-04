import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Ultra-crisp studio dark palette (obsidian neutral base + deliberate electric tangerine accent)
  static const Color background = Color(0xFF090A0E);
  static const Color surfaceCard = Color(0xFF13161D);
  static const Color surfaceInset = Color(0xFF0B0D12);
  static const Color surfaceRaised = Color(0xFF1B1E28);
  static const Color surfaceElevated = Color(0xFF232836);
  static const Color border = Color(0xFF1F2430);
  static const Color borderStrong = Color(0xFF323A4D);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static const Color solidLight = Color(0xFFF1F5F9);
  static const Color onSolidLight = Color(0xFF090A0E);

  static const Color accent = Color(0xFFFF5500);
  static const Color onAccent = Color(0xFF000000);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Disciplined, consistent radii (avoiding arbitrary pill shapes everywhere)
  static const double radiusTag = 4;
  static const double radiusControl = 8;
  static const double radiusCard = 14;

  static const Color primary = accent;
  static const Color primaryLight = Color(0xFFFF7733);
  static const Color surface = surfaceCard;

  // Typography tokens with Google Fonts Inter & JetBrains Mono
  static TextStyle get label => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        height: 1.2,
        color: textMuted,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: textPrimary,
      );

  static TextStyle get headline => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
        color: textPrimary,
      );

  static TextStyle get readout => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: textSecondary,
      );

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusControl),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      primaryColor: accent,
      dividerColor: border,
      focusColor: Colors.white.withValues(alpha: 0.12),
      hoverColor: Colors.white.withValues(alpha: 0.04),
      highlightColor: Colors.white.withValues(alpha: 0.04),
      splashColor: Colors.white.withValues(alpha: 0.06),
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: onAccent,
        secondary: solidLight,
        onSecondary: onSolidLight,
        surface: surfaceCard,
        onSurface: textPrimary,
        error: error,
        onError: Colors.black,
        outline: border,
      ),
      textTheme: const TextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: textPrimary,
        ),
        titleLarge: headline.copyWith(fontSize: 20),
        titleMedium: headline.copyWith(fontSize: 16),
        bodyLarge: body,
        bodyMedium: body.copyWith(fontSize: 13, color: textSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: textMuted),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
        labelSmall: label,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceInset,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: body.copyWith(color: textMuted),
        errorStyle: GoogleFonts.inter(fontSize: 12, color: error),
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        disabledBorder: inputBorder(border),
        focusedBorder: inputBorder(accent, 1.5),
        errorBorder: inputBorder(error),
        focusedErrorBorder: inputBorder(error, 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: surfaceRaised,
          disabledForegroundColor: textMuted,
          elevation: 0,
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: controlShape,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: solidLight,
          foregroundColor: onSolidLight,
          disabledBackgroundColor: surfaceRaised,
          disabledForegroundColor: textMuted,
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: controlShape,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderStrong),
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: controlShape,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: controlShape,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return textMuted;
          return s.contains(WidgetState.selected) ? onAccent : textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return surfaceRaised;
          return s.contains(WidgetState.selected) ? accent : surfaceRaised;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) {
          return s.contains(WidgetState.selected) ? accent : borderStrong;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surfaceRaised,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceRaised,
        contentTextStyle: body,
        actionTextColor: textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: const BorderSide(color: borderStrong),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCard,
        elevation: 0,
        titleTextStyle: headline,
        contentTextStyle: body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceCard,
        modalBackgroundColor: surfaceCard,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: borderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard)),
          side: BorderSide(color: border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceRaised,
          borderRadius: BorderRadius.circular(radiusTag),
          border: Border.all(color: borderStrong),
        ),
        textStyle: GoogleFonts.inter(fontSize: 12, color: textPrimary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: const BorderSide(color: border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceRaised,
        side: const BorderSide(color: border),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusTag)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: background,
        indicatorColor: surfaceRaised,
        indicatorShape: controlShape,
        selectedIconTheme: const IconThemeData(color: accent, size: 22),
        unselectedIconTheme: const IconThemeData(color: textMuted, size: 22),
        selectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        unselectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
      ),
    );
  }
}
