import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockRepository {
  final Dio _dio = Dio();

  Future<String?> _getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<String?> _getBackendUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('backend_url');
  }

  Options _authOptions(String token) => Options(
    headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
  );

  Future<void> blockUser({required String currentUserId, required String targetUserId}) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token != null && baseUrl != null) {
        final response = await _dio.post(
          '$baseUrl/api/users/$targetUserId/block',
          options: _authOptions(token),
        );
        if (response.statusCode == 200 || response.statusCode == 204) {
          debugPrint('[BlockRepo] Blocked user $targetUserId via backend');
          return;
        }
      }
    } catch (e) {
      debugPrint('[BlockRepo] Error blocking user via backend: $e');
    }
  }

  Future<void> unblockUser({required String currentUserId, required String targetUserId}) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token != null && baseUrl != null) {
        final response = await _dio.delete(
          '$baseUrl/api/users/$targetUserId/unblock',
          options: _authOptions(token),
        );
        if (response.statusCode == 200 || response.statusCode == 204) {
          debugPrint('[BlockRepo] Unblocked user $targetUserId via backend');
          return;
        }
      }
    } catch (e) {
      debugPrint('[BlockRepo] Error unblocking user via backend: $e');
    }
  }
}
