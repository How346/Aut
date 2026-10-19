import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small persisted app preferences (onboarding + clipboard protection).
class AppSettings extends ChangeNotifier {
  static const String _onboardingKey = 'authly_onboarding_done';
  static const String _clipboardKey = 'authly_clipboard_clear';
  static const String _maskKey = 'authly_mask_codes';

  bool _onboardingDone = false;
  bool _clipboardClear = true;
  bool _maskCodes = false;

  bool get onboardingDone => _onboardingDone;

  /// Show codes as bullets until the eye button is tapped.
  bool get maskCodes => _maskCodes;

  /// Clear the clipboard 30 seconds after a code is copied.
  bool get clipboardClear => _clipboardClear;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool(_onboardingKey) ?? false;
    _clipboardClear = prefs.getBool(_clipboardKey) ?? true;
    _maskCodes = prefs.getBool(_maskKey) ?? false;
    notifyListeners();
  }

  Future<void> setOnboardingDone() async {
    _onboardingDone = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  Future<void> setClipboardClear(bool value) async {
    _clipboardClear = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clipboardKey, value);
  }

  Future<void> setMaskCodes(bool value) async {
    _maskCodes = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_maskKey, value);
  }
}
