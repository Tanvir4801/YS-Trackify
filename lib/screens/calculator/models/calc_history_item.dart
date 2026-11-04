class CalcHistoryItem {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final Map<String, dynamic>? inputs;
  final Map<String, dynamic>? results;

  CalcHistoryItem({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.inputs,
    this.results,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'title': title,
    'subtitle': subtitle,
    'timestamp': timestamp.toIso8601String(),
    if (inputs != null) 'inputs': inputs,
    if (results != null) 'results': results,
  };

  factory CalcHistoryItem.fromJson(Map<String, dynamic> json) => CalcHistoryItem(
    id: json['id'] as String,
    category: json['category'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    inputs: json['inputs'] as Map<String, dynamic>?,
    results: json['results'] as Map<String, dynamic>?,
  );
}
