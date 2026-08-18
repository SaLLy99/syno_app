import 'dart:convert';
import 'dart:io';
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
            content: json['content'] as String?,
            imageUrl: json['image_url'] as String?,
            videoUrl: json['video_url'] as String?,
            gifUrl: json['gif_url'] as String?,
            messageType: json['message_type'] as String? ?? 'text',
            isRead: json['is_read'] as bool? ?? false,
            isEdited: json['is_edited'] as bool? ?? false,
            timestamp: DateTime.parse(json['created_at'] as String),
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

  Future<void> sendMessage(String matchId, String senderId, String content, {String? imageUrl, String? videoUrl, String? gifUrl, String messageType = "text"}) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token != null && baseUrl != null) {
        final response = await _dio.post(
          '$baseUrl/api/messages',
          data: {
            'match_id': int.parse(matchId),
            'content': content,
            'image_url': imageUrl,
            'video_url': videoUrl,
            'gif_url': gifUrl,
            'message_type': messageType,
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
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      gifUrl: gifUrl,
      messageType: messageType,
      timestamp: DateTime.now(),
      isRead: false,
    );
    final List<ChatMessage> allMessages = await _getAllMessages();
    allMessages.add(message);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String messagesJson = jsonEncode(allMessages.map((ChatMessage m) => m.toJson()).toList());
    await prefs.setString(_messagesKey, messagesJson);
  }

  Future<String?> uploadMedia(File file, String token, String baseUrl) async {
    try {
      final String fileName = file.path.split('/').last;
      final String mimeType = fileName.endsWith('.mp4') || fileName.endsWith('.mov')
          ? 'video/mp4'
          : 'image/jpeg';

      final FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      final response = await _dio.post(
        '$baseUrl/api/chat/media',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['url'] as String?;
      }
    } catch (e) {
      debugPrint('[ChatRepo] Error uploading media: $e');
    }
    return null;
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token != null && baseUrl != null) {
        final response = await _dio.delete(
          '$baseUrl/api/messages/message/$messageId',
          options: _authOptions(token),
        );
        if (response.statusCode == 204) {
          debugPrint('[ChatRepo] Message deleted');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[ChatRepo] Error deleting message: $e');
    }
    return false;
  }

  Future<ChatMessage?> editMessage(String messageId, String newContent) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token != null && baseUrl != null) {
        final response = await _dio.patch(
          '$baseUrl/api/messages/message/$messageId',
          data: {'content': newContent},
          options: _authOptions(token),
        );
        if (response.statusCode == 200) {
          final json = response.data as Map<String, dynamic>;
          return ChatMessage(
            id: json['id'].toString(),
            matchId: json['match_id'].toString(),
            senderId: json['sender_id'].toString(),
            content: json['content'] as String?,
            imageUrl: json['image_url'] as String?,
            videoUrl: json['video_url'] as String?,
            gifUrl: json['gif_url'] as String?,
            messageType: json['message_type'] as String? ?? 'text',
            isRead: json['is_read'] as bool? ?? false,
            isEdited: json['is_edited'] as bool? ?? false,
            timestamp: DateTime.parse(json['created_at'] as String),
          );
        }
      }
    } catch (e) {
      debugPrint('[ChatRepo] Error editing message: $e');
    }
    return null;
  }

  Future<ChatMessage?> forwardMessage(String messageId, String targetMatchId) async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token != null && baseUrl != null) {
        final response = await _dio.post(
          '$baseUrl/api/messages/message/$messageId/forward',
          data: {'target_match_id': int.parse(targetMatchId)},
          options: _authOptions(token),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          final json = response.data as Map<String, dynamic>;
          return ChatMessage(
            id: json['id'].toString(),
            matchId: json['match_id'].toString(),
            senderId: json['sender_id'].toString(),
            content: json['content'] as String?,
            imageUrl: json['image_url'] as String?,
            videoUrl: json['video_url'] as String?,
            gifUrl: json['gif_url'] as String?,
            messageType: json['message_type'] as String? ?? 'text',
            isRead: json['is_read'] as bool? ?? false,
            isEdited: json['is_edited'] as bool? ?? false,
            timestamp: DateTime.parse(json['created_at'] as String),
          );
        }
      }
    } catch (e) {
      debugPrint('[ChatRepo] Error forwarding message: $e');
    }
    return null;
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
