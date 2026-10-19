import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../app_lock_controller.dart';
import 'pin_entry.dart';

enum PinFlowMode { verify, create, change }

/// Full-screen PIN flow. Pops `true` when the flow succeeded.
class PinFlowScreen extends StatefulWidget {
  const PinFlowScreen({
    super.key,
    required this.controller,
    required this.mode,
  });

  final AppLockController controller;
  final PinFlowMode mode;

  @override
  State<PinFlowScreen> createState() => _PinFlowScreenState();
}

class _PinFlowScreenState extends State<PinFlowScreen> {
  int _step = 0;
  String? _first;
  String? _error;
  int _reset = 0;
  bool _busy = false;

  String get _title {
    switch (widget.mode) {
      case PinFlowMode.verify:
        return 'Enter PIN';
      case PinFlowMode.create:
        return _step == 0 ? 'Create PIN' : 'Confirm PIN';
      case PinFlowMode.change:
        if (_step == 0) return 'Enter current PIN';
        return _step == 1 ? 'Enter new PIN' : 'Confirm new PIN';
    }
  }

  void _fail(String message, {int? backToStep}) {
    setState(() {
      _error = message;
      _reset++;
      _busy = false;
      if (backToStep != null) {
        _step = backToStep;
        _first = null;
      }
    });
  }

  void _next() {
    setState(() {
      _step++;
      _error = null;
      _reset++;
      _busy = false;
    });
  }

  Future<void> _checkCurrent(String pin, {required bool popOnOk}) async {
    final result = await widget.controller.verifyPin(pin);
    if (!mounted) return;
    switch (result) {
      case PinCheck.ok:
        if (popOnOk) {
          Navigator.pop(context, true);
        } else {
          _next();
        }
      case PinCheck.wrong:
        _fail('Incorrect PIN. Try again.');
      case PinCheck.tooManyAttempts:
        _fail(
          'Too many attempts. Try again in '
          '${widget.controller.lockoutSecondsRemaining}s.',
        );
    }
  }

  Future<void> _confirmNew(String pin) async {
    if (pin != _first) {
      _fail("PINs don't match. Start again.", backToStep: _newPinStep);
      return;
    }
    await widget.controller.savePin(pin);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  int get _newPinStep => widget.mode == PinFlowMode.change ? 1 : 0;

  Future<void> _onComplete(String pin) async {
    if (_busy) return;
    setState(() => _busy = true);
    switch (widget.mode) {
      case PinFlowMode.verify:
        await _checkCurrent(pin, popOnOk: true);
      case PinFlowMode.create:
        if (_step == 0) {
          _first = pin;
          _next();
        } else {
          await _confirmNew(pin);
        }
      case PinFlowMode.change:
        if (_step == 0) {
          await _checkCurrent(pin, popOnOk: false);
        } else if (_step == 1) {
          _first = pin;
          _next();
        } else {
          await _confirmNew(pin);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.hero(context)),
        child: SafeArea(
          child: PinEntry(
            title: _title,
            error: _error,
            hideDigits: widget.controller.hidePin,
            enabled: !_busy,
            resetToken: _reset,
            onComplete: _onComplete,
          ),
        ),
      ),
    );
  }
}
