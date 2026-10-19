import 'package:flutter/material.dart';

/// Circular countdown with the remaining seconds in the middle. The arc
/// sweeps smoothly, changes colour in the last 5 seconds and the number
/// pulses once per second.
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
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: const Duration(milliseconds: 300),
        builder: (context, animatedColor, _) {
          final c = animatedColor ?? color;
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: progress),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.linear,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: strokeWidth,
                    strokeCap: StrokeCap.round,
                    backgroundColor: scheme.outlineVariant,
                    color: c,
                  ),
                ),
              ),
              AnimatedScale(
                scale: urgent && seconds.isOdd ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: Text(
                  showSuffix ? '${seconds}s' : '$seconds',
                  style: TextStyle(
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
