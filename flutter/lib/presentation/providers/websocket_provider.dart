import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:syno_app/data/services/websocket_service.dart';

final Provider<WebSocketService> webSocketServiceProvider =
    Provider<WebSocketService>((Ref ref) {
  final WebSocketService service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

final StreamProvider<WebSocketStatus> webSocketStatusProvider =
    StreamProvider<WebSocketStatus>((Ref ref) {
  final WebSocketService service = ref.watch(webSocketServiceProvider);
  return service.status;
});

final StreamProvider<Set<int>> onlineUsersProvider =
    StreamProvider<Set<int>>((Ref ref) {
  final WebSocketService service = ref.watch(webSocketServiceProvider);
  return service.onlineUsers;
});

final StreamProvider<WebSocketMessage> webSocketMessagesProvider =
    StreamProvider<WebSocketMessage>((Ref ref) {
  final WebSocketService service = ref.watch(webSocketServiceProvider);
  return service.messages;
});

class WebSocketNotifier extends StateNotifier<WebSocketStatus> {
  final WebSocketService _service;
  StreamSubscription<WebSocketStatus>? _statusSubscription;

  WebSocketNotifier(this._service) : super(WebSocketStatus.disconnected) {
    _statusSubscription = _service.status.listen((WebSocketStatus status) {
      if (mounted) {
        state = status;
      }
    });
  }

  void connect() => _service.connect();
  void disconnect() => _service.disconnect();
  void sendTyping(int recipientId, bool isTyping) =>
      _service.sendTyping(recipientId, isTyping);

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<WebSocketNotifier, WebSocketStatus>
    webSocketProvider =
    StateNotifierProvider<WebSocketNotifier, WebSocketStatus>((Ref ref) {
  final WebSocketService service = ref.watch(webSocketServiceProvider);
  return WebSocketNotifier(service);
});
