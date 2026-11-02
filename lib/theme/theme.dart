import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Light theme "Mist & Eucalyptus" and dark theme "Graphite Mint", typeset in Nunito Sans
/// with only Regular 400 and Medium 500 (guidelines §5).
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? const ColorScheme(
          brightness: Brightness.dark,
          primary: GraphiteMint.accent,
          onPrimary: GraphiteMint.background,
          primaryContainer: GraphiteMint.surfaceElevated,
          onPrimaryContainer: GraphiteMint.text,
          secondary: GraphiteMint.textMuted,
          onSecondary: GraphiteMint.background,
          surface: GraphiteMint.background,
          onSurface: GraphiteMint.text,
          onSurfaceVariant: GraphiteMint.textMuted,
          surfaceContainerLowest: GraphiteMint.background,
          surfaceContainerLow: GraphiteMint.surface,
          surfaceContainer: GraphiteMint.surface,
          surfaceContainerHigh: GraphiteMint.surfaceElevated,
          surfaceContainerHighest: GraphiteMint.surfaceElevated,
          outline: Color(0xFF4A5550),
          outlineVariant: GraphiteMint.surfaceElevated,
          error: StatusColors.error,
          onError: GraphiteMint.text,
        )
      : const ColorScheme(
          brightness: Brightness.light,
          primary: MistEucalyptus.accentStrong,
          onPrimary: MistEucalyptus.background,
          primaryContainer: MistEucalyptus.surface,
          onPrimaryContainer: MistEucalyptus.text,
          secondary: MistEucalyptus.accentStrong,
          onSecondary: MistEucalyptus.background,
          surface: MistEucalyptus.background,
          onSurface: MistEucalyptus.text,
          onSurfaceVariant: MistEucalyptus.accentStrong,
          surfaceContainerLowest: Color(0xFFFFFFFF),
          surfaceContainerLow: Color(0xFFEAEFEB),
          surfaceContainer: MistEucalyptus.surface,
          surfaceContainerHigh: MistEucalyptus.surface,
          surfaceContainerHighest: Color(0xFFCFD9D2),
          outline: MistEucalyptus.accent,
          outlineVariant: Color(0xFFCAD5CD),
          error: StatusColors.error,
          onError: MistEucalyptus.background,
        );

  final text = _textTheme(scheme.onSurface, scheme.onSurfaceVariant);
  final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: dark ? GraphiteMint.surface : Colors.white.withValues(alpha: 0.7),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: dark ? BorderSide.none : BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        shape: controlShape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        shape: controlShape,
        side: BorderSide(color: scheme.outline),
        foregroundColor: scheme.onSurface,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 44), shape: controlShape, textStyle: text.labelLarge),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 1,
      highlightElevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
      extendedTextStyle: text.labelLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? GraphiteMint.surface : Colors.white.withValues(alpha: 0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md + 2),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.control), borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.control), borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.control), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
      labelStyle: text.bodyMedium,
      hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: dark ? GraphiteMint.surface : Colors.white.withValues(alpha: 0.6),
      selectedColor: dark ? GraphiteMint.surfaceElevated : MistEucalyptus.surface,
      labelStyle: text.labelMedium,
      checkmarkColor: scheme.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? GraphiteMint.surface : MistEucalyptus.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: dark ? GraphiteMint.surfaceElevated : MistEucalyptus.surface,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
          )),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? GraphiteMint.surfaceElevated : MistEucalyptus.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? GraphiteMint.surfaceElevated : MistEucalyptus.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sheet)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? GraphiteMint.surfaceElevated : MistEucalyptus.text,
      contentTextStyle: text.bodyMedium?.copyWith(color: dark ? GraphiteMint.text : MistEucalyptus.background),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.primary : null),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: scheme.surfaceContainer),
  );
}

TextTheme _textTheme(Color ink, Color muted) {
  TextStyle style(double size, double height, FontWeight weight, {Color? color}) =>
      GoogleFonts.nunitoSans(fontSize: size, height: height / size, fontWeight: weight, color: color ?? ink);
  const regular = FontWeight.w400;
  const medium = FontWeight.w500;
  return TextTheme(
    displayLarge: style(40, 44, medium),
    displayMedium: style(40, 44, medium),
    displaySmall: style(32, 38, medium),
    headlineLarge: style(32, 38, medium),
    headlineMedium: style(24, 30, medium),
    headlineSmall: style(24, 30, medium),
    titleLarge: style(20, 26, medium),
    titleMedium: style(16, 24, medium),
    titleSmall: style(14, 20, medium),
    bodyLarge: style(16, 24, regular),
    bodyMedium: style(14, 20, regular),
    bodySmall: style(12, 16, regular, color: muted),
    labelLarge: style(14, 18, medium),
    labelMedium: style(14, 18, medium),
    labelSmall: style(12, 16, regular),
  );
}

/// Tabular figures for nutrition values that line up in columns.
const tabularFigures = [FontFeature.tabularFigures()];
