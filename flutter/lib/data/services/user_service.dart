import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  final String backendUrl;
  final dio.Dio _dio = dio.Dio(); 
  final VoidCallback? onUnauthorized;

  UserService(this.backendUrl, {this.onUnauthorized}) {
    _dio.interceptors.add(
      dio.InterceptorsWrapper(
        onError: (dio.DioException e, dio.ErrorInterceptorHandler handler) async {
          final int? statusCode = e.response?.statusCode;
          final dynamic data = e.response?.data;
          final String? detail = data is Map<String, dynamic> ? data['detail'] as String? : null;

          if (statusCode == 401 || statusCode == 403) {
            if (detail == 'account.deactivated' || detail == 'account.deactivated_token_invalid') {
              debugPrint("[UserService Interceptor] Deactivated account detected ($statusCode). Saving recovery flag and logging out.");
              final SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setBool('pending_reactivation', true);
              await prefs.remove('auth_token');
              onUnauthorized?.call();
              return handler.reject(e);
            }
            if (statusCode == 401) {
              debugPrint("[UserService Interceptor] 401 Unauthorized detected. Triggering logout.");
              onUnauthorized?.call();
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  String _normalizeToken(String? token) {
    if (token == null) return '';
    return token.trim().replaceAll('"', '');
  }


  Future<User?> fetchCurrentUser() async {
    debugPrint("[UserService] Attempting to fetch current user...");
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenRaw = prefs.getString('auth_token');
    final String token = _normalizeToken(tokenRaw);

    debugPrint('[UserService] fetchCurrentUser using token: ${token.isEmpty ? '<empty>' : '${token.substring(0, token.length > 8 ? 8 : token.length)}...'}');

    if (token.isEmpty) {
      debugPrint("[UserService] No auth token found. Returning null.");
      return null;
    }

    final String url = '$backendUrl/api/users/me/';
    try {
      final dio.Response response = await _dio.get(
        url,
        options: dio.Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'}),
      );
      debugPrint("[UserService] Current user fetched successfully.");
  

      return User.fromJson(response.data);
    } on dio.DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // This is an expected case during registration where the user exists
        // but the profile has not been created yet. Return null.
        debugPrint("[UserService] User found, but profile does not exist (404). Returning null.");
        return null;
      }
      debugPrint("[UserService] DioException: Type=${e.type}, Status=${e.response?.statusCode}, Data=${e.response?.data}, Message=${e.message}");
      throw Exception('Failed to fetch user: Status=${e.response?.statusCode}, Message=${e.message}');
    }
  }


  Future<User> createProfileWithPhotos(Map<String, dynamic> profileData, List<String> photoPaths, {bool firstIsPrimary = false}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenRaw = prefs.getString('auth_token');
    final String token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found. User must be logged in.');
    }

    final Map<String, dynamic> formDataMap = <String, dynamic>{};
    
    // Create a copy and explicitly remove 'uploaded_photos' to prevent it from being sent as a text field
    final Map<String, dynamic> data = Map<String, dynamic>.from(profileData);
    data.remove('uploaded_photos');

    // Explicitly remove keys that are handled by other endpoints or are deprecated.
    // This separates profile data saving from other concerns like themes or old field structures.
    final List<String> themeKeys = <String>['theme_id', 'background_color', 'accent_color', 'layout', 'theme_preferences',
                       'intention', 'core_values' // Deprecated fields
                      ];
    for (final String key in themeKeys) {
      data.remove(key);
    }

    data.forEach((String key, value) {
      if (value is DateTime) {
        // Convert DateTime objects to ISO 8601 string format
        formDataMap[key] = value.toIso8601String();
      } else if (value is List) {
        // JSON-encode lists to match backend expectation for multipart forms
        formDataMap[key] = jsonEncode(value);
      } else if (value != null) {
        // For other non-null values, add them directly. Dio will handle their conversion for multipart.
        formDataMap[key] = value;
      }
    });

    // Add photos to the form data.
    // The backend expects 'primary_photo' and 'additional_photos'.
    if (photoPaths.isNotEmpty) {
      if (firstIsPrimary) {
        // 1. Handle Primary Photo
        formDataMap['primary_photo'] = await dio.MultipartFile.fromFile(
          photoPaths[0], 
          filename: photoPaths[0].split('/').last
        );
      }

      // 2. Handle Additional Photos
      final int startIndex = firstIsPrimary ? 1 : 0;
      if (photoPaths.length > startIndex) {
        final List<dio.MultipartFile> additionalFiles = <dio.MultipartFile>[];
        for (int i = startIndex; i < photoPaths.length; i++) {
          additionalFiles.add(await dio.MultipartFile.fromFile(photoPaths[i], filename: photoPaths[i].split('/').last));
        }
        formDataMap['uploaded_photos'] = additionalFiles;
      }
    }
    final dio.FormData formData = dio.FormData.fromMap(formDataMap);

    final String url = '$backendUrl/api/users/me';
    try {
      debugPrint('[UserService] createProfileWithPhotos sending to $url with token present');
      final dio.Response response = await _dio.patch(
        url,
        data: formData,
        options: dio.Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'}),
      );

      return User.fromJson(response.data);
    } on dio.DioException catch (e) {
      throw Exception('Failed to update profile with photo: ${e.response?.data ?? e.message}');
    }
  }

  Future<User?> fetchUser() async {
    return await fetchCurrentUser();
  }

  Future<void> deletePhoto(int photoId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenRaw = prefs.getString('auth_token');
    final String token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final String url = '$backendUrl/api/photos/$photoId';
    try {
      final dio.Response response = await _dio.delete(
        url,
        options: dio.Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'}),
      );

      // A 204 No Content status code indicates success.
      if (response.statusCode != 204) {
        throw Exception('Failed to delete photo. Status code: ${response.statusCode}');
      }
    } on dio.DioException catch (e) {
      throw Exception('Failed to delete photo: ${e.response?.data ?? e.message}');
    }
  }

  Future<User> updateTheme(Map<String, dynamic> themeData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenRaw = prefs.getString('auth_token');
    final String token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    // Construct payload ensuring all values are strings as expected by the backend
    final Map<String, dynamic> payload = <String, dynamic>{};
    final List<String> allowedKeys = <String>['theme_id', 'background_color', 'accent_color', 'layout'];

    for (final String key in allowedKeys) {
      if (themeData.containsKey(key) && themeData[key] != null) {
        payload[key] = themeData[key].toString();
      }
    }

    final String url = '$backendUrl/api/users/me/settings';
    try {
      final dio.Response response = await _dio.put(
        url,
        data: payload,
        options: dio.Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'}),
      );

      return User.fromJson(response.data);
    } on dio.DioException catch (e) {
      debugPrint("[UserService] Update theme failed: ${e.response?.statusCode} - ${e.response?.data}");
      throw Exception('Failed to update theme: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> updateCoreValues(int profileId, List<int> coreValueIds) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenRaw = prefs.getString('auth_token');
    final String token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final String url = '$backendUrl/api/post/core-values';
    final Map<String, Object> payload = <String, Object>{
      'profile_id': profileId,
      'core_value_id': coreValueIds,
    };

    try {
      final dio.Response response = await _dio.post(
        url,
        data: payload,
        options: dio.Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update core values. Status code: ${response.statusCode}');
      }
    } on dio.DioException catch (e) {
      throw Exception('Failed to update core values: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> updateIntentions(int profileId, List<int> intentionIds) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenRaw = prefs.getString('auth_token');
    final String token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final String url = '$backendUrl/api/post/intentions';
    final Map<String, Object> payload = <String, Object>{
      'profile_id': profileId,
      'intention_id': intentionIds,
    };

    try {
      final dio.Response response = await _dio.post(
        url,
        data: payload,
        options: dio.Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update intentions. Status code: ${response.statusCode}');
      }
    } on dio.DioException catch (e) {
      throw Exception('Failed to update intentions: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> unblockUser(int userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenRaw = prefs.getString('auth_token');
    final String token = _normalizeToken(tokenRaw);

    if (token.isEmpty) throw Exception('Authentication token not found.');

    final String url = '$backendUrl/api/users/$userId/unblock';
    try {
      final dio.Response response = await _dio.delete(
        url,
        options: dio.Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to unblock user. Status code: ${response.statusCode}');
      }
    } on dio.DioException catch (e) {
      throw Exception('Failed to unblock user: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> deleteAccount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenRaw = prefs.getString('auth_token');
    final String token = _normalizeToken(tokenRaw);

    if (token.isEmpty) throw Exception('Authentication token not found.');

    final String url = '$backendUrl/api/users/me';
    try {
      final dio.Response response = await _dio.delete(
        url,
        options: dio.Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete account. Status code: ${response.statusCode}');
      }
    } on dio.DioException catch (e) {
      throw Exception('Failed to delete account: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> requestReactivation({String? email, String? phoneNumber}) async {
    final String url = '$backendUrl/api/auth/request-reactivation';
    try {
      final Map<String, String> data = <String, String>{};
      if (email != null) data['email'] = email;
      if (phoneNumber != null) data['phone_number'] = phoneNumber;
      await _dio.post(url, data: data);
    } on dio.DioException catch (e) {
      throw Exception('Failed to request reactivation: ${e.response?.data ?? e.message}');
    }
  }

  Future<String> verifyReactivation({String? email, String? phoneNumber, required String code}) async {
    final String url = '$backendUrl/api/auth/verify-reactivation';
    try {
      final Map<String, String> data = <String, String>{'code': code};
      if (email != null) data['email'] = email;
      if (phoneNumber != null) data['phone_number'] = phoneNumber;
      final dio.Response response = await _dio.post(url, data: data);
      final String accessToken = response.data['access_token'] as String;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', accessToken);
      return accessToken;
    } on dio.DioException catch (e) {
      throw Exception('Failed to verify reactivation: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> blockUserByName(String name) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenRaw = prefs.getString('auth_token');
    final String token = _normalizeToken(tokenRaw);

    if (token.isEmpty) throw Exception('Authentication token not found.');

    final String url = '$backendUrl/api/users/block-by-name';
    try {
      final dio.Response response = await _dio.post(
        url,
        data: <String, String>{'name': name},
        options: dio.Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to block user. Status code: ${response.statusCode}');
      }
    } on dio.DioException catch (e) {
      throw Exception('Failed to block user: ${e.response?.data ?? e.message}');
    }
  }

  Future<List<User>> fetchBlockedUsers() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenRaw = prefs.getString('auth_token');
    final String token = _normalizeToken(tokenRaw);

    if (token.isEmpty) throw Exception('Authentication token not found.');

    final String url = '$backendUrl/api/users/me/blocked';
    try {
      final dio.Response response = await _dio.get(
        url,
        options: dio.Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'}),
      );

      if (response.data is List) {
        return (response.data as List).map((u) => User.fromJson(u)).toList();
      }
      return <User>[];
    } on dio.DioException catch (e) {
      debugPrint("[UserService] Fetch blocked users failed: ${e.response?.statusCode}");
      throw Exception('Failed to fetch blocked users: ${e.response?.data ?? e.message}');
    }
  }

  /// Searches for a user profile by name.
  /// Returns a [User] if found, or null if the backend returns a 404.
  /// Throws an exception for other errors.
  Future<User?> searchUserByName(String name) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenRaw = prefs.getString('auth_token');
    final String token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final String url = '$backendUrl/api/users/profile-search/$name';
    try {
      final dio.Response response = await _dio.get(
        url,
        options: dio.Options(headers: <String, dynamic>{'Authorization': 'Bearer $token'}),
      );

      return User.fromJson(response.data);
    } on dio.DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // User not found, return null as per requirement
      }
      debugPrint("[UserService] Search user by name failed: ${e.response?.statusCode} - ${e.response?.data}");
      throw Exception('Failed to search for user: ${e.response?.data ?? e.message}');
    }
  }
}