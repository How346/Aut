import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const String _modeKey = 'authly_theme_mode';
  static const String _accentKey = 'authly_accent_index';

  ThemeMode _mode = ThemeMode.system;
  int _accentIndex = 0;

  ThemeMode get mode => _mode;
  int get accentIndex => _accentIndex;
  Color get accent => AppTheme.accents[_accentIndex];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_modeKey);
    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
    final index = prefs.getInt(_accentKey) ?? 0;
    _accentIndex = (index >= 0 && index < AppTheme.accents.length) ? index : 0;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> setAccentIndex(int index) async {
    if (index < 0 || index >= AppTheme.accents.length) return;
    _accentIndex = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, index);
  }
}
