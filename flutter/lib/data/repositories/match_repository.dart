import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/domain/entities/match.dart';

class MatchRepository {
  static const String _matchesKey = 'matches';
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

  Future<String> _getMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_mode') ?? 'dating';
  }

  Future<int?> saveMatchToBackend(Match match) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      final String mode = await _getMode();
      if (token == null || baseUrl == null) return null;

      final response = await _dio.post(
        '$baseUrl/api/matches',
        data: {
          'matched_user_id': int.parse(match.matchedUserId),
          'status': match.status.name,
          'compatibility_score': match.averageScore.round(),
          'mode': mode,
        },
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final int? backendId = response.data['id'] as int?;
        debugPrint('[MatchRepo] Saved match to backend: $backendId');
        return backendId;
      }
    } catch (e) {
      debugPrint('[MatchRepo] Error saving match to backend: $e');
    }
    return null;
  }

  Future<void> updateMatchStatusOnBackend(int backendMatchId, String status) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token == null || baseUrl == null) return;

      await _dio.patch(
        '$baseUrl/api/matches/$backendMatchId',
        data: {'status': status},
        options: _authOptions(token),
      );
      debugPrint('[MatchRepo] Updated match $backendMatchId to $status on backend');
    } catch (e) {
      debugPrint('[MatchRepo] Error updating match on backend: $e');
    }
  }

  Future<List<Match>> getMatches(String userId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? matchesJson = prefs.getString(_matchesKey);
      if (matchesJson == null || matchesJson.isEmpty) return <Match>[];
      final List<dynamic> matchesList = jsonDecode(matchesJson);
      final List<Match> allMatches = matchesList.map((json) => Match.fromJson(json as Map<String, dynamic>)).toList();
      return allMatches.where((Match m) => m.userId == userId).toList();
    } catch (e) {
      debugPrint('[MatchRepo] Error loading matches: $e');
      return <Match>[];
    }
  }

  Future<void> saveMatches(List<Match> matches) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Match> existingMatches = await _getAllMatches();
      final List<Match> otherMatches = existingMatches.where((Match m) => !matches.any((Match nm) => nm.id == m.id)).toList();
      final List<Match> allMatches = <Match>[...otherMatches, ...matches];
      final String matchesJson = jsonEncode(allMatches.map((Match m) => m.toJson()).toList());
      await prefs.setString(_matchesKey, matchesJson);
    } catch (e) {
      debugPrint('[MatchRepo] Error saving matches: $e');
    }
  }

  Future<List<Match>> _getAllMatches() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? matchesJson = prefs.getString(_matchesKey);
      if (matchesJson == null || matchesJson.isEmpty) return <Match>[];
      final List<dynamic> matchesList = jsonDecode(matchesJson);
      return matchesList.map((json) => Match.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return <Match>[];
    }
  }

  Future<void> updateMatchStatus(String matchId, MatchStatus status) async {
    try {
      final List<Match> allMatches = await _getAllMatches();
      final int index = allMatches.indexWhere((Match m) => m.id == matchId);
      if (index != -1) {
        allMatches[index] = allMatches[index].copyWith(status: status);
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String matchesJson = jsonEncode(allMatches.map((Match m) => m.toJson()).toList());
        await prefs.setString(_matchesKey, matchesJson);

        final Match updated = allMatches[index];
        if (updated.backendMatchId != null) {
          await updateMatchStatusOnBackend(updated.backendMatchId!, status.name);
        } else {
          await saveMatchToBackend(updated);
        }
      }
    } catch (e) {
      debugPrint('[MatchRepo] Error updating match status: $e');
    }
  }

  Future<List<Match>> getAcceptedMatches(String userId) async {
    final List<Match> matches = await getMatches(userId);
    return matches.where((Match m) => m.status == MatchStatus.accepted).toList();
  }

  Future<Map<String, dynamic>?> acceptIncomingLike(int matchId) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token == null || baseUrl == null) return null;

      final response = await _dio.post(
        '$baseUrl/api/likes/$matchId/accept',
        options: _authOptions(token),
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[MatchRepo] Error accepting like: $e');
    }
    return null;
  }

  Future<bool> declineIncomingLike(int matchId) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token == null || baseUrl == null) return false;

      final response = await _dio.post(
        '$baseUrl/api/likes/$matchId/decline',
        options: _authOptions(token),
      );
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('[MatchRepo] Error declining like: $e');
    }
    return false;
  }

  Future<bool> checkMutualMatch(String otherUserId) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token == null || baseUrl == null) return false;

      final response = await _dio.get(
        '$baseUrl/api/matches/mutual/$otherUserId',
        options: _authOptions(token),
      );
      if (response.statusCode == 200) {
        return response.data['is_mutual'] as bool? ?? false;
      }
    } catch (e) {
      debugPrint('[MatchRepo] Error checking mutual match: $e');
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getReceivedLikes() async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      final String mode = await _getMode();
      if (token == null || baseUrl == null) return <Map<String, dynamic>>[];

      final response = await _dio.get(
        '$baseUrl/api/likes/received',
        queryParameters: {'mode': mode},
        options: _authOptions(token),
      );
      if (response.statusCode == 200) {
        return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[MatchRepo] Error fetching received likes: $e');
    }
    return <Map<String, dynamic>>[];
  }
}
