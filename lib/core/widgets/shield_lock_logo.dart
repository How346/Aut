import 'package:flutter/material.dart';

/// Authly logo: a shield with a padlock placed exactly at its visual centre.
/// [filled] draws a solid shield (for light backgrounds); otherwise an outlined
/// shield (for the blue gradient screens).
class ShieldLockLogo extends StatelessWidget {
  const ShieldLockLogo({
    super.key,
    required this.size,
    required this.shieldColor,
    this.lockColor,
    this.filled = false,
  });

  /// Width of the logo. The height is `size * 1.12`.
  final double size;
  final Color shieldColor;
  final Color? lockColor;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.12,
      child: CustomPaint(
        painter: _ShieldLockPainter(
          shieldColor: shieldColor,
          lockColor: lockColor ?? (filled ? Colors.white : shieldColor),
          filled: filled,
        ),
      ),
    );
  }
}

class _ShieldLockPainter extends CustomPainter {
  _ShieldLockPainter({
    required this.shieldColor,
    required this.lockColor,
    required this.filled,
  });

  final Color shieldColor;
  final Color lockColor;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = filled ? 0.0 : w * 0.05;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      w - stroke,
      h - stroke,
    );

    Offset p(double x, double y) =>
        Offset(rect.left + x * rect.width, rect.top + y * rect.height);

    final shield = Path()
      ..moveTo(p(0.5, 0.0).dx, p(0.5, 0.0).dy)
      ..cubicTo(
        p(0.68, 0.10).dx, p(0.68, 0.10).dy,
        p(0.84, 0.13).dx, p(0.84, 0.13).dy,
        p(0.96, 0.13).dx, p(0.96, 0.13).dy,
      )
      ..lineTo(p(0.96, 0.50).dx, p(0.96, 0.50).dy)
      ..cubicTo(
        p(0.96, 0.76).dx, p(0.96, 0.76).dy,
        p(0.76, 0.92).dx, p(0.76, 0.92).dy,
        p(0.5, 1.0).dx, p(0.5, 1.0).dy,
      )
      ..cubicTo(
        p(0.24, 0.92).dx, p(0.24, 0.92).dy,
        p(0.04, 0.76).dx, p(0.04, 0.76).dy,
        p(0.04, 0.50).dx, p(0.04, 0.50).dy,
      )
      ..lineTo(p(0.04, 0.13).dx, p(0.04, 0.13).dy)
      ..cubicTo(
        p(0.16, 0.13).dx, p(0.16, 0.13).dy,
        p(0.32, 0.10).dx, p(0.32, 0.10).dy,
        p(0.5, 0.0).dx, p(0.5, 0.0).dy,
      )
      ..close();

    canvas.saveLayer(Offset.zero & size, Paint());

    if (filled) {
      canvas.drawPath(shield, Paint()..color = shieldColor);
    } else {
      canvas.drawPath(
        shield,
        Paint()
          ..color = shieldColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Padlock, centred on the shield's visual centre.
    final cx = w / 2;
    final cy = rect.top + rect.height * 0.50;
    final lockW = w * 0.36;
    final bodyH = lockW * 0.78;
    final shackleR = lockW * 0.27;
    final shackleH = shackleR + lockW * 0.10;
    final totalH = bodyH + shackleH;
    final top = cy - totalH / 2;
    final bodyTop = top + shackleH;

    final lockPaint = Paint()..color = lockColor;
    final shackle = Path()
      ..moveTo(cx - shackleR, bodyTop)
      ..lineTo(cx - shackleR, top + shackleR)
      ..arcToPoint(
        Offset(cx + shackleR, top + shackleR),
        radius: Radius.circular(shackleR),
      )
      ..lineTo(cx + shackleR, bodyTop);
    canvas.drawPath(
      shackle,
      Paint()
        ..color = lockColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = lockW * 0.13
        ..strokeCap = StrokeCap.butt,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - lockW / 2, bodyTop, lockW, bodyH),
        Radius.circular(lockW * 0.12),
      ),
      lockPaint,
    );

    // Keyhole (cut out for the outlined logo, solid for the filled one).
    final holePaint = Paint();
    if (filled) {
      holePaint.color = shieldColor;
    } else {
      holePaint.blendMode = BlendMode.clear;
    }
    final holeCenter = Offset(cx, bodyTop + bodyH * 0.40);
    canvas.drawCircle(holeCenter, lockW * 0.075, holePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          cx - lockW * 0.03,
          holeCenter.dy,
          cx + lockW * 0.03,
          bodyTop + bodyH * 0.72,
        ),
        Radius.circular(lockW * 0.03),
      ),
      holePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShieldLockPainter old) =>
      old.shieldColor != shieldColor ||
      old.lockColor != lockColor ||
      old.filled != filled;
}
