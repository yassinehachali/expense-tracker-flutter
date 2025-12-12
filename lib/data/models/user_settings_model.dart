// File: lib/data/models/user_settings_model.dart
class UserSettingsModel {
  final double salary;

  UserSettingsModel({this.salary = 0.0});

  factory UserSettingsModel.fromMap(Map<String, dynamic> map) {
    return UserSettingsModel(
      salary: (map['salary'] ?? 0).toDouble(),
    );
  }
}
