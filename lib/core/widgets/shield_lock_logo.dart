import 'package:flutter/material.dart';

/// The Authly logo: a shield with a padlock, traced from the brand artwork.
///
/// By default the shield is filled with [shieldColor] and the padlock is white
/// (or [lockColor]). With [cutout] the padlock is punched out of the shield,
/// which is used on the blue splash screen (white shield, gradient showing
/// through the padlock).
class ShieldLockLogo extends StatelessWidget {
  const ShieldLockLogo({
    super.key,
    required this.size,
    required this.shieldColor,
    this.lockColor,
    this.cutout = false,
  });

  /// Width of the logo. The height is `size * 1.2107`.
  final double size;
  final Color shieldColor;
  final Color? lockColor;
  final bool cutout;

  static const double aspect = 1.2107;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * aspect,
      child: CustomPaint(
        painter: _ShieldLockPainter(
          shieldColor: shieldColor,
          lockColor: lockColor ?? Colors.white,
          cutout: cutout,
        ),
      ),
    );
  }
}

class _ShieldLockPainter extends CustomPainter {
  _ShieldLockPainter({
    required this.shieldColor,
    required this.lockColor,
    required this.cutout,
  });

  final Color shieldColor;
  final Color lockColor;
  final bool cutout;

  /// Half-width profile of the shield as (y, halfWidth) pairs, both in units
  /// of the shield width. The shield is symmetric around x = 0.5.
  static const List<double> _profile = [
    0.0, 0.0114,
    0.0021, 0.0217,
    0.0083, 0.0393,
    0.1529, 0.4243,
    0.1653, 0.4537,
    0.1715, 0.4652,
    0.1756, 0.4708,
    0.1818, 0.4777,
    0.1901, 0.4847,
    0.2004, 0.491,
    0.2107, 0.4953,
    0.2252, 0.499,
    0.2376, 0.5,
    0.6157, 0.5,
    0.6529, 0.4977,
    0.6798, 0.4947,
    0.7066, 0.4906,
    0.7231, 0.4874,
    0.75, 0.4809,
    0.7686, 0.4756,
    0.8017, 0.464,
    0.8161, 0.4584,
    0.845, 0.4453,
    0.876, 0.4292,
    0.8967, 0.417,
    0.9236, 0.3994,
    0.9504, 0.3798,
    0.9835, 0.3523,
    1.0, 0.3369,
    1.0351, 0.3013,
    1.062, 0.2706,
    1.0826, 0.2447,
    1.1136, 0.2014,
    1.1343, 0.1691,
    1.1508, 0.1412,
    1.1632, 0.1188,
    1.1818, 0.082,
    1.2025, 0.0351,
    1.2066, 0.0248,
    1.2087, 0.0155,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;

    final shield = Path();
    for (var i = 0; i < _profile.length; i += 2) {
      final x = cx - _profile[i + 1] * s;
      final y = _profile[i] * s;
      if (i == 0) {
        shield.moveTo(x, y);
      } else {
        shield.lineTo(x, y);
      }
    }
    for (var i = _profile.length - 2; i >= 0; i -= 2) {
      shield.lineTo(cx + _profile[i + 1] * s, _profile[i] * s);
    }
    shield.close();

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(shield, Paint()..color = shieldColor);

    final lockPaint = Paint();
    if (cutout) {
      lockPaint.blendMode = BlendMode.clear;
    } else {
      lockPaint.color = lockColor;
    }

    // Shackle.
    final strokeW = 0.0495 * s;
    final radius = 0.178 * s - strokeW / 2;
    final arcCenterY = (0.176 + 0.178) * s;
    final bodyTop = 0.4617 * s;
    final shackle = Path()
      ..moveTo(cx - radius, bodyTop)
      ..lineTo(cx - radius, arcCenterY)
      ..arcToPoint(
        Offset(cx + radius, arcCenterY),
        radius: Radius.circular(radius),
      )
      ..lineTo(cx + radius, bodyTop);
    canvas.drawPath(
      shackle,
      Paint()
        ..color = lockPaint.color
        ..blendMode = lockPaint.blendMode
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    // Body.
    canvas.drawRRect(
      RRect.fromLTRBR(
        0.265 * s,
        bodyTop,
        0.735 * s,
        0.868 * s,
        Radius.circular(0.055 * s),
      ),
      lockPaint,
    );

    // Keyhole (always the shield colour).
    final keyPaint = Paint()..color = shieldColor;
    canvas.drawCircle(Offset(cx, 0.619 * s), 0.051 * s, keyPaint);
    final slot = Path()
      ..moveTo(cx - 0.030 * s, 0.662 * s)
      ..lineTo(cx + 0.030 * s, 0.662 * s)
      ..lineTo(cx + 0.053 * s, 0.786 * s)
      ..lineTo(cx - 0.053 * s, 0.786 * s)
      ..close();
    canvas.drawPath(slot, keyPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShieldLockPainter old) =>
      old.shieldColor != shieldColor ||
      old.lockColor != lockColor ||
      old.cutout != cutout;
}
