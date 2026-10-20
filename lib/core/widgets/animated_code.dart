import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shows a (grouped) one-time code. Every digit rolls up and fades in with a
/// small stagger whenever it changes, and turns into a bullet when [masked].
class AnimatedCode extends StatelessWidget {
  const AnimatedCode({
    super.key,
    required this.code,
    required this.fontSize,
    required this.color,
    this.masked = false,
  });

  /// Code including its group separator, e.g. "483 920".
  final String code;
  final double fontSize;
  final Color color;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final slots = <Widget>[];
    var digitIndex = 0;
    for (var i = 0; i < code.length; i++) {
      final ch = code[i];
      if (ch == ' ') {
        slots.add(SizedBox(width: fontSize * 0.32));
        continue;
      }
      slots.add(
        _DigitSlot(
          key: ValueKey<int>(i),
          char: masked ? '•' : ch,
          index: digitIndex,
          fontSize: fontSize,
          color: color,
        ),
      );
      digitIndex++;
    }
    return Semantics(
      label: masked ? 'Hidden code' : code,
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: slots),
    );
  }
}

class _DigitSlot extends StatefulWidget {
  const _DigitSlot({
    super.key,
    required this.char,
    required this.index,
    required this.fontSize,
    required this.color,
  });

  final String char;
  final int index;
  final double fontSize;
  final Color color;

  @override
  State<_DigitSlot> createState() => _DigitSlotState();
}

class _DigitSlotState extends State<_DigitSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );
  late String _previous = widget.char;

  @override
  void didUpdateWidget(covariant _DigitSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.char != widget.char) {
      _previous = oldWidget.char;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _glyph(String ch) {
    return Text(
      ch,
      style: TextStyle(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w700,
        fontFamily: AppTheme.codeFont,
        color: widget.color,
        height: 1.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = (widget.index * 0.08).clamp(0.0, 0.4);
    final travel = widget.fontSize * 0.7;

    return SizedBox(
      width: widget.fontSize * 0.66,
      height: widget.fontSize * 1.3,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final raw = ((_controller.value - start) / (1 - start)).clamp(0.0, 1.0);
            final t = Curves.easeOutCubic.transform(raw);
            return Stack(
              alignment: Alignment.center,
              children: [
                if (t < 1)
                  Transform.translate(
                    offset: Offset(0, -t * travel),
                    child: Opacity(opacity: 1 - t, child: _glyph(_previous)),
                  ),
                Transform.translate(
                  offset: Offset(0, (1 - t) * travel),
                  child: Transform.scale(
                    scale: 0.75 + 0.25 * t,
                    child: Opacity(opacity: t, child: _glyph(widget.char)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
