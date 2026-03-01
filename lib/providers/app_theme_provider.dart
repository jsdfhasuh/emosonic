import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/logger.dart';

/// Theme mode options
enum AppThemeMode {
  system,
  light,
  dark,
}

extension AppThemeModeExtension on AppThemeMode {
  String get displayName {
    switch (this) {
      case AppThemeMode.system:
        return '跟随系统';
      case AppThemeMode.light:
        return '浅色主题';
      case AppThemeMode.dark:
        return '深色主题';
    }
  }

  ThemeMode get flutterThemeMode {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  static AppThemeMode fromString(String value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }
}

/// Provider for app theme mode
final appThemeModeProvider = StateNotifierProvider<AppThemeModeNotifier, AppThemeMode>((ref) {
  return AppThemeModeNotifier();
});

/// Notifier for managing app theme mode
class AppThemeModeNotifier extends StateNotifier<AppThemeMode> {
  static const String _prefsKey = 'app_theme_mode';
  static const AppThemeMode _defaultValue = AppThemeMode.dark;
  final Logger _logger = Logger('AppThemeModeNotifier');

  AppThemeModeNotifier() : super(_defaultValue) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_prefsKey);
      if (value != null) {
        state = AppThemeModeExtension.fromString(value);
      }
      _logger.info('Loaded theme mode: ${state.displayName}');
    } catch (e) {
      _logger.error('Failed to load theme mode: $e');
      state = _defaultValue;
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
      state = mode;
      _logger.info('Theme mode updated: ${mode.displayName}');
    } catch (e) {
      _logger.error('Failed to save theme mode: $e');
    }
  }
}
