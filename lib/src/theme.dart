import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const paper = Color(0xFF10181C);
  static const ink = Color(0xFFE7F3F0);
  static const muted = Color(0xFF93A8AD);
  static const line = Color(0xFF2A4148);
  static const card = Color(0xFF17262C);
  static const petrol = Color(0xFF0E2C33);
  static const petrolSoft = Color(0xFF1B333A);
  static const mint = Color(0xFF2FCBAA);
  static const mintSoft = Color(0xFF14352E);
  static const map = Color(0xFF0C1C22);
  static const amber = Color(0xFFE2B56A);
  static const amberSoft = Color(0xFF3A3020);
  static const danger = Color(0xFFF0A39A);
  static const dangerSoft = Color(0xFF3A2424);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.paper,
    canvasColor: AppColors.paper,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.mint,
      onPrimary: Color(0xFF04241C),
      secondary: AppColors.mint,
      onSecondary: Color(0xFF04241C),
      surface: AppColors.card,
      onSurface: AppColors.ink,
    ),
    dividerColor: AppColors.line,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.mintSoft,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.petrol : AppColors.muted,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.mint,
        foregroundColor: const Color(0xFF04241C),
        minimumSize: const Size(44, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(44, 46),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.mint),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.petrol, width: 1.4),
      ),
      labelStyle: const TextStyle(color: AppColors.muted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.mintSoft,
      disabledColor: AppColors.paper,
      checkmarkColor: AppColors.mint,
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF243C44),
      contentTextStyle: TextStyle(color: AppColors.ink),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.card),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
  );
}

({Color fg, Color bg}) statusTone(String key) {
  switch (key) {
    case 'done':
      return (fg: AppColors.mint, bg: AppColors.mintSoft);
    case 'enRoute':
    case 'arrived':
    case 'inService':
      return (fg: AppColors.petrol, bg: AppColors.petrolSoft);
    case 'reschedule':
      return (fg: AppColors.amber, bg: AppColors.amberSoft);
    case 'badAddress':
    case 'absent':
    case 'cancelled':
      return (fg: AppColors.danger, bg: AppColors.dangerSoft);
    default:
      return (fg: AppColors.muted, bg: const Color(0xFF243238));
  }
}
