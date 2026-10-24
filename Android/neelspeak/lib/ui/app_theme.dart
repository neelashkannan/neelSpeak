import 'package:flutter/material.dart';

/// Brand kit. Pulled from the NeelSpeak app icon — an electric blue that
/// reads as both calm and energetic. Keep these tokens canonical; UI surfaces
/// should reach into [NeelSpeakBrand] rather than inventing one-off colors.
class NeelSpeakBrand {
  // Gradient of the macOS app icon, top-left → bottom-right.
  static const primary = Color(0xFF0A5CF5);
  static const primaryDeep = Color(0xFF0036C9);
  static const primarySoft = Color(0xFF8AB0FF);
  static const accent = Color(0xFF7AE5FF);
  static const ink = Color(0xFF0A1330);
  static const surfaceLight = Color(0xFFF6F8FF);
  static const surfaceDark = Color(0xFF050A1E);
  static const success = Color(0xFF15803D);
  static const successDark = Color(0xFF4ADE80);
  static const warning = Color(0xFFB45309);
  static const warningDark = Color(0xFFFBBF24);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDeep],
  );
}

/// Spacing scale (4 dp grid). Use these instead of ad-hoc numbers in new
/// layouts so screens line up with each other.
class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;

  /// Horizontal page gutter.
  static const double page = 20;
}

/// Status colours that stay readable in both themes.
extension StatusColors on ColorScheme {
  Color get success => brightness == Brightness.dark
      ? NeelSpeakBrand.successDark
      : NeelSpeakBrand.success;
  Color get warning => brightness == Brightness.dark
      ? NeelSpeakBrand.warningDark
      : NeelSpeakBrand.warning;
}

class NeelSpeakTheme {
  static const _seed = NeelSpeakBrand.primary;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: NeelSpeakBrand.primary,
      onPrimary: Colors.white,
      secondary: NeelSpeakBrand.primaryDeep,
      tertiary: NeelSpeakBrand.accent,
      surface: NeelSpeakBrand.surfaceLight,
      onSurface: NeelSpeakBrand.ink,
    );
    return _theme(scheme, const Color(0xFFF4F7FF));
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: NeelSpeakBrand.primarySoft,
      onPrimary: NeelSpeakBrand.ink,
      secondary: NeelSpeakBrand.primary,
      tertiary: NeelSpeakBrand.accent,
      surface: const Color(0xFF0B1330),
      onSurface: const Color(0xFFF4F6FF),
    );
    return _theme(scheme, const Color(0xFF020617));
  }

  static ThemeData _theme(ColorScheme scheme, Color scaffoldBackground) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    final textTheme = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: scheme.outline.withAlpha(80)),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme.copyWith(
        displaySmall: textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.45),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        // Opaque, matching the top of AppBackdrop: the bar sits outside the
        // page body, so a transparent one would show the window behind it.
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.brightness == Brightness.dark
            ? const Color(0xFF111B31).withAlpha(235)
            : Colors.white.withAlpha(235),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        labelStyle: TextStyle(color: scheme.onSurface.withAlpha(180)),
        hintStyle: TextStyle(color: scheme.onSurface.withAlpha(120)),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: scheme.outline.withAlpha(110)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.onSurface.withAlpha(28),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.brightness == Brightness.dark
            ? const Color(0xFF111827)
            : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: scheme.outline.withAlpha(90)),
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurface.withAlpha(150),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.onSurface.withAlpha(24),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
