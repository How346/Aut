import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'biometric_service.dart';

enum PinCheck { ok, wrong, tooManyAttempts }

/// App lock: PIN (stored as a salted PBKDF2 hash in the Keystore-backed
/// secure storage) with optional biometric unlock and an auto-lock timeout.
class AppLockController extends ChangeNotifier {
  static const String _enabledKey = 'authly_app_lock_enabled';
  static const String _biometricKey = 'authly_biometric_enabled';
  static const String _autoLockKey = 'authly_auto_lock_minutes';
  static const String _hidePinKey = 'authly_hide_pin';
  static const String _pinHashKey = 'authly_pin_hash_v1';
  static const String _pinSaltKey = 'authly_pin_salt_v1';

  static const int pinLength = 4;
  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(seconds: 30);
  static const List<int> autoLockOptions = [0, 1, 5, 15];

  static final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 20000,
    bits: 256,
  );

  final BiometricService _biometrics;
  final FlutterSecureStorage _storage;

  bool _enabled = false;
  bool _biometricEnabled = false;
  bool _hasPin = false;
  bool _hidePin = true;
  bool _locked = false;
  int _autoLockMinutes = 1;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  DateTime? _pausedAt;
  bool _authenticating = false;

  AppLockController({
    BiometricService? biometrics,
    FlutterSecureStorage? storage,
  })  : _biometrics = biometrics ?? BiometricService(),
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: true,
              ),
            );

  bool get enabled => _enabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get hasPin => _hasPin;
  bool get hidePin => _hidePin;
  bool get locked => _locked;
  int get autoLockMinutes => _autoLockMinutes;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _biometricEnabled = prefs.getBool(_biometricKey) ?? false;
    _hidePin = prefs.getBool(_hidePinKey) ?? true;
    final minutes = prefs.getInt(_autoLockKey) ?? 1;
    _autoLockMinutes = autoLockOptions.contains(minutes) ? minutes : 1;
    try {
      final hash = await _storage.read(key: _pinHashKey);
      _hasPin = hash != null && hash.isNotEmpty;
    } catch (_) {
      _hasPin = false;
    }
    if (_enabled && !_hasPin) {
      // Lock was enabled by an older version without a PIN.
      _enabled = false;
      await prefs.setBool(_enabledKey, false);
    }
    _locked = _enabled;
    notifyListeners();
  }

  Future<bool> biometricsSupported() => _biometrics.isDeviceSupported();

  // ---------------------------------------------------------------- PIN

  Future<String> _hash(String pin, List<int> salt) async {
    final key = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return base64Encode(await key.extractBytes());
  }

  Future<void> savePin(String pin) async {
    final rng = Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));
    final hash = await _hash(pin, salt);
    await _storage.write(key: _pinSaltKey, value: base64Encode(salt));
    await _storage.write(key: _pinHashKey, value: hash);
    _hasPin = true;
    _failedAttempts = 0;
    _lockedUntil = null;
    notifyListeners();
  }

  /// Seconds left of a temporary lockout, or 0.
  int get lockoutSecondsRemaining {
    final until = _lockedUntil;
    if (until == null) return 0;
    final left = until.difference(DateTime.now()).inSeconds + 1;
    return left > 0 ? left : 0;
  }

  Future<PinCheck> verifyPin(String pin) async {
    if (lockoutSecondsRemaining > 0) return PinCheck.tooManyAttempts;
    try {
      final saltB64 = await _storage.read(key: _pinSaltKey);
      final stored = await _storage.read(key: _pinHashKey);
      if (saltB64 == null || stored == null) return PinCheck.wrong;
      final candidate = await _hash(pin, base64Decode(saltB64));
      if (_constantTimeEquals(candidate, stored)) {
        _failedAttempts = 0;
        _lockedUntil = null;
        return PinCheck.ok;
      }
    } catch (_) {
      return PinCheck.wrong;
    }
    _failedAttempts++;
    if (_failedAttempts >= maxAttempts) {
      _failedAttempts = 0;
      _lockedUntil = DateTime.now().add(lockoutDuration);
      return PinCheck.tooManyAttempts;
    }
    return PinCheck.wrong;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // ----------------------------------------------------------- Settings

  /// Turns the lock on or off. Turning on requires an existing PIN.
  Future<bool> setEnabled(bool value) async {
    if (value && !_hasPin) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    _enabled = value;
    _locked = false;
    notifyListeners();
    return true;
  }

  Future<bool> setBiometricEnabled(bool value) async {
    if (value) {
      if (!await _biometrics.isDeviceSupported()) return false;
      final ok = await _biometrics.authenticate(
        localizedReason: 'Confirm to enable biometric unlock',
      );
      if (!ok) return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, value);
    _biometricEnabled = value;
    notifyListeners();
    return true;
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    if (!autoLockOptions.contains(minutes)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockKey, minutes);
    _autoLockMinutes = minutes;
    notifyListeners();
  }

  Future<void> setHidePin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hidePinKey, value);
    _hidePin = value;
    notifyListeners();
  }

  // ---------------------------------------------------------- Lifecycle

  void onBackground() {
    _pausedAt = DateTime.now();
  }

  void onForeground() {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (!_enabled || _locked || pausedAt == null || _authenticating) return;
    final away = DateTime.now().difference(pausedAt);
    if (away >= Duration(minutes: _autoLockMinutes)) {
      _locked = true;
      notifyListeners();
    }
  }

  void unlockNow() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  Future<bool> unlockWithBiometrics() async {
    if (!_biometricEnabled || _authenticating) return false;
    _authenticating = true;
    try {
      final ok = await _biometrics.authenticate(
        localizedReason: 'Unlock Authly',
      );
      if (ok) unlockNow();
      return ok;
    } finally {
      _authenticating = false;
    }
  }
}
