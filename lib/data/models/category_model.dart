// File: lib/data/models/category_model.dart
class CategoryModel {
  final String name;
  final String color;
  final String icon;

  CategoryModel({
    required this.name,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color': color,
      'icon': icon,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      name: map['name'] ?? '',
      color: map['color'] ?? '#000000',
      icon: map['icon'] ?? 'MoreHorizontal',
    );
  }
}
