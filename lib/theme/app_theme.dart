import 'package:flutter/material.dart';

/// Color tokens copied from the Figma file.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFFBF6EE);
  static const Color card = Color(0xFFFFFDF8);
  static const Color primary = Color(0xFF9B5B32); // accent/default
  static const Color chip = Color(0xFFFAEBE2);
  static const Color tint = Color(0xFFF2E4D3); // flipped card, Why box
  static const Color border = Color(0xFFE8DED0);
  static const Color ink = Color(0xFF201914); // text/primary
  static const Color muted = Color(0xFF7A6D63); // text/faint
  static const Color danger = Color(0xFFB33A3A); // state/danger
  static const Color success = Color(0xFF4F8A4F); // state/success
  static const Color hard = Color(0xFFB9701E); // Hard rating button
}

/// Font families bundled in assets/fonts (see pubspec.yaml).
class AppFonts {
  AppFonts._();

  static const String serif = 'Newsreader';
  static const String sans = 'Inter';
  static const String mono = 'JetBrainsMono';
}

/// Material 3 theme used across the whole app.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.background,
    onSurface: AppColors.ink,
    error: AppColors.danger,
    // Material 3 tints dialogs, date pickers and menus with the brown seed.
    // Use the plain card white for every raised surface instead.
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: AppColors.card,
    surfaceContainerLow: AppColors.card,
    surfaceContainer: AppColors.card,
    surfaceContainerHigh: AppColors.card,
    surfaceContainerHighest: AppColors.card,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: AppFonts.sans);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.card),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.card,
      headerBackgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: const PopupMenuThemeData(color: AppColors.card),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.card),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(48, 48),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(48, 48),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => kMonoMicro.copyWith(
          color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
        ),
      ),
    ),
  );
}

/// Mono/Meta Upper in Figma: small uppercase labels.
const TextStyle kMonoLabel = TextStyle(
  fontFamily: AppFonts.mono,
  fontSize: 11,
  height: 1.5,
  letterSpacing: 0.66,
  color: AppColors.muted,
);

/// Mono/Micro in Figma: pills and bottom navigation labels.
const TextStyle kMonoMicro = TextStyle(
  fontFamily: AppFonts.mono,
  fontSize: 10,
  letterSpacing: 0.6,
  color: AppColors.muted,
);

/// Newsreader SemiBold, used for screen and card titles.
const TextStyle kSerifTitle = TextStyle(
  fontFamily: AppFonts.serif,
  fontSize: 28,
  height: 1.25,
  fontWeight: FontWeight.w600,
  color: AppColors.ink,
);

/// Body/Small in Figma.
const TextStyle kBodySmall = TextStyle(
  fontFamily: AppFonts.sans,
  fontSize: 13,
  height: 1.5,
  color: AppColors.muted,
);

/// Heading/Section in Figma: card and section titles.
const TextStyle kSerifSection = TextStyle(
  fontFamily: AppFonts.serif,
  fontSize: 20,
  height: 1.3,
  fontWeight: FontWeight.w600,
  color: AppColors.ink,
);
