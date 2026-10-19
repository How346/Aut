import 'package:flutter/material.dart';

/// Round icon for a service. Well-known services get a brand-coloured mark,
/// everything else gets the first letter of the issuer.
class ServiceIcon extends StatelessWidget {
  const ServiceIcon({super.key, required this.issuer, this.size = 40});

  final String issuer;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = issuer.trim().toLowerCase();

    Color background = scheme.primaryContainer;
    Widget child;
    var bordered = false;

    if (key.contains('google') || key.contains('gmail')) {
      background = Colors.white;
      bordered = true;
      child = Text(
        'G',
        style: TextStyle(
          color: const Color(0xFF4285F4),
          fontSize: size * 0.56,
          fontWeight: FontWeight.w800,
        ),
      );
    } else if (key.contains('microsoft') ||
        key.contains('outlook') ||
        key.contains('azure')) {
      background = Colors.white;
      bordered = true;
      child = _MicrosoftMark(size: size * 0.46);
    } else if (key.contains('github')) {
      background = const Color(0xFF181717);
      child = Icon(Icons.code, color: Colors.white, size: size * 0.55);
    } else if (key.contains('amazon') || key.contains('aws')) {
      background = const Color(0xFF131A22);
      child = Text(
        'a',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.6,
          fontWeight: FontWeight.w800,
        ),
      );
    } else if (key.contains('discord')) {
      background = const Color(0xFF5865F2);
      child = Icon(Icons.sports_esports, color: Colors.white, size: size * 0.55);
    } else {
      final letter = key.isEmpty ? '?' : key.substring(0, 1).toUpperCase();
      child = Text(
        letter,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontSize: size * 0.46,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: bordered ? Border.all(color: scheme.outlineVariant) : null,
      ),
      child: child,
    );
  }
}

class _MicrosoftMark extends StatelessWidget {
  const _MicrosoftMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cell = (size - 2) / 2;
    Widget square(Color color) =>
        SizedBox(width: cell, height: cell, child: ColoredBox(color: color));
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              square(const Color(0xFFF25022)),
              square(const Color(0xFF7FBA00)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              square(const Color(0xFF00A4EF)),
              square(const Color(0xFFFFB900)),
            ],
          ),
        ],
      ),
    );
  }
}
