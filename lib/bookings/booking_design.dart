import 'package:flutter/material.dart';

/// Booking surfaces follow the host application's brightness, never a separate
/// theme preference. Cairo is bundled, so offline screens need no font request.
ThemeData bookingDesignTheme(ThemeData host) {
  final dark = host.brightness == Brightness.dark;
  const gold = Color(0xFFC5A16B), navy = Color(0xFF0F172A);
  final surface = dark ? const Color(0xFF182338) : Colors.white;
  final ink = dark ? const Color(0xFFF1F3F7) : navy;
  final muted = dark ? const Color(0xFFADB8CA) : const Color(0xFF55647A);
  final border = dark ? const Color(0xFF2B3850) : const Color(0xFFDCE2EA);
  final scheme = host.colorScheme.copyWith(
      primary: gold,
      onPrimary: navy,
      secondary: gold,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: border,
      secondaryContainer:
          dark ? const Color(0xFF2B3040) : const Color(0xFFF0E7D8),
      onSecondaryContainer: dark ? gold : const Color(0xFF795522));
  return host.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? navy : const Color(0xFFF6F7FA),
      textTheme: host.textTheme
          .apply(fontFamily: 'Cairo', bodyColor: ink, displayColor: ink),
      iconTheme: IconThemeData(color: muted),
      dividerColor: border,
      cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: border))),
      appBarTheme: AppBarTheme(
          backgroundColor: dark ? navy : Colors.white,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: ink)),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: navy,
              minimumSize: const Size(48, 54),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              textStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              minimumSize: const Size(48, 48),
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: dark ? gold : const Color(0xFF795522),
              minimumSize: const Size(44, 44))),
      chipTheme: host.chipTheme.copyWith(
          backgroundColor: surface,
          selectedColor: scheme.secondaryContainer,
          side: BorderSide(color: border),
          labelStyle: TextStyle(fontFamily: 'Cairo', color: ink, fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          labelStyle: TextStyle(color: muted),
          hintStyle: TextStyle(color: muted),
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border))),
      bottomSheetTheme:
          host.bottomSheetTheme.copyWith(backgroundColor: surface),
      dialogTheme: host.dialogTheme.copyWith(backgroundColor: surface));
}
