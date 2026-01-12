class EventModel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final double totalAmount;
  final String lastUpdated; // Iso8601 String
  final bool isClosed;
  final String icon;

  EventModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.totalAmount = 0.0,
    required this.lastUpdated,
    this.isClosed = false,
    this.icon = 'Calendar', // Default icon
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'totalAmount': totalAmount,
      'lastUpdated': lastUpdated,
      'isClosed': isClosed,
      'icon': icon,
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      lastUpdated: map['lastUpdated'] ?? DateTime.now().toIso8601String(),
      isClosed: map['isClosed'] ?? false,
      icon: map['icon'] ?? 'Plane',
    );
  }

  EventModel copyWith({
    String? name,
    String? description,
    double? totalAmount,
    String? lastUpdated,
    bool? isClosed,
    String? icon,
  }) {
    return EventModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isClosed: isClosed ?? this.isClosed,
      icon: icon ?? this.icon,
    );
  }
}
