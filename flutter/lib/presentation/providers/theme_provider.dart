import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/theme.dart';

/// Helper to convert a hex string to a Color object.
Color _colorFromHex(String hexColor) {
  try {
    final hexCode = hexColor.replaceAll('#', '');
    if (hexCode.length == 6) {
      return Color(int.parse('FF$hexCode', radix: 16));
    }
    if (hexCode.length == 8) {
      return Color(int.parse(hexCode, radix: 16));
    }
  } catch (e) {
    debugPrint('Failed to parse color: $hexColor. Error: $e');
  }
  // Return a default/fallback color if parsing fails or format is unexpected.
  return Colors.black;
}

/// Helper to convert a Color object to a hex string.
String _colorToHex(Color color) {
  return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
}

/// Data class representing the visual theme of the application.
@immutable
class AppThemeData {
  final String id;
  final String name;
  final Gradient gradient;
  final Color accentColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final String layout;

  const AppThemeData({
    required this.id,
    required this.name,
    required this.gradient,
    required this.accentColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    this.layout = 'default',
  });

  /// Convenience getter for backward compatibility with older screens.
  Color get textColor => primaryTextColor;

  /// Returns the first color of the gradient as a representative solid background color.
  Color get backgroundColor {
    if (gradient is LinearGradient) {
      return (gradient as LinearGradient).colors.first;
    }
    return Colors.black;
  }

  /// Converts the gradient's colors to a comma-separated hex string for API storage.
  String get gradientString {
    if (gradient is LinearGradient) {
      final lg = gradient as LinearGradient;
      return lg.colors.map((c) => _colorToHex(c)).join(',');
    }
    return ''; // Handle other gradient types if needed
  }

  /// Factory to create a theme from a JSON map, used for loading from API/prefs.
  factory AppThemeData.fromJson(Map<String, dynamic> json) {
    List<Color> colors = [];
    if (json['background_color'] is String) {
      colors = (json['background_color'] as String)
          .split(',')
          .where((hex) => hex.isNotEmpty)
          .map((hex) => _colorFromHex(hex))
          .toList();
    }

    return AppThemeData(
      id: json['theme_id'] ?? 'deep_space',
      name: json['name'] ?? json['theme_id'] ?? 'Deep Space',
      gradient: colors.length > 1
          ? LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)
          : (colors.length == 1 
              ? LinearGradient(colors: [colors.first, colors.first], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : CosmicColors.deepSpaceGradient), 
      accentColor: json['accent_color'] != null ? _colorFromHex(json['accent_color']) : CosmicColors.cosmicPink,
      primaryTextColor: json['primary_text_color'] != null ? _colorFromHex(json['primary_text_color']) : Colors.white,
      secondaryTextColor: json['secondary_text_color'] != null ? _colorFromHex(json['secondary_text_color']) : Colors.white70,
      layout: json['layout'] ?? 'default',
    );
  }
}

/// The default theme for the application.
final defaultTheme = AppThemeData(
  id: 'deep_space',
  name: 'Deep Space',
  gradient: CosmicColors.deepSpaceGradient,
  accentColor: CosmicColors.cosmicPink,
  primaryTextColor: Colors.white,
  secondaryTextColor: Colors.white.withOpacity(0.7),
);

/// Notifier to manage the theme state and interactions with the API.
class ThemeNotifier extends Notifier<AppThemeData> {
  @override
  AppThemeData build() {
    _loadThemeFromPrefs();
    return defaultTheme;
  }

  /// Loads the saved theme from local storage on app startup.
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeJsonString = prefs.getString('user_theme');
    if (themeJsonString != null) {
      state = AppThemeData.fromJson(jsonDecode(themeJsonString));
    }
  }

  /// Sets the theme based on user profile data from the API, caching it locally.
  /// This does NOT make an API call back to the server.
  Future<void> setThemeFromProfile(AppThemeData newTheme) async {
    state = newTheme;
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeJsonToSave = {
        'theme_id': newTheme.id,
        'name': newTheme.name,
        'background_color': newTheme.gradientString,
        'accent_color': _colorToHex(newTheme.accentColor),
        'primary_text_color': _colorToHex(newTheme.primaryTextColor),
        'secondary_text_color': _colorToHex(newTheme.secondaryTextColor),
        'layout': newTheme.layout,
      };
      await prefs.setString('user_theme', jsonEncode(themeJsonToSave));
    } catch (e) {
      debugPrint('Error saving theme from profile to prefs: $e');
    }
  }
}

/// The main provider for accessing the theme state throughout the app.
final themeProvider = NotifierProvider<ThemeNotifier, AppThemeData>(ThemeNotifier.new);

/// Predefined list of themes available for selection.
final availableThemes = [
  defaultTheme,
  AppThemeData(
    id: '2',
    name: 'Nebula Dream',
    gradient: const LinearGradient(colors: [Color(0xFF00416A), Color(0xFF4D089A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    accentColor: Colors.tealAccent,
    primaryTextColor: Colors.white,
    secondaryTextColor: Colors.white70,
  ),
  AppThemeData(
    id: '1',
    name: 'Starlight',
    gradient: const LinearGradient(colors: [Color(0xFFECE9E6), Color(0xFFFFFFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    accentColor: Colors.deepPurple,
    primaryTextColor: const Color(0xFF333333),
    secondaryTextColor: Colors.black54,
  ),
];