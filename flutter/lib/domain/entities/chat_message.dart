class ChatMessage {
  final String id;
  final String matchId;
  final String senderId;
  final String? content;
  final String? imageUrl;
  final String? videoUrl;
  final String? gifUrl;
  final String messageType;
  final bool isRead;
  final bool isEdited;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    this.content,
    this.imageUrl,
    this.videoUrl,
    this.gifUrl,
    this.messageType = "text",
    this.isRead = false,
    this.isEdited = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'matchId': matchId,
        'senderId': senderId,
        'content': content,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'gifUrl': gifUrl,
        'messageType': messageType,
        'isRead': isRead,
        'isEdited': isEdited,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        matchId: json['matchId'] as String,
        senderId: json['senderId'] as String,
        content: json['content'] as String?,
        imageUrl: json['imageUrl'] as String?,
        videoUrl: json['videoUrl'] as String?,
        gifUrl: json['gifUrl'] as String?,
        messageType: json['messageType'] as String? ?? 'text',
        isRead: json['isRead'] as bool? ?? false,
        isEdited: json['isEdited'] as bool? ?? false,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  ChatMessage copyWith({
    String? id,
    String? matchId,
    String? senderId,
    String? content,
    String? imageUrl,
    String? videoUrl,
    String? gifUrl,
    String? messageType,
    bool? isRead,
    bool? isEdited,
    DateTime? timestamp,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        matchId: matchId ?? this.matchId,
        senderId: senderId ?? this.senderId,
        content: content ?? this.content,
        imageUrl: imageUrl ?? this.imageUrl,
        videoUrl: videoUrl ?? this.videoUrl,
        gifUrl: gifUrl ?? this.gifUrl,
        messageType: messageType ?? this.messageType,
        isRead: isRead ?? this.isRead,
        isEdited: isEdited ?? this.isEdited,
        timestamp: timestamp ?? this.timestamp,
      );
}
