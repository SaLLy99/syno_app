import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifier;
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/websocket_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's authentication state and profile data.
class UserStateNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref _ref;
  String? _authToken;
  bool _justReactivated = false;

  UserStateNotifier(this._ref) : super(const AsyncValue.loading()) {
    _initializeUserAndToken();
  }

  String? get authToken => _authToken;
  bool get justReactivated => _justReactivated;

  void clearJustReactivated() {
    _justReactivated = false;
  }

  Future<void> _initializeUserAndToken() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token'); // Load token on init
      if (_authToken != null) {
        await refreshUser();
        _connectWebSocket();
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      debugPrint("[UserStateNotifier] Error fetching user: $e");
      if (e.toString().contains('401') || e.toString().contains('Unauthorized') || e.toString().contains('Could not validate credentials')) {
        await _clearAuthToken();
      }
      // Treat errors as "Logged Out" so the app doesn't get stuck in an error state.
      if (mounted) {
        state = const AsyncValue.data(null);
      }
    }
  }

  void _connectWebSocket() {
    try {
      final wsService = _ref.read(webSocketServiceProvider);
      wsService.connect();
    } catch (e) {
      debugPrint("[UserStateNotifier] WebSocket connection failed: $e");
    }
  }

  Future<void> _clearAuthToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _authToken = null;
  }

  /// Re-fetches the user profile from the backend.
  Future<void> refreshUser({String? token}) async {
    state = const AsyncValue.loading();
    if (token != null) {
      _authToken = token;
      // Save token to persistence synchronously before fetching user
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    }
    try {
      final User? user = await _ref.read(userServiceProvider).fetchUser();
      if (mounted) {
        // If the fetched user has theme preferences from the API, apply them.
        if (user?.themePreferences != null) {
          final AppThemeData themeData = AppThemeData.fromJson(user!.themePreferences!);
          _ref.read(themeProvider.notifier).setThemeFromProfile(themeData);
        }
        state = AsyncValue.data(user);
        // Clear reactivated flag once we have a valid user profile
        if (user != null) {
          _justReactivated = false;
        }
      }
    } catch (e) {
      debugPrint("[UserStateNotifier] Error in refreshUser: $e");
      if (e.toString().contains('401') || e.toString().contains('Unauthorized') || e.toString().contains('Could not validate credentials')) {
        await _clearAuthToken();
      }
      if (mounted) state = const AsyncValue.data(null);
    }
  }

  /// Allows manually setting the user state and optionally the auth token, e.g., after a profile update or login.
  Future<AsyncValue<User?>> setUser(User? user, {String? token}) async {
    if (token != null) {
      _authToken = token;
      // Save token synchronously to avoid race conditions
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    }
    // Force a state transition to ensure listeners (like the Router) re-evaluate
    state = const AsyncValue.loading();
    state = AsyncValue.data(user);
    return state;
  }

  Future<void> createProfileWithPhotos(Map<String, dynamic> combinedData, List<String> paths, {bool firstIsPrimary = false}) async {
    try {
      final User createUser = await _ref
          .read(userServiceProvider)
          .createProfileWithPhotos(combinedData, paths, firstIsPrimary: firstIsPrimary);
      state = AsyncValue.data(createUser);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<User> updateUserProfile(Map<String, dynamic> apiData) async {
    try {
      // Use createProfileWithPhotos for updates as well. Pass an empty list for photos
      // since this method is for data-only changes. The backend will preserve existing photos.
      final User updatedUser = await _ref.read(userServiceProvider).createProfileWithPhotos(apiData, <String>[], firstIsPrimary: true);

      state = AsyncValue.data(updatedUser);
      return updatedUser;
    } catch (e) {
      // state = AsyncValue.error(e, st); // Don't set global error state on update failure
      rethrow; 
    }
  }

  Future<User> updateProfilePhoto(String photoPath) async {
    try {
      // Use createProfileWithPhotos to update only the photo.
      // The backend PATCH logic will handle this correctly.
      final User updatedUser = await _ref.read(userServiceProvider).createProfileWithPhotos(<String, dynamic>{}, <String>[photoPath], firstIsPrimary: true);
      state = AsyncValue.data(updatedUser);
      return updatedUser;
    } catch (e) {
      // state = AsyncValue.error(e, st); // Don't set global error state on update failure
      rethrow;
    }
  }

  Future<void> deletePhoto(int photoId) async {
    try {
      await _ref.read(userServiceProvider).deletePhoto(photoId);

      // After successful deletion, refetch the user to get the updated list of photos
      // and ensure the primary photo is correctly identified.
      final User? updatedUser = await _ref.read(userServiceProvider).fetchUser();
      state = AsyncValue.data(updatedUser);

    } catch (e) {
      // state = AsyncValue.error(e, st); // Don't set global error state on update failure
      rethrow; // Rethrow to allow the UI to catch it and show a message.
    }
  }

  Future<void> unblockUser(int userId) async {
    try {
      await _ref.read(userServiceProvider).unblockUser(userId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deactivateAccount() async {
    try {
      await _ref.read(userServiceProvider).deleteAccount();
      await logout();
    } catch (e) { rethrow; }
  }

  Future<void> requestReactivation({String? email, String? phoneNumber}) async {
    try {
      await _ref.read(userServiceProvider).requestReactivation(email: email, phoneNumber: phoneNumber);
    } catch (e) { rethrow; }
  }

  Future<void> verifyReactivation({String? email, String? phoneNumber, required String code}) async {
    try {
      final String token = await _ref.read(userServiceProvider).verifyReactivation(
        email: email,
        phoneNumber: phoneNumber,
        code: code,
      );
      _justReactivated = true;
      await refreshUser(token: token);
    } catch (e) { rethrow; }
  }

  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _authToken = null;
    _justReactivated = false;
    _ref.read(registrationProvider.notifier).reset();
    state = const AsyncValue.data(null);
  }

  Future<void> blockUserByName(String name) async {
    try {
      await _ref.read(userServiceProvider).blockUserByName(name);
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> searchUserByName(String name) async {
    try {
      return await _ref.read(userServiceProvider).searchUserByName(name);
    } catch (e) {
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }
}