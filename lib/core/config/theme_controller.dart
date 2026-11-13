import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();
  static const _preferenceKey = 'darkModeEnabled';

  bool _isDark = false;

  /// Set by the app shell: captures the current screen right before the theme flips, so the
  /// circular reveal has something to uncover. Awaited before the switch.
  Future<void> Function()? beforeChange;

  /// Where the reveal circle starts (global position of the toggle); null uses a default corner.
  Offset? revealOrigin;

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

  Future<bool> setDark(bool enabled, {Offset? origin}) async {
    if (_isDark == enabled) return true;
    revealOrigin = origin;
    await beforeChange?.call();
    // Switch the UI first so the toggle responds instantly, then save; roll back if saving fails.
    _isDark = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      if (await preferences.setBool(_preferenceKey, enabled)) return true;
    } catch (_) {}
    _isDark = !enabled;
    notifyListeners();
    return false;
  }
}

/// Centre of the widget behind [context] in global coordinates, for the theme reveal's start point.
Offset? originOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(box.size.center(Offset.zero));
}
