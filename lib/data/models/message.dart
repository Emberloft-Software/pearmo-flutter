/// Row from `messages`.
class Message {
  final String id;
  final String connectionId;
  final String senderId;
  final String content;
  final String contentType;
  final DateTime sentAt;

  /// Storage path in the `chat-media` bucket, set only when
  /// `contentType` is `image`/`video`. Resolved to a signed URL for
  /// display — never a public path (see `StorageRepository`).
  final String? mediaUrl;

  const Message({
    required this.id,
    required this.connectionId,
    required this.senderId,
    required this.content,
    required this.contentType,
    required this.sentAt,
    this.mediaUrl,
  });

  bool isMine(String currentUserId) => senderId == currentUserId;

  bool get isImage => contentType == 'image';
  bool get isVideo => contentType == 'video';

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      connectionId: json['connection_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      contentType: json['content_type'] as String? ?? 'text',
      sentAt: DateTime.parse(json['sent_at'] as String),
      mediaUrl: json['media_url'] as String?,
    );
  }
}
