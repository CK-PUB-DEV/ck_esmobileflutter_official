import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();
  static const _preferenceKey = 'darkModeEnabled';

  bool _isDark = false;

  bool get isDark => _isDark;
  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _isDark = preferences.getBool(_preferenceKey) ?? false;
      notifyListeners();
    } catch (_) {
      _isDark = false;
    }
  }

  Future<bool> setDark(bool enabled) async {
    if (_isDark == enabled) return true;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setBool(_preferenceKey, enabled)) return false;
      _isDark = enabled;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
