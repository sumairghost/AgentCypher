class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final AgentActionResult? actionResult;
  final String? imageUrl;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.actionResult,
    this.imageUrl,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'actionResult': actionResult?.toJson(),
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role']?.toString() ?? 'assistant',
        content: json['content']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
        imageUrl: json['imageUrl']?.toString(),
        actionResult: json['actionResult'] is Map
            ? AgentActionResult.fromJson(Map<String, dynamic>.from(json['actionResult'] as Map))
            : null,
      );
}

class AgentActionResult {
  final String actionType;
  final bool success;
  final String? details;

  AgentActionResult({required this.actionType, required this.success, this.details});

  Map<String, dynamic> toJson() => {'actionType': actionType, 'success': success, 'details': details};

  factory AgentActionResult.fromJson(Map<String, dynamic> json) => AgentActionResult(
        actionType: json['actionType']?.toString() ?? 'unknown',
        success: json['success'] == true,
        details: json['details']?.toString(),
      );
}
