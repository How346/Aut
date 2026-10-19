import 'package:flutter/material.dart';

/// Fades and slides its child up once when first inserted. Later items
/// (higher [index]) take slightly longer, which gives a staggered entrance.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final step = index < 0 ? 0 : (index > 8 ? 8 : index);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + step * 60),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
