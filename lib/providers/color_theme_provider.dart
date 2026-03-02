import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/logger.dart';

/// Available color themes
enum ColorTheme {
  deepBlue,
  obsidianPurple,
  amberOrange,
  forestGreen,
  roseRed,
  graphiteGrey,
}

/// Theme data configuration
class AppColorTheme {
  final String name;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color accentColor;
  final Color secondaryAccentColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;

  const AppColorTheme({
    required this.name,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.accentColor,
    required this.secondaryAccentColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
  });

  /// Deep Blue (深海蓝) - Default theme
  static const deepBlue = AppColorTheme(
    name: '深海蓝',
    backgroundColor: Color(0xFF1E293B),
    surfaceColor: Color(0xFF2D3B4E),
    accentColor: Color(0xFF6B8DD6),
    secondaryAccentColor: Color(0xFF8FA1B3),
    textPrimaryColor: Color(0xFFFFFFFF),
    textSecondaryColor: Color(0xFF94A3B8),
  );

  /// Obsidian Purple (曜石紫)
  static const obsidianPurple = AppColorTheme(
    name: '曜石紫',
    backgroundColor: Color(0xFF1E1B2E),
    surfaceColor: Color(0xFF2D2A3E),
    accentColor: Color(0xFF9A7BFF),
    secondaryAccentColor: Color(0xFFB8A9E8),
    textPrimaryColor: Color(0xFFFFFFFF),
    textSecondaryColor: Color(0xFFA69EC0),
  );

  /// Amber Orange (琥珀橙)
  static const amberOrange = AppColorTheme(
    name: '琥珀橙',
    backgroundColor: Color(0xFF2B1C14),
    surfaceColor: Color(0xFF3D2A1F),
    accentColor: Color(0xFFF4A261),
    secondaryAccentColor: Color(0xFFE9C46A),
    textPrimaryColor: Color(0xFFFFFFFF),
    textSecondaryColor: Color(0xFFD4A574),
  );

  /// Forest Green (森林绿)
  static const forestGreen = AppColorTheme(
    name: '森林绿',
    backgroundColor: Color(0xFF1B2B23),
    surfaceColor: Color(0xFF2A3D33),
    accentColor: Color(0xFF6DD6A1),
    secondaryAccentColor: Color(0xFF88D4AA),
    textPrimaryColor: Color(0xFFFFFFFF),
    textSecondaryColor: Color(0xFF8FAE9C),
  );

  /// Rose Red (玫瑰红)
  static const roseRed = AppColorTheme(
    name: '玫瑰红',
    backgroundColor: Color(0xFF2B1B22),
    surfaceColor: Color(0xFF3D2A33),
    accentColor: Color(0xFFFF6B8A),
    secondaryAccentColor: Color(0xFFFF9AAE),
    textPrimaryColor: Color(0xFFFFFFFF),
    textSecondaryColor: Color(0xFFC99AA8),
  );

  /// Graphite Grey (石墨灰)
  static const graphiteGrey = AppColorTheme(
    name: '石墨灰',
    backgroundColor: Color(0xFF1C1F24),
    surfaceColor: Color(0xFF2A2E35),
    accentColor: Color(0xFF8FA1B3),
    secondaryAccentColor: Color(0xFFA8B5C4),
    textPrimaryColor: Color(0xFFFFFFFF),
    textSecondaryColor: Color(0xFF8E99A4),
  );

  /// Get theme by enum
  static AppColorTheme fromEnum(ColorTheme theme) {
    switch (theme) {
      case ColorTheme.deepBlue:
        return deepBlue;
      case ColorTheme.obsidianPurple:
        return obsidianPurple;
      case ColorTheme.amberOrange:
        return amberOrange;
      case ColorTheme.forestGreen:
        return forestGreen;
      case ColorTheme.roseRed:
        return roseRed;
      case ColorTheme.graphiteGrey:
        return graphiteGrey;
    }
  }
}

/// Provider for color theme
final colorThemeProvider = StateNotifierProvider<ColorThemeNotifier, AppColorTheme>((ref) {
  return ColorThemeNotifier();
});

/// Notifier for managing color theme
class ColorThemeNotifier extends StateNotifier<AppColorTheme> {
  static const String _prefsKey = 'app_color_theme';
  static const ColorTheme _defaultTheme = ColorTheme.deepBlue;
  final Logger _logger = Logger('ColorThemeNotifier');

  ColorThemeNotifier() : super(AppColorTheme.deepBlue) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString(_prefsKey);
      
      if (themeName != null) {
        final theme = ColorTheme.values.firstWhere(
          (t) => t.name == themeName,
          orElse: () => _defaultTheme,
        );
        state = AppColorTheme.fromEnum(theme);
      }
      _logger.info('Loaded color theme: ${state.name}');
    } catch (e) {
      _logger.error('Failed to load color theme: $e');
      state = AppColorTheme.fromEnum(_defaultTheme);
    }
  }

  Future<void> setTheme(ColorTheme theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, theme.name);
      state = AppColorTheme.fromEnum(theme);
      _logger.info('Color theme updated: ${state.name}');
    } catch (e) {
      _logger.error('Failed to save color theme: $e');
    }
  }
}
