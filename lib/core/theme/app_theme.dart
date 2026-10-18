import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color brand = Color(0xFF2563EB);
  static const Color brandDeep = Color(0xFF1D4ED8);
  static const Color brandLight = Color(0xFF5B9DFF);
  static const Color accent = Color(0xFF22D3EE);
  static const Color navyDeep = Color(0xFF070D1F);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
  );

  static const List<List<Color>> avatarGradients = [
    [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    [Color(0xFF06B6D4), Color(0xFF0E7490)],
    [Color(0xFF6366F1), Color(0xFF4338CA)],
    [Color(0xFF0EA5E9), Color(0xFF0369A1)],
    [Color(0xFF8B5CF6), Color(0xFF5B21B6)],
    [Color(0xFF14B8A6), Color(0xFF0F766E)],
  ];

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  /// Shared, premium-looking text field decoration.
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
        borderRadius: BorderRadius.circular(14),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(scheme.primary, 1.8),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.8),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
    ).copyWith(
      primary: dark ? brandLight : brandDeep,
      onPrimary: dark ? const Color(0xFF04122E) : Colors.white,
      primaryContainer:
          dark ? const Color(0xFF16275A) : const Color(0xFFDCE7FF),
      onPrimaryContainer:
          dark ? const Color(0xFFCFE0FF) : const Color(0xFF0B2A8A),
      secondary: dark ? accent : const Color(0xFF0891B2),
      surface: dark ? const Color(0xFF0E1731) : Colors.white,
      onSurface: dark ? const Color(0xFFE8EEFF) : const Color(0xFF0B1230),
      onSurfaceVariant:
          dark ? const Color(0xFF9AA8D1) : const Color(0xFF5B678F),
      surfaceContainerHighest:
          dark ? const Color(0xFF1A2548) : const Color(0xFFE8EEFF),
      outline: dark ? const Color(0xFF3A4A80) : const Color(0xFF9AA8D1),
      outlineVariant: dark ? const Color(0xFF22305C) : const Color(0xFFD9E2FA),
      error: dark ? const Color(0xFFFF6B7A) : const Color(0xFFDC2626),
    );

    final scaffold = dark ? navyDeep : const Color(0xFFF3F6FF);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
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
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        extendedTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF1A2548) : const Color(0xFF0B1230),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
