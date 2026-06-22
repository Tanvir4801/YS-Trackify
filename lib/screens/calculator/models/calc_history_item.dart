class CalcHistoryItem {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final DateTime timestamp;

  CalcHistoryItem({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'title': title,
    'subtitle': subtitle,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CalcHistoryItem.fromJson(Map<String, dynamic> json) => CalcHistoryItem(
    id: json['id'] as String,
    category: json['category'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
