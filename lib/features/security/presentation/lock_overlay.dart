import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../app_lock_controller.dart';
import 'pin_entry.dart';

/// Full-screen lock shown on top of the app while it is locked.
class LockOverlay extends StatefulWidget {
  const LockOverlay({super.key, required this.controller});

  final AppLockController controller;

  @override
  State<LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<LockOverlay> {
  late bool _pinMode = !widget.controller.biometricEnabled;
  String? _error;
  int _reset = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!_pinMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    final ok = await widget.controller.unlockWithBiometrics();
    if (!ok && mounted) {
      setState(() => _pinMode = true);
    }
  }

  Future<void> _onPin(String pin) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.controller.verifyPin(pin);
    if (!mounted) return;
    switch (result) {
      case PinCheck.ok:
        widget.controller.unlockNow();
      case PinCheck.wrong:
        setState(() {
          _error = 'Incorrect PIN. Try again.';
          _reset++;
          _busy = false;
        });
      case PinCheck.tooManyAttempts:
        setState(() {
          _error = 'Too many attempts. Try again in '
              '${widget.controller.lockoutSecondsRemaining}s.';
          _reset++;
          _busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        child: _pinMode ? _buildPin(context) : _buildBiometric(context),
      ),
    );
  }

  Widget _buildPin(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.hero(context)),
      child: SafeArea(
        child: PinEntry(
          title: 'Enter PIN',
          error: _error,
          hideDigits: widget.controller.hidePin,
          enabled: !_busy,
          resetToken: _reset,
          onComplete: _onPin,
          onBiometric: widget.controller.biometricEnabled
              ? () {
                  _tryBiometric();
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildBiometric(BuildContext context) {
    final primary = Theme.of(context).colorScheme.secondary;
    return Container(
      color: const Color(0xFF0F1A2E),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Use Biometrics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Authenticate with your fingerprint or face to unlock Authly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB6C2D9), fontSize: 14),
                ),
                const SizedBox(height: 36),
                InkResponse(
                  onTap: _tryBiometric,
                  radius: 70,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.16),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(Icons.fingerprint, color: primary, size: 66),
                  ),
                ),
                const SizedBox(height: 28),
                TextButton(
                  onPressed: () => setState(() => _pinMode = true),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
