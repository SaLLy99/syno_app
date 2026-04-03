import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/domain/entities/chat_message.dart';
import 'package:uuid/uuid.dart';

class ChatRepository {
  static const String _messagesKey = 'chat_messages';
  final Uuid _uuid = const Uuid();

  Future<List<ChatMessage>> getMessages(String matchId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? messagesJson = prefs.getString(_messagesKey);
      
      if (messagesJson == null || messagesJson.isEmpty) {
        return <ChatMessage>[];
      }
      
      final List<dynamic> messagesList = jsonDecode(messagesJson) as List<dynamic>;
      final List<ChatMessage> allMessages = messagesList
          .map<ChatMessage>((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
      
      final List<ChatMessage> filtered = allMessages.where((ChatMessage m) => m.matchId == matchId).toList();
      filtered.sort((ChatMessage a, ChatMessage b) => a.timestamp.compareTo(b.timestamp));
      return filtered;
    } catch (e) {
      debugPrint('Error loading messages: $e');
      return <ChatMessage>[];
    }
  }

  Future<void> sendMessage(String matchId, String senderId, String content) async {
    try {
      final ChatMessage message = ChatMessage(
        id: _uuid.v4(),
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
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> markAsRead(String matchId, String userId) async {
    try {
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
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<List<ChatMessage>> _getAllMessages() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? messagesJson = prefs.getString(_messagesKey);
      
      if (messagesJson == null || messagesJson.isEmpty) {
        return <ChatMessage>[];
      }
      
      final List<dynamic> messagesList = jsonDecode(messagesJson) as List<dynamic>;
      return messagesList
          .map<ChatMessage>((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading all messages: $e');
      return <ChatMessage>[];
    }
  }
}