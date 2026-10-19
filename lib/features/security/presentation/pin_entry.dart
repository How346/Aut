import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_lock_controller.dart';

/// Lock icon, title, PIN dots and a numeric keypad. Meant to be shown on the
/// blue hero gradient (all colours are white).
class PinEntry extends StatefulWidget {
  const PinEntry({
    super.key,
    required this.title,
    required this.onComplete,
    this.error,
    this.hideDigits = true,
    this.enabled = true,
    this.resetToken = 0,
    this.onBiometric,
  });

  final String title;
  final ValueChanged<String> onComplete;
  final String? error;
  final bool hideDigits;
  final bool enabled;

  /// Change this value to clear the entered digits.
  final int resetToken;

  /// When set, a fingerprint key is shown in the bottom-left slot.
  final VoidCallback? onBiometric;

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PinEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) {
      _pin = '';
      if (widget.error != null && widget.error!.isNotEmpty) {
        HapticFeedback.heavyImpact();
        _shake.forward(from: 0);
      }
    }
  }

  void _tap(String digit) {
    if (!widget.enabled || _pin.length >= AppLockController.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += digit);
    if (_pin.length == AppLockController.pinLength) {
      widget.onComplete(_pin);
    }
  }

  void _backspace() {
    if (!widget.enabled || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _key(String digit) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _tap(digit),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconKey(IconData icon, VoidCallback? onTap) {
    if (onTap == null) return const SizedBox(width: 72, height: 72);
    return InkResponse(
      onTap: onTap,
      radius: 40,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _dot(int index) {
    final filled = index < _pin.length;
    if (filled && !widget.hideDigits) {
      return SizedBox(
        width: 28,
        child: Center(
          child: Text(
            _pin[index],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 28,
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.white : Colors.transparent,
            border: Border.all(color: Colors.white, width: 1.6),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[
      [_key('1'), _key('2'), _key('3')],
      [_key('4'), _key('5'), _key('6')],
      [_key('7'), _key('8'), _key('9')],
      [
        _iconKey(Icons.fingerprint, widget.onBiometric),
        _key('0'),
        _iconKey(Icons.backspace_outlined, _backspace),
      ],
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final dx = math.sin(_shake.value * math.pi * 6) *
                    12 *
                    (1 - _shake.value);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < AppLockController.pinLength; i++) _dot(i),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  widget.error ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD1D1),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < row.length; i++) ...[
                      if (i > 0) const SizedBox(width: 22),
                      row[i],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
