import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/domain/entities/match.dart';

class MatchRepository {
  static const String _matchesKey = 'matches';

  Future<List<Match>> getMatches(String userId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? matchesJson = prefs.getString(_matchesKey);
      
      if (matchesJson == null || matchesJson.isEmpty) {
        return <Match>[];
      }
      
      final List<dynamic> matchesList = jsonDecode(matchesJson);
      final List<Match> allMatches = matchesList.map((json) => Match.fromJson(json as Map<String, dynamic>)).toList();
      
      return allMatches.where((Match m) => m.userId == userId).toList();
    } catch (e) {
      debugPrint('Error loading matches: $e');
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
      debugPrint('Error saving matches: $e');
    }
  }

  Future<List<Match>> _getAllMatches() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? matchesJson = prefs.getString(_matchesKey);
      
      if (matchesJson == null || matchesJson.isEmpty) {
        return <Match>[];
      }
      
      final List<dynamic> matchesList = jsonDecode(matchesJson);
      return matchesList.map((json) => Match.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading all matches: $e');
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
      }
    } catch (e) {
      debugPrint('Error updating match status: $e');
    }
  }

  Future<List<Match>> getAcceptedMatches(String userId) async {
    final List<Match> matches = await getMatches(userId);
    return matches.where((Match m) => m.status == MatchStatus.accepted).toList();
  }
}
