import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WebSocketStatus { connecting, connected, disconnected, error }

class WebSocketMessage {
  final String type;
  final Map<String, dynamic> data;

  WebSocketMessage({required this.type, required this.data});

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String? ?? '',
      data: json,
    );
  }
}

class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _staleCleanupTimer;
  int? _currentUserId;
  String? _baseUrl;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 10;
  static const Duration heartbeatInterval = Duration(seconds: 25);
  static const Duration reconnectBaseDelay = Duration(seconds: 2);

  final StreamController<WebSocketMessage> _messageController =
      StreamController<WebSocketMessage>.broadcast();
  final StreamController<WebSocketStatus> _statusController =
      StreamController<WebSocketStatus>.broadcast();
  final StreamController<Set<int>> _onlineUsersController =
      StreamController<Set<int>>.broadcast();

  Stream<WebSocketMessage> get messages => _messageController.stream;
  Stream<WebSocketStatus> get status => _statusController.stream;
  Stream<Set<int>> get onlineUsers => _onlineUsersController.stream;
  WebSocketStatus get currentStatus => _status;

  Future<void> connect() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    _baseUrl = prefs.getString('backend_url');
    _currentUserId = prefs.getInt('user_id');

    if (token == null || _baseUrl == null || _currentUserId == null) {
      debugPrint('[WebSocket] Missing auth info, cannot connect');
      return;
    }

    _status = WebSocketStatus.connecting;
    _statusController.add(_status);

    try {
      final String wsUrl = _baseUrl!.replaceFirst('http', 'ws');
      final String url = '$wsUrl/ws/$_currentUserId?token=$token';

      debugPrint('[WebSocket] Connecting to $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        (dynamic data) {
          _reconnectAttempts = 0;
          if (_status != WebSocketStatus.connected) {
            _status = WebSocketStatus.connected;
            _statusController.add(_status);
          }

          try {
            final String textData = data is String ? data : String.fromCharCodes(data as List<int>);
            final Map<String, dynamic> json = jsonDecode(textData);
            final WebSocketMessage message = WebSocketMessage.fromJson(json);

            if (message.type == 'heartbeat_ack') {
              return;
            }

            if (message.type == 'online_status') {
              final List<dynamic> onlineList = message.data['online_users'] ?? [];
              _onlineUsersController.add(onlineList.cast<int>().toSet());
              return;
            }

            _messageController.add(message);
          } catch (e) {
            debugPrint('[WebSocket] Parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('[WebSocket] Error: $error');
          _status = WebSocketStatus.error;
          _statusController.add(_status);
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[WebSocket] Connection closed');
          _status = WebSocketStatus.disconnected;
          _statusController.add(_status);
          _scheduleReconnect();
        },
      );

      _startHeartbeat();
      _requestOnlineUsers();
    } catch (e) {
      debugPrint('[WebSocket] Connection failed: $e');
      _status = WebSocketStatus.error;
      _statusController.add(_status);
      _scheduleReconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_status == WebSocketStatus.connected) {
        send({'type': 'heartbeat'});
      }
    });
  }

  void _requestOnlineUsers() {
    send({'type': 'get_online'});
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('[WebSocket] Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    final int delaySeconds = reconnectBaseDelay.inSeconds * (1 << _reconnectAttempts);
    final Duration delay = Duration(seconds: delaySeconds.clamp(2, 60));

    debugPrint('[WebSocket] Reconnecting in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1})');
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  void send(Map<String, dynamic> message) {
    if (_channel != null && _status == WebSocketStatus.connected) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('[WebSocket] Send error: $e');
      }
    }
  }

  void sendTyping(int recipientId, bool isTyping) {
    send({
      'type': 'typing',
      'recipient_id': recipientId,
      'is_typing': isTyping,
    });
  }

  void requestOnlineUsers() {
    send({'type': 'get_online'});
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _staleCleanupTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _status = WebSocketStatus.disconnected;
    _statusController.add(_status);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
    _onlineUsersController.close();
  }
}
