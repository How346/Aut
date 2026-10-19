import 'package:flutter/material.dart';

/// Circular countdown with the remaining seconds in the middle.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.progress,
    required this.seconds,
    this.size = 34,
    this.strokeWidth = 3,
    this.showSuffix = false,
  });

  final double progress;
  final int seconds;
  final double size;
  final double strokeWidth;
  final bool showSuffix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urgent = seconds <= 5;
    final color = urgent ? scheme.error : scheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.outlineVariant,
              color: color,
            ),
          ),
          Text(
            showSuffix ? '${seconds}s' : '$seconds',
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
