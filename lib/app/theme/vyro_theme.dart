import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// VYRO design tokens and Material theme wiring.
///
/// The visual language is "premium minimal + performance technology": soft
/// organic backgrounds, one lime accent used as a signal, tight typography and
/// thin strokes. Light mode mirrors the dark composition with sage-tinted
/// surfaces instead of pure grey.
class VyroTheme {
  // Dark palette.
  static const ink = Color(0xFF08090B);
  static const surfaceDark = Color(0xFF121419);
  static const elevatedDark = Color(0xFF191C22);
  static const lime = Color(0xFFB8F36B);
  static const limeDeep = Color(0xFF95D64A);
  static const textDark = Color(0xFFF4F6F8);
  static const mutedDark = Color(0xFF9AA1AC);
  static const borderDark = Color(0xFF23272E);

  // Light palette (sage tinted, per brand guide).
  static const lightBg = Color(0xFFF7F9F3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFFCFDF9);
  static const green = Color(0xFF4A741A);
  static const greenDeep = Color(0xFF35560F);
  static const lightText = Color(0xFF141A12);
  static const lightMuted = Color(0xFF6A736C);
  static const lightBorder = Color(0xFFE3E9DC);

  // Shared semantic colours.
  static const positive = Color(0xFF5FC98A);
  static const warning = Color(0xFFE8B23C);
  static const negative = Color(0xFFE4796F);

  static ThemeData get dark => _build(darkMode: true);
  static ThemeData get light => _build(darkMode: false);

  /// Accent used for fills (buttons, dots, selected chips).
  static Color accentOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// Accent safe for text on the current background.
  static Color accentTextOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? lime : greenDeep;

  /// Primary gradient for calls to action.
  static LinearGradient ctaGradient({required bool darkMode}) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: darkMode
        ? const [Color(0xFFCEFA86), Color(0xFFA6E454)]
        : const [Color(0xFFBFF476), Color(0xFF97D848)],
  );

  static ThemeData _build({required bool darkMode}) {
    final accent = darkMode ? lime : green;
    final background = darkMode ? ink : lightBg;
    final surface = darkMode ? surfaceDark : lightSurface;
    final text = darkMode ? textDark : lightText;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: darkMode ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: accent,
          onPrimary: darkMode ? ink : Colors.white,
          primaryContainer: darkMode
              ? const Color(0xFF23300F)
              : const Color(0xFFEAF7D2),
          onPrimaryContainer: darkMode ? lime : greenDeep,
          secondary: darkMode
              ? const Color(0xFF8AB4F8)
              : const Color(0xFF3E6BB5),
          tertiary: darkMode
              ? const Color(0xFFE9B384)
              : const Color(0xFFB26A2E),
          surface: surface,
          onSurface: text,
          surfaceContainerHighest: darkMode ? elevatedDark : lightElevated,
          outline: darkMode ? borderDark : lightBorder,
          outlineVariant: darkMode
              ? const Color(0xFF1B1E24)
              : const Color(0xFFEDF1E8),
          error: darkMode ? negative : const Color(0xFFB3261E),
        );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
    );
    final radius16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final muted = darkMode ? mutedDark : lightMuted;

    final textTheme = base.textTheme
        .apply(bodyColor: text, displayColor: text)
        .copyWith(
          displaySmall: TextStyle(
            fontSize: 38,
            height: 1.06,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.6,
            color: text,
          ),
          headlineMedium: TextStyle(
            fontSize: 31,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: text,
          ),
          headlineSmall: TextStyle(
            fontSize: 23,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: text,
          ),
          titleLarge: TextStyle(
            fontSize: 19,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: text,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.15,
            color: text,
          ),
          titleSmall: TextStyle(
            fontSize: 13.5,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
            color: text,
          ),
          bodyLarge: TextStyle(fontSize: 16.5, height: 1.5, color: muted),
          bodyMedium: TextStyle(fontSize: 14.5, height: 1.5, color: muted),
          bodySmall: TextStyle(fontSize: 12.5, height: 1.45, color: muted),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: text,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: muted,
          ),
        );

    return base.copyWith(
      // iOS-style horizontal slide for pushed pages on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: darkMode ? borderDark : lightBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkMode ? surfaceDark : lightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: darkMode ? 0.18 : 0.16),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        height: 72,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: darkMode ? ink : Colors.white,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: radius16,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: radius16,
          side: BorderSide(color: darkMode ? borderDark : lightBorder),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkMode ? lime : greenDeep,
          minimumSize: const Size(44, 44),
          shape: radius16,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
          side: BorderSide(color: darkMode ? borderDark : lightBorder),
        ),
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: darkMode ? 0.16 : 0.18),
        checkmarkColor: darkMode ? lime : greenDeep,
        labelStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      dividerTheme: DividerThemeData(
        color: darkMode ? borderDark : lightBorder,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(iconColor: muted, textColor: text),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: darkMode ? borderDark : lightBorder,
        circularTrackColor: darkMode ? borderDark : lightBorder,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkMode ? surfaceDark : lightSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: darkMode ? surfaceDark : lightSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkMode ? surfaceDark : lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkMode ? elevatedDark : const Color(0xFF171A20),
        contentTextStyle: const TextStyle(color: textDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkMode ? elevatedDark : const Color(0xFFF1F5EC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: TextStyle(color: muted, fontSize: 15),
        labelStyle: TextStyle(color: muted, fontSize: 14.5),
        floatingLabelStyle: TextStyle(
          color: darkMode ? lime : greenDeep,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: muted,
        suffixIconColor: muted,
        suffixStyle: TextStyle(color: muted, fontSize: 13.5),
        counterStyle: TextStyle(color: muted, fontSize: 11.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: darkMode ? borderDark : lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
    );
  }
}
