import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/data/repositories/chat_repository.dart';
import 'package:syno_app/domain/entities/chat_message.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/match_provider.dart';

final Provider<ChatRepository> chatRepositoryProvider = Provider((Ref ref) => ChatRepository());

final FutureProviderFamily<List<ChatMessage>, String> chatMessagesProvider = FutureProvider.family<List<ChatMessage>, String>((Ref ref, String matchId) async {
  final ChatRepository repository = ref.watch(chatRepositoryProvider);
  return repository.getMessages(matchId);
});

final Provider<ChatActions> chatActionsProvider = Provider((Ref ref) => ChatActions(ref));

class ChatActions {
  final Ref ref;
  ChatActions(this.ref);

  Future<void> sendMessage(String matchId, String content, {String? imageUrl, String? videoUrl, String? gifUrl, String messageType = "text"}) async {
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;
    
    final ChatRepository repository = ref.read(chatRepositoryProvider);
    await repository.sendMessage(
      matchId,
      currentUser.id.toString(),
      content,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      gifUrl: gifUrl,
      messageType: messageType,
    );
    
    ref.invalidate(chatsFromBackendProvider);
    ref.refresh(chatMessagesProvider(matchId));
  }

  Future<String?> uploadAndSendMedia(String matchId, File file, {String messageType = "image"}) async {
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return null;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    final String? baseUrl = prefs.getString('backend_url');
    if (token == null || baseUrl == null) return null;

    final ChatRepository repository = ref.read(chatRepositoryProvider);
    final String? mediaUrl = await repository.uploadMedia(file, token, baseUrl);
    if (mediaUrl == null) return null;

    await repository.sendMessage(
      matchId,
      currentUser.id.toString(),
      '',
      imageUrl: messageType == 'image' ? mediaUrl : null,
      videoUrl: messageType == 'video' ? mediaUrl : null,
      gifUrl: messageType == 'gif' ? mediaUrl : null,
      messageType: messageType,
    );

    ref.invalidate(chatsFromBackendProvider);
    ref.refresh(chatMessagesProvider(matchId));
    return mediaUrl;
  }

  Future<bool> deleteMessage(String matchId, String messageId) async {
    final ChatRepository repository = ref.read(chatRepositoryProvider);
    final bool success = await repository.deleteMessage(messageId);
    if (success) {
      ref.invalidate(chatMessagesProvider(matchId));
      ref.invalidate(chatsFromBackendProvider);
    }
    return success;
  }

  Future<bool> editMessage(String matchId, String messageId, String newContent) async {
    final ChatRepository repository = ref.read(chatRepositoryProvider);
    final ChatMessage? edited = await repository.editMessage(messageId, newContent);
    if (edited != null) {
      ref.invalidate(chatMessagesProvider(matchId));
      return true;
    }
    return false;
  }

  Future<bool> forwardMessage(String messageId, String targetMatchId) async {
    final ChatRepository repository = ref.read(chatRepositoryProvider);
    final ChatMessage? forwarded = await repository.forwardMessage(messageId, targetMatchId);
    if (forwarded != null) {
      ref.invalidate(chatMessagesProvider(targetMatchId));
      return true;
    }
    return false;
  }

  Future<void> markAsRead(String matchId) async {
   final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;
    
    final ChatRepository repository = ref.read(chatRepositoryProvider);
    await repository.markAsRead(matchId, currentUser.id.toString());
    
    ref.invalidate(chatMessagesProvider(matchId));
  }
}
