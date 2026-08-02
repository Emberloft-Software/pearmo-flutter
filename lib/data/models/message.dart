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

  /// Written by the database, not by a participant — currently only the
  /// verification-tier-change trigger (see
  /// docs/matching-and-verification-tiers.md). Rendered as a centred
  /// notice rather than a bubble: `sender_id` is set to whoever the event
  /// is *about* (the column is NOT NULL and FKs to `users`), so bubbling it
  /// would read as if that person had typed it.
  bool get isSystem => contentType == 'system';

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
