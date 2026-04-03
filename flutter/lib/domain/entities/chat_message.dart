class ChatMessage {
  final String id;
  final String matchId;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.isRead,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'matchId': matchId,
        'senderId': senderId,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        matchId: json['matchId'] as String,
        senderId: json['senderId'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: json['isRead'] as bool,
      );

  ChatMessage copyWith({
    String? id,
    String? matchId,
    String? senderId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        matchId: matchId ?? this.matchId,
        senderId: senderId ?? this.senderId,
        content: content ?? this.content,
        timestamp: timestamp ?? this.timestamp,
        isRead: isRead ?? this.isRead,
      );
}
