import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifier;
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's authentication state and profile data.
class UserStateNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref _ref;
  String? _authToken;

  UserStateNotifier(this._ref) : super(const AsyncValue.loading()) {
    _initializeUserAndToken();
  }

  String? get authToken => _authToken;

  Future<void> _initializeUserAndToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token'); // Load token on init

      final User? user = await _ref.read(userServiceProvider).fetchUser();
      if (mounted) {
        // If the fetched user has theme preferences from the API, apply them.
        if (user?.themePreferences != null) {
          final themeData = AppThemeData.fromJson(user!.themePreferences!);
          _ref.read(themeProvider.notifier).setThemeFromProfile(themeData);
        }
        state = AsyncValue.data(user);
      }
    } catch (e, st) {
      debugPrint("[UserStateNotifier] Error fetching user: $e");
      // Treat errors (like 401 Unauthorized) as "Logged Out" so the app doesn't get stuck in an error state.
      if (mounted) {
        state = const AsyncValue.data(null);
      }
    }
  }

  /// Allows manually setting the user state and optionally the auth token, e.g., after a profile update or login.
  AsyncValue<User?> setUser(User? user, {String? token}) {
    if (token != null) {
      _authToken = token;
      SharedPreferences.getInstance().then((prefs) => prefs.setString('auth_token', token));
    }
    return state = AsyncValue.data(user);
  }

  Future<void> createProfileWithPhotos(Map<String, dynamic> combinedData, List<String> paths, {bool firstIsPrimary = false}) async {
    try {
      final createUser = await _ref
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
      final updatedUser = await _ref.read(userServiceProvider).createProfileWithPhotos(apiData, [], firstIsPrimary: true);

      state = AsyncValue.data(updatedUser);
      return updatedUser;
    } catch (e, st) {
      // state = AsyncValue.error(e, st); // Don't set global error state on update failure
      rethrow; 
    }
  }

  Future<User> updateProfilePhoto(String photoPath) async {
    try {
      // Use createProfileWithPhotos to update only the photo.
      // The backend PATCH logic will handle this correctly.
      final updatedUser = await _ref.read(userServiceProvider).createProfileWithPhotos({}, [photoPath], firstIsPrimary: true);
      state = AsyncValue.data(updatedUser);
      return updatedUser;
    } catch (e, st) {
      // state = AsyncValue.error(e, st); // Don't set global error state on update failure
      rethrow;
    }
  }

  Future<void> deletePhoto(int photoId) async {
    try {
      await _ref.read(userServiceProvider).deletePhoto(photoId);

      // After successful deletion, refetch the user to get the updated list of photos
      // and ensure the primary photo is correctly identified.
      final updatedUser = await _ref.read(userServiceProvider).fetchUser();
      state = AsyncValue.data(updatedUser);

    } catch (e, st) {
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _authToken = null; // Clear token on logout
    // Setting state to null will trigger the router to redirect to the login screen.
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