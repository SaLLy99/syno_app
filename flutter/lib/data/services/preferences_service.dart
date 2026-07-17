import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/domain/entities/user_preferences.dart';

class PreferencesService {
  static const String _cacheKey = 'user_discover_preferences';

  Future<DiscoverPreferences> getPreferences(String? authToken, String backendUrl) async {
    if (authToken == null || authToken.isEmpty) {
      return _loadFromCache();
    }

    try {
      final response = await Dio().get(
        '$backendUrl/api/users/me/preferences',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final prefs = DiscoverPreferences.fromJson(data);
        await _saveToCache(prefs);
        return prefs;
      }
    } catch (e) {
      debugPrint('Error fetching preferences from API: $e');
    }

    return _loadFromCache();
  }

  Future<DiscoverPreferences> updatePreferences(
    DiscoverPreferences prefs,
    String? authToken,
    String backendUrl,
  ) async {
    await _saveToCache(prefs);

    if (authToken == null || authToken.isEmpty) {
      return prefs;
    }

    try {
      final response = await Dio().put(
        '$backendUrl/api/users/me/preferences',
        data: prefs.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return DiscoverPreferences.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error updating preferences via API: $e');
    }

    return prefs;
  }

  Future<DiscoverPreferences> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_cacheKey);
      if (jsonString != null) {
        return DiscoverPreferences.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error loading preferences from cache: $e');
    }
    return const DiscoverPreferences();
  }

  Future<void> _saveToCache(DiscoverPreferences prefs) async {
    try {
      final prefsStorage = await SharedPreferences.getInstance();
      await prefsStorage.setString(_cacheKey, jsonEncode(prefs.toJson()));
    } catch (e) {
      debugPrint('Error saving preferences to cache: $e');
    }
  }
}
