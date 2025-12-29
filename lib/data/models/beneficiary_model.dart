class BeneficiaryModel {
  final String id;
  final String name;
  final String? phoneNumber;
  final String createdAt;

  BeneficiaryModel({
    required this.id,
    required this.name,
    this.phoneNumber,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt,
    };
  }

  factory BeneficiaryModel.fromMap(Map<String, dynamic> map, String docId) {
    return BeneficiaryModel(
      id: docId,
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
