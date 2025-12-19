import 'package:cloud_firestore/cloud_firestore.dart';

class FixedChargeModel {
  final String id;
  final String name;
  final double amount;
  final String category;
  final int dayOfMonth;
  final bool isAutoApplied;
  final bool delayedAutoPay;

  FixedChargeModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.dayOfMonth,
    this.isAutoApplied = false,
    this.delayedAutoPay = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'category': category,
      'dayOfMonth': dayOfMonth,
      'isAutoApplied': isAutoApplied,
      'delayedAutoPay': delayedAutoPay,
    };
  }

  factory FixedChargeModel.fromMap(String id, Map<String, dynamic> map) {
    return FixedChargeModel(
      id: id,
      name: map['name'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      dayOfMonth: map['dayOfMonth'] ?? 1,
      isAutoApplied: map['isAutoApplied'] ?? false,
      delayedAutoPay: map['delayedAutoPay'] ?? false,
    );
  }

  factory FixedChargeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FixedChargeModel.fromMap(doc.id, data);
  }
}
