// File: lib/data/models/user_settings_model.dart

class MonthlySettings {
  final double salary;
  final int startDay;
  // 0 = Same month (e.g. Jan cycle starts Jan 1), -1 = Previous Month (Jan cycle starts Dec 26)
  final int monthOffset; 

  MonthlySettings({
    this.salary = 0.0,
    this.startDay = 1,
    this.monthOffset = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'salary': salary,
      'startDay': startDay,
      'monthOffset': monthOffset,
    };
  }

  factory MonthlySettings.fromMap(Map<String, dynamic> map) {
    return MonthlySettings(
      salary: (map['salary'] ?? 0).toDouble(),
      startDay: map['startDay'] ?? 1,
      monthOffset: map['monthOffset'] ?? 0,
    );
  }
}

class UserSettingsModel {
  final double defaultSalary;
  final int defaultStartDay;
  final Map<String, MonthlySettings> monthlyOverrides; // Key: "yyyy-MM"

  UserSettingsModel({
    this.defaultSalary = 0.0, 
    this.defaultStartDay = 1,
    this.monthlyOverrides = const {},
  });

  factory UserSettingsModel.fromMap(Map<String, dynamic> map) {
    final overrides = <String, MonthlySettings>{};
    if (map['monthlyOverrides'] != null) {
      (map['monthlyOverrides'] as Map<String, dynamic>).forEach((key, value) {
        overrides[key] = MonthlySettings.fromMap(value);
      });
    }

    return UserSettingsModel(
      defaultSalary: (map['defaultSalary'] ?? map['salary'] ?? 0).toDouble(), // fallback for migration
      defaultStartDay: map['defaultStartDay'] ?? map['salaryDate'] ?? 1,
      monthlyOverrides: overrides,
    );
  }
}
