class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.room,
    required this.sender,
    required this.content,
    required this.at,
  });

  final String id;
  final String room;
  final String sender;
  final String content;
  final int at;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '${json['at'] ?? DateTime.now().millisecondsSinceEpoch}',
      room: json['room'] as String? ?? 'hall',
      sender: json['sender'] as String? ?? json['userAddress'] as String? ?? '匿名',
      content: json['content'] as String? ?? json['text'] as String? ?? '',
      at: (json['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
