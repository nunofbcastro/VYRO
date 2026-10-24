import 'package:flutter/material.dart';

class VyroTheme {
  static const ink = Color(0xFF0B0D10);
  static const surfaceDark = Color(0xFF171A20);
  static const elevatedDark = Color(0xFF20242B);
  static const lime = Color(0xFFB8F36B);
  static const green = Color(0xFF4A741A);
  static const textDark = Color(0xFFF5F7F8);
  static const mutedDark = Color(0xFF9299A4);
  static const borderDark = Color(0xFF2A2E35);
  static const lightBg = Color(0xFFF8FAF7);
  static const lightMuted = Color(0xFF5E6770);
  static const lightBorder = Color(0xFFDCE2DB);

  static ThemeData get dark => _build(darkMode: true);
  static ThemeData get light => _build(darkMode: false);

  static ThemeData _build({required bool darkMode}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: darkMode ? lime : green,
      brightness: darkMode ? Brightness.dark : Brightness.light,
      surface: darkMode ? surfaceDark : Colors.white,
      primary: darkMode ? lime : green,
      onPrimary: darkMode ? ink : Colors.white,
      secondary: darkMode ? lime : green,
      outline: darkMode ? borderDark : lightBorder,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: darkMode ? ink : lightBg,
      cardTheme: CardThemeData(
        color: darkMode ? surfaceDark : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: darkMode ? borderDark : lightBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkMode ? ink : lightBg,
        foregroundColor: darkMode ? textDark : const Color(0xFF171A20),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkMode ? surfaceDark : Colors.white,
        indicatorColor: (darkMode ? lime : green).withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        height: 72,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkMode ? elevatedDark : const Color(0xFFF0F3EF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: darkMode ? mutedDark : lightMuted,
        ),
      ),
    );
  }
}
