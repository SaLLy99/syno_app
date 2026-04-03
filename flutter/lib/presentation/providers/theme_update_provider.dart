import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';

/// A dedicated notifier for handling the theme update process.
///
/// This centralizes the logic for:
/// 1. Preparing theme data for the API.
/// 2. Calling the user service to persist the change.
/// 3. Updating the global `currentUserProvider` and `themeProvider` on success.
/// 4. Managing its own loading/error state, which can be watched by the UI.
final themeUpdateProvider = StateNotifierProvider<ThemeUpdateNotifier, AsyncValue<void>>((ref) {
  return ThemeUpdateNotifier(ref);
});

class ThemeUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ThemeUpdateNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Updates the user's theme on the backend and refreshes the app's state.
  Future<void> updateTheme(AppThemeData newTheme) async {
    state = const AsyncValue.loading();

    try {
      // Helper to convert Color to an #RRGGBB hex string for the backend.
      String colorToHex(Color color) {
        return '#${color.value.toRadixString(16).substring(2).padLeft(6, '0')}';
      }

      // The backend expects a single background color, but the theme uses a gradient.
      // We'll use the first color of the gradient as the representative background color.
      final backgroundColor = (newTheme.gradient is LinearGradient)
          ? (newTheme.gradient as LinearGradient).colors.first
          : Colors.black; // Fallback color

      final themeData = {
        'theme_id': newTheme.id,
        'background_color': colorToHex(backgroundColor),
        'accent_color': colorToHex(newTheme.accentColor),
        'layout': newTheme.layout,
      };

      // 1. Call the service to update the backend. This returns the full, updated user object.
      final updatedUser = await _ref.read(userServiceProvider).updateTheme(themeData);

      // 2. Update the global theme provider with the new theme from the response.
      if (updatedUser.themePreferences != null) {
        final newThemeData = AppThemeData.fromJson(updatedUser.themePreferences!);
        _ref.read(themeProvider.notifier).setThemeFromProfile(newThemeData);
      }

      // 3. Update the global user provider with the new user data.
      _ref.read(currentUserProvider.notifier).setUser(updatedUser);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}