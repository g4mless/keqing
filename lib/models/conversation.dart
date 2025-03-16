class Conversation {
  final String id;
  String title; // Remove final
  final DateTime createdAt;
  final List<Map<String, String>> messages;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'messages': messages,
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'],
    title: json['title'],
    createdAt: DateTime.parse(json['createdAt']),
    messages: List<Map<String, String>>.from(
      json['messages'].map((x) => Map<String, String>.from(x)),
    ),
  );

  factory Conversation.create() => Conversation(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    title: 'New Chat',
    createdAt: DateTime.now(),
    messages: [],
  );
}