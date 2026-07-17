import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/theme.dart';
import 'package:easy_localization/easy_localization.dart';

/// Helper to convert a hex string to a Color object.
Color _colorFromHex(String hexColor) {
  try {
    final String hexCode = hexColor.replaceAll('#', '');
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
  final String? translationKey;

  const AppThemeData({
    required this.id,
    required this.name,
    required this.gradient,
    required this.accentColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    this.layout = 'default',
    this.translationKey,
  });

  /// Convenience getter for backward compatibility with older screens.
  Color get textColor => primaryTextColor;

  String localizedName(BuildContext context) {
    if (translationKey != null) {
      return translationKey!.tr(context: context);
    }
    return name;
  }

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
      final LinearGradient lg = gradient as LinearGradient;
      return lg.colors.map((Color c) => _colorToHex(c)).join(',');
    }
    return ''; // Handle other gradient types if needed
  }

  /// Factory to create a theme from a JSON map, used for loading from API/prefs.
  factory AppThemeData.fromJson(Map<String, dynamic> json) {
    List<Color> colors = <Color>[];
    if (json['background_color'] is String) {
      colors = (json['background_color'] as String)
          .split(',')
          .where((String hex) => hex.isNotEmpty)
          .map((String hex) => _colorFromHex(hex))
          .toList();
    }

    return AppThemeData(
      id: json['theme_id'] ?? 'deep_space',
      name: json['name'] ?? json['theme_id'] ?? 'Deep Space',
      gradient: colors.length > 1
          ? LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)
          : (colors.length == 1 
              ? LinearGradient(colors: <Color>[colors.first, colors.first], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : CosmicColors.deepSpaceGradient), 
      accentColor: json['accent_color'] != null ? _colorFromHex(json['accent_color']) : CosmicColors.cosmicPink,
      primaryTextColor: json['primary_text_color'] != null ? _colorFromHex(json['primary_text_color']) : Colors.white,
      secondaryTextColor: json['secondary_text_color'] != null ? _colorFromHex(json['secondary_text_color']) : Colors.white70,
      layout: json['layout'] ?? 'default',
    );
  }
}

/// The default theme for the application.
final AppThemeData defaultTheme = AppThemeData(
  id: 'deep_space',
  name: 'Deep Space',
  gradient: CosmicColors.deepSpaceGradient,
  accentColor: CosmicColors.cosmicPink,
  primaryTextColor: Colors.white,
  secondaryTextColor: Colors.white.withOpacity(0.7),
  translationKey: 'profile.settings.theme.names.deep_space',
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? themeJsonString = prefs.getString('user_theme');
    if (themeJsonString != null) {
      state = AppThemeData.fromJson(jsonDecode(themeJsonString));
    }
  }

  /// Sets the theme based on user profile data from the API, caching it locally.
  /// This does NOT make an API call back to the server.
  Future<void> setThemeFromProfile(AppThemeData newTheme) async {
    state = newTheme;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, String> themeJsonToSave = <String, String>{
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
final NotifierProvider<ThemeNotifier, AppThemeData> themeProvider = NotifierProvider<ThemeNotifier, AppThemeData>(ThemeNotifier.new);

/// Predefined list of themes available for selection.
final List<AppThemeData> availableThemes = <AppThemeData>[
  defaultTheme,
  const AppThemeData(
    id: '2',
    name: 'Nebula Dream',
    gradient: LinearGradient(colors: <Color>[Color(0xFF00416A), Color(0xFF4D089A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    accentColor: Colors.tealAccent,
    primaryTextColor: Colors.white,
    secondaryTextColor: Colors.white70,
    translationKey: 'profile.settings.theme.names.nebula_dream',
  ),
  const AppThemeData(
    id: '1',
    name: 'Starlight',
    gradient: LinearGradient(colors: <Color>[Color(0xFFECE9E6), Color(0xFFFFFFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    accentColor: Colors.deepPurple,
    primaryTextColor: Color(0xFF333333),
    secondaryTextColor: Colors.black54,
    translationKey: 'profile.settings.theme.names.starlight',
  ),
];