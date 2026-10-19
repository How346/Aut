import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  /// Selectable accent colours (first one is the default blue).
  static const List<Color> accents = [
    Color(0xFF1565E8),
    Color(0xFF8B5CF6),
    Color(0xFF14A37F),
    Color(0xFFF97316),
    Color(0xFFEC4899),
  ];

  static ThemeData light(Color accent) => _build(Brightness.light, accent);
  static ThemeData dark(Color accent) => _build(Brightness.dark, accent);

  /// Blue hero gradient used on splash, PIN and detail screens.
  /// The raw accent colour is exposed as `colorScheme.secondary`.
  static LinearGradient hero(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(accent, Colors.white, 0.06)!,
        Color.lerp(accent, Colors.black, 0.34)!,
      ],
    );
  }

  /// Shared text field decoration.
  static InputDecoration inputDecoration(
    BuildContext context, {
    String? label,
    String? hint,
    IconData? icon,
    Widget? suffix,
  }) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: scheme.surface,
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(scheme.primary, 1.6),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.6),
    );
  }

  static ThemeData _build(Brightness brightness, Color accent) {
    final dark = brightness == Brightness.dark;
    const navy = Color(0xFF0B1220);

    final primary = dark ? Color.lerp(accent, Colors.white, 0.25)! : accent;

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: dark ? navy : Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      primaryContainer: dark
          ? Color.lerp(accent, navy, 0.72)!
          : Color.lerp(accent, Colors.white, 0.88)!,
      onPrimaryContainer: dark
          ? Color.lerp(accent, Colors.white, 0.75)!
          : Color.lerp(accent, Colors.black, 0.3)!,
      surface: dark ? const Color(0xFF131C30) : Colors.white,
      onSurface: dark ? const Color(0xFFE6ECF7) : const Color(0xFF101828),
      onSurfaceVariant:
          dark ? const Color(0xFF93A1BC) : const Color(0xFF667085),
      surfaceContainerHighest:
          dark ? const Color(0xFF1B2740) : const Color(0xFFEAF0FA),
      outlineVariant: dark ? const Color(0xFF223049) : const Color(0xFFE3EAF6),
      error: dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? navy : const Color(0xFFF6F9FF),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 46),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
