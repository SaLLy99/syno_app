import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockRepository {
  // Key namespace per current user: 'blocked_users_<userId>' stores a JSON list of userIds
  String _keyFor(String userId) => 'blocked_users_$userId';

  Future<Set<String>> getBlockedUserIds(String currentUserId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_keyFor(currentUserId));
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
      // Auto-sanitize corrupted entries
      debugPrint('Blocked list corrupted for ???. Resetting.');
      await prefs.remove(_keyFor(currentUserId));
      return <String>{};
    } on FormatException catch (e) {
      // This specifically catches JSON parsing errors.
      debugPrint('Corrupted JSON in blocked users list for ???. Resetting. Error: $e');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor(currentUserId));
      return <String>{};
    }
  }

  Future<bool> isBlocked({required String currentUserId, required String targetUserId}) async {
    final Set<String> set = await getBlockedUserIds(currentUserId);
    return set.contains(targetUserId);
  }

  Future<void> blockUser({required String currentUserId, required String targetUserId}) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Set<String> set = await getBlockedUserIds(currentUserId);
      set.add(targetUserId);
      await prefs.setString(_keyFor(currentUserId), jsonEncode(set.toList()));
    } catch (e) {
      debugPrint('Error blocking ??? for ???: $e');
    }
  }

  Future<void> unblockUser({required String currentUserId, required String targetUserId}) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Set<String> set = await getBlockedUserIds(currentUserId);
      set.remove(targetUserId);
      await prefs.setString(_keyFor(currentUserId), jsonEncode(set.toList()));
    } catch (e) {
      debugPrint('Error unblocking ??? for ???: $e');
    }
  }
}
