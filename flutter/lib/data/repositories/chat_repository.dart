import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/domain/entities/chat_message.dart';

class ChatRepository {
  static const String _messagesKey = 'chat_messages';
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

  Future<List<ChatMessage>> getMessages(String matchId) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token != null && baseUrl != null) {
        final response = await _dio.get(
          '$baseUrl/api/messages/$matchId',
          options: _authOptions(token),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data as List<dynamic>;
          final List<ChatMessage> messages = data.map((json) => ChatMessage(
            id: json['id'].toString(),
            matchId: json['match_id'].toString(),
            senderId: json['sender_id'].toString(),
            content: json['content'] as String,
            timestamp: DateTime.parse(json['created_at'] as String),
            isRead: json['is_read'] as bool? ?? false,
          )).toList();
          await _saveMessagesLocally(matchId, messages);
          return messages;
        }
      }
    } catch (e) {
      debugPrint('[ChatRepo] Error fetching messages from backend: $e');
    }
    return _getMessagesLocal(matchId);
  }

  Future<void> sendMessage(String matchId, String senderId, String content) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token != null && baseUrl != null) {
        final response = await _dio.post(
          '$baseUrl/api/messages',
          data: {
            'match_id': int.parse(matchId),
            'content': content,
          },
          options: _authOptions(token),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('[ChatRepo] Message sent to backend');
          return;
        }
      }
    } catch (e) {
      debugPrint('[ChatRepo] Error sending message to backend: $e');
    }

    final ChatMessage message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      matchId: matchId,
      senderId: senderId,
      content: content,
      timestamp: DateTime.now(),
      isRead: false,
    );
    final List<ChatMessage> allMessages = await _getAllMessages();
    allMessages.add(message);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String messagesJson = jsonEncode(allMessages.map((ChatMessage m) => m.toJson()).toList());
    await prefs.setString(_messagesKey, messagesJson);
  }

  Future<void> markAsRead(String matchId, String userId) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token != null && baseUrl != null) {
        await _dio.patch(
          '$baseUrl/api/messages/$matchId/read',
          options: _authOptions(token),
        );
        return;
      }
    } catch (e) {
      debugPrint('[ChatRepo] Error marking read on backend: $e');
    }

    final List<ChatMessage> allMessages = await _getAllMessages();
    for (int i = 0; i < allMessages.length; i++) {
      final ChatMessage msg = allMessages[i];
      if (msg.matchId == matchId && msg.senderId != userId && !msg.isRead) {
        allMessages[i] = msg.copyWith(isRead: true);
      }
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String messagesJson = jsonEncode(allMessages.map((ChatMessage m) => m.toJson()).toList());
    await prefs.setString(_messagesKey, messagesJson);
  }

  Future<void> _saveMessagesLocally(String matchId, List<ChatMessage> messages) async {
    try {
      final List<ChatMessage> allMessages = await _getAllMessages();
      allMessages.removeWhere((ChatMessage m) => m.matchId == matchId);
      allMessages.addAll(messages);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String messagesJson = jsonEncode(allMessages.map((ChatMessage m) => m.toJson()).toList());
      await prefs.setString(_messagesKey, messagesJson);
    } catch (e) {
      debugPrint('[ChatRepo] Error saving messages locally: $e');
    }
  }

  Future<List<ChatMessage>> _getMessagesLocal(String matchId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? messagesJson = prefs.getString(_messagesKey);
      if (messagesJson == null || messagesJson.isEmpty) return <ChatMessage>[];
      final List<dynamic> messagesList = jsonDecode(messagesJson) as List<dynamic>;
      final List<ChatMessage> allMessages = messagesList
          .map<ChatMessage>((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
      final List<ChatMessage> filtered = allMessages.where((ChatMessage m) => m.matchId == matchId).toList();
      filtered.sort((ChatMessage a, ChatMessage b) => a.timestamp.compareTo(b.timestamp));
      return filtered;
    } catch (e) {
      return <ChatMessage>[];
    }
  }

  Future<List<ChatMessage>> _getAllMessages() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? messagesJson = prefs.getString(_messagesKey);
      if (messagesJson == null || messagesJson.isEmpty) return <ChatMessage>[];
      final List<dynamic> messagesList = jsonDecode(messagesJson) as List<dynamic>;
      return messagesList
          .map<ChatMessage>((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return <ChatMessage>[];
    }
  }
}
