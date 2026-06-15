/// Row from `messages`.
class Message {
  final String id;
  final String connectionId;
  final String senderId;
  final String content;
  final String contentType;
  final DateTime sentAt;

  const Message({
    required this.id,
    required this.connectionId,
    required this.senderId,
    required this.content,
    required this.contentType,
    required this.sentAt,
  });

  bool isMine(String currentUserId) => senderId == currentUserId;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      connectionId: json['connection_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      contentType: json['content_type'] as String? ?? 'text',
      sentAt: DateTime.parse(json['sent_at'] as String),
    );
  }
}
