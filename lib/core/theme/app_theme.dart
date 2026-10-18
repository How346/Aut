import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color brand = Color(0xFF2563EB);

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  /// Shared simple text field decoration.
  static InputDecoration inputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffix,
  }) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
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

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
    ).copyWith(
      primary: dark ? const Color(0xFF60A5FA) : brand,
      onPrimary: dark ? const Color(0xFF0B1B3F) : Colors.white,
      primaryContainer:
          dark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
      onPrimaryContainer:
          dark ? const Color(0xFFDBEAFE) : const Color(0xFF1E3A8A),
      surface: dark ? const Color(0xFF111C36) : Colors.white,
      onSurface: dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
      onSurfaceVariant:
          dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      surfaceContainerHighest:
          dark ? const Color(0xFF1B2A4D) : const Color(0xFFE8F0FE),
      outlineVariant: dark ? const Color(0xFF24345C) : const Color(0xFFDCE6F7),
      error: dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF0B1224) : const Color(0xFFF4F8FF),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
