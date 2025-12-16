class InsuranceClaimModel {
  final String id;
  final String userId;
  final String title;
  final double totalAmount;
  final double? refundAmount;
  final String date; // ISO 8601 date of the initial expense
  final String status; // 'pending', 'paid'
  final String? relatedExpenseId; // ID of the auto-generated expense

  InsuranceClaimModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.totalAmount,
    this.refundAmount,
    required this.date,
    required this.status,
    this.relatedExpenseId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'totalAmount': totalAmount,
      'refundAmount': refundAmount,
      'date': date,
      'status': status,
      'relatedExpenseId': relatedExpenseId,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  factory InsuranceClaimModel.fromMap(String id, Map<String, dynamic> data) {
    return InsuranceClaimModel(
      id: id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      refundAmount: data['refundAmount'] != null ? (data['refundAmount']).toDouble() : null,
      date: data['date'] ?? '',
      status: data['status'] ?? 'pending',
      relatedExpenseId: data['relatedExpenseId'],
    );
  }
}
