import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'biometric_service.dart';

/// Holds the persisted "app lock" toggle and the current locked state.
class AppLockController extends ChangeNotifier {
  static const String _prefKey = 'authly_app_lock_enabled';

  final BiometricService _biometrics;
  bool _enabled = false;
  bool _locked = false;
  bool _authenticating = false;

  AppLockController({BiometricService? biometrics})
      : _biometrics = biometrics ?? BiometricService();

  bool get enabled => _enabled;
  bool get locked => _locked;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? false;
    _locked = _enabled;
    notifyListeners();
  }

  Future<bool> isSupported() => _biometrics.isDeviceSupported();

  /// Enables/disables the lock. Enabling requires a successful authentication.
  Future<bool> setEnabled(bool value) async {
    if (value) {
      if (!await _biometrics.isDeviceSupported()) return false;
      final ok = await _biometrics.authenticate(
        localizedReason: 'Confirm to enable app lock',
      );
      if (!ok) return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    _enabled = value;
    _locked = false;
    notifyListeners();
    return true;
  }

  void lock() {
    if (_enabled && !_locked) {
      _locked = true;
      notifyListeners();
    }
  }

  Future<void> unlock() async {
    if (!_enabled) {
      _locked = false;
      notifyListeners();
      return;
    }
    if (_authenticating) return;
    _authenticating = true;
    try {
      final ok = await _biometrics.authenticate(
        localizedReason: 'Unlock Authly',
      );
      if (ok) {
        _locked = false;
        notifyListeners();
      }
    } finally {
      _authenticating = false;
    }
  }
}
