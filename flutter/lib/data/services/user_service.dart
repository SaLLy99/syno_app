import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:syno_app/domain/entities/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';

class UserService {
  final String backendUrl;
  final dio.Dio _dio = dio.Dio(); 
  final VoidCallback? onUnauthorized;

  UserService(this.backendUrl, {this.onUnauthorized}) {
    _dio.interceptors.add(
      dio.InterceptorsWrapper(
        onError: (e, handler) {
          // If the server returns a 401 Unauthorized, it means the token
          // is expired or invalid. Trigger the onUnauthorized callback to
          // initiate a global logout.
          if (e.response?.statusCode == 401) {
            debugPrint("[UserService Interceptor] 401 Unauthorized detected. Triggering logout.");
            onUnauthorized?.call();
          }
          return handler.next(e); // Propagate the error.
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
    final prefs = await SharedPreferences.getInstance();
    final tokenRaw = prefs.getString('auth_token');
    final token = _normalizeToken(tokenRaw);

    debugPrint('[UserService] fetchCurrentUser using token: ${token.isEmpty ? '<empty>' : '${token.substring(0, token.length > 8 ? 8 : token.length)}...'}');

    if (token.isEmpty) {
      debugPrint("[UserService] No auth token found. Returning null.");
      return null;
    }

    final url = '$backendUrl/api/users/me/';
    try {
      final response = await _dio.get(
        url,
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
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
    final prefs = await SharedPreferences.getInstance();
    final tokenRaw = prefs.getString('auth_token');
    final token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found. User must be logged in.');
    }

    final Map<String, dynamic> formDataMap = {};
    
    // Create a copy and explicitly remove 'uploaded_photos' to prevent it from being sent as a text field
    final data = Map<String, dynamic>.from(profileData);
    data.remove('uploaded_photos');

    // Explicitly remove keys that are handled by other endpoints or are deprecated.
    // This separates profile data saving from other concerns like themes or old field structures.
    final themeKeys = ['theme_id', 'background_color', 'accent_color', 'layout', 'theme_preferences',
                       'intention', 'core_values' // Deprecated fields
                      ];
    for (final key in themeKeys) {
      data.remove(key);
    }

    data.forEach((key, value) {
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
      final startIndex = firstIsPrimary ? 1 : 0;
      if (photoPaths.length > startIndex) {
        final additionalFiles = <dio.MultipartFile>[];
        for (int i = startIndex; i < photoPaths.length; i++) {
          additionalFiles.add(await dio.MultipartFile.fromFile(photoPaths[i], filename: photoPaths[i].split('/').last));
        }
        formDataMap['uploaded_photos'] = additionalFiles;
      }
    }
    final formData = dio.FormData.fromMap(formDataMap);

    final url = '$backendUrl/api/users/me';
    try {
      debugPrint('[UserService] createProfileWithPhotos sending to $url with token present');
      final response = await _dio.patch(
        url,
        data: formData,
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
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
    final prefs = await SharedPreferences.getInstance();
    final tokenRaw = prefs.getString('auth_token');
    final token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final url = '$backendUrl/api/photos/$photoId';
    try {
      final response = await _dio.delete(
        url,
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
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
    final prefs = await SharedPreferences.getInstance();
    final tokenRaw = prefs.getString('auth_token');
    final token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    // Construct payload ensuring all values are strings as expected by the backend
    final Map<String, dynamic> payload = {};
    final allowedKeys = ['theme_id', 'background_color', 'accent_color', 'layout'];

    for (final key in allowedKeys) {
      if (themeData.containsKey(key) && themeData[key] != null) {
        payload[key] = themeData[key].toString();
      }
    }

    final url = '$backendUrl/api/users/me/settings';
    try {
      final response = await _dio.put(
        url,
        data: payload,
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return User.fromJson(response.data);
    } on dio.DioException catch (e) {
      debugPrint("[UserService] Update theme failed: ${e.response?.statusCode} - ${e.response?.data}");
      throw Exception('Failed to update theme: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> updateCoreValues(int profileId, List<int> coreValueIds) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenRaw = prefs.getString('auth_token');
    final token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final url = '$backendUrl/api/post/core-values';
    final payload = {
      'profile_id': profileId,
      'core_value_id': coreValueIds,
    };

    try {
      final response = await _dio.post(
        url,
        data: payload,
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update core values. Status code: ${response.statusCode}');
      }
    } on dio.DioException catch (e) {
      throw Exception('Failed to update core values: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> updateIntentions(int profileId, List<int> intentionIds) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenRaw = prefs.getString('auth_token');
    final token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final url = '$backendUrl/api/post/intentions';
    final payload = {
      'profile_id': profileId,
      'intention_id': intentionIds,
    };

    try {
      final response = await _dio.post(
        url,
        data: payload,
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update intentions. Status code: ${response.statusCode}');
      }
    } on dio.DioException catch (e) {
      throw Exception('Failed to update intentions: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> unblockUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenRaw = prefs.getString('auth_token');
    final token = _normalizeToken(tokenRaw);

    if (token.isEmpty) throw Exception('Authentication token not found.');

    final url = '$backendUrl/api/users/$userId/unblock';
    try {
      final response = await _dio.delete(
        url,
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to unblock user. Status code: ${response.statusCode}');
      }
    } on dio.DioException catch (e) {
      throw Exception('Failed to unblock user: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenRaw = prefs.getString('auth_token');
    final token = _normalizeToken(tokenRaw);

    if (token.isEmpty) throw Exception('Authentication token not found.');

    final url = '$backendUrl/api/users/me';
    try {
      final response = await _dio.delete(
        url,
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete account. Status code: ${response.statusCode}');
      }
    } on dio.DioException catch (e) {
      throw Exception('Failed to delete account: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> blockUserByName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenRaw = prefs.getString('auth_token');
    final token = _normalizeToken(tokenRaw);

    if (token.isEmpty) throw Exception('Authentication token not found.');

    final url = '$backendUrl/api/users/block-by-name';
    try {
      final response = await _dio.post(
        url,
        data: {'name': name},
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to block user. Status code: ${response.statusCode}');
      }
    } on dio.DioException catch (e) {
      throw Exception('Failed to block user: ${e.response?.data ?? e.message}');
    }
  }

  Future<List<User>> fetchBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenRaw = prefs.getString('auth_token');
    final token = _normalizeToken(tokenRaw);

    if (token.isEmpty) throw Exception('Authentication token not found.');

    final url = '$backendUrl/api/users/me/blocked';
    try {
      final response = await _dio.get(
        url,
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data is List) {
        return (response.data as List).map((u) => User.fromJson(u)).toList();
      }
      return [];
    } on dio.DioException catch (e) {
      debugPrint("[UserService] Fetch blocked users failed: ${e.response?.statusCode}");
      throw Exception('Failed to fetch blocked users: ${e.response?.data ?? e.message}');
    }
  }

  /// Searches for a user profile by name.
  /// Returns a [User] if found, or null if the backend returns a 404.
  /// Throws an exception for other errors.
  Future<User?> searchUserByName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenRaw = prefs.getString('auth_token');
    final token = _normalizeToken(tokenRaw);

    if (token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final url = '$backendUrl/api/users/profile-search/$name';
    try {
      final response = await _dio.get(
        url,
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
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