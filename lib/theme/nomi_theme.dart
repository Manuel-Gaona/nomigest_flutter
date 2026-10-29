import 'package:flutter/material.dart';

/// Paleta oficial NomiGest
class NomiColors {
  static const navy = Color(0xFF1E3A8A); // Base y profesionalismo
  static const blue = Color(0xFF3B82F6); // Tecnología y confianza
  static const darkGreen = Color(0xFF166534); // Crecimiento y finanzas
  static const emerald = Color(0xFF10B981); // Puntualidad y precisión
  static const bg = Color(0xFF0F172A);
  static const card = Color(0xFF1E293B);

  // Apoyo
  static const stroke = Color(0xFF334155);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const text1 = Color(0xFFF8FAFC);
  static const text2 = Color(0xFFCBD5E1);
  static const text3 = Color(0xFF94A3B8);

  // Fondos translúcidos para insignias
  static const emeraldBg = Color(0x2610B981);
  static const amberBg = Color(0x26F59E0B);
  static const redBg = Color(0x26EF4444);
  static const blueBg = Color(0x333B82F6);
}

ThemeData buildNomiTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    scaffoldBackgroundColor: NomiColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: NomiColors.blue,
      secondary: NomiColors.emerald,
      surface: NomiColors.card,
      error: NomiColors.red,
      onSurface: NomiColors.text1,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: NomiColors.text1,
      displayColor: NomiColors.text1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NomiColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: NomiColors.card),
    inputDecorationTheme: InputDecorationTheme(
      border: border(NomiColors.stroke),
      enabledBorder: border(NomiColors.stroke),
      focusedBorder: border(NomiColors.blue, 1.5),
      labelStyle: const TextStyle(color: NomiColors.text3),
      floatingLabelStyle: const TextStyle(color: NomiColors.blue),
      prefixIconColor: NomiColors.text3,
      suffixIconColor: NomiColors.text3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NomiColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: NomiColors.blueBg,
        selectedForegroundColor: Colors.white,
        foregroundColor: NomiColors.text2,
        side: const BorderSide(color: NomiColors.stroke),
      ),
    ),
  );
}
