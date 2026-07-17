import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:syno_app/data/repositories/chat_repository.dart';
import 'package:syno_app/domain/entities/chat_message.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';

final Provider<ChatRepository> chatRepositoryProvider = Provider((Ref ref) => ChatRepository());

final FutureProviderFamily<List<ChatMessage>, String> chatMessagesProvider = FutureProvider.family<List<ChatMessage>, String>((Ref ref, String matchId) async {
  final ChatRepository repository = ref.watch(chatRepositoryProvider);
  return repository.getMessages(matchId);
});

final Provider<ChatActions> chatActionsProvider = Provider((Ref ref) => ChatActions(ref));

class ChatActions {
  final Ref ref;
  ChatActions(this.ref);

  Future<void> sendMessage(String matchId, String content) async {
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;
    
    final ChatRepository repository = ref.read(chatRepositoryProvider);
    await repository.sendMessage(matchId, currentUser.id.toString(), content);
    
    ref.invalidate(chatMessagesProvider(matchId));
  }

  Future<void> markAsRead(String matchId) async {
   final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;
    
    final ChatRepository repository = ref.read(chatRepositoryProvider);
    await repository.markAsRead(matchId, currentUser.id.toString());
    
    ref.invalidate(chatMessagesProvider(matchId));
  }
}
