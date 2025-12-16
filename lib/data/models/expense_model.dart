// File: lib/data/models/expense_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final double amount;
  final String category;
  final String description;
  final String date;
  final String type; // 'expense', 'loan', 'income'
  
  // Loan specific
  final bool isReturned;
  final double returnedAmount;
  final String? loanee;
  final String? originChargeId; // ID of the FixedCharge this originated from

  final DateTime? createdAt; // Can be null locally before sync

  ExpenseModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    required this.type,
    this.isReturned = false,
    this.returnedAmount = 0.0,
    this.loanee,
    this.originChargeId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'date': date,
      'type': type,
      'isReturned': isReturned,
      'returnedAmount': returnedAmount,
      if (loanee != null) 'loanee': loanee,
      if (originChargeId != null) 'originChargeId': originChargeId,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      // Note: We don't save 'id' as a field, it's the doc key
    };
  }

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle Timestamp
    DateTime? createdDate;
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        createdDate = (data['createdAt'] as Timestamp).toDate();
      }
    }

    return ExpenseModel(
      id: doc.id,
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      date: data['date'] ?? '',
      type: data['type'] ?? 'expense',
      isReturned: data['isReturned'] ?? false,
      returnedAmount: (data['returnedAmount'] ?? 0).toDouble(),
      loanee: data['loanee'],
      originChargeId: data['originChargeId'],
      createdAt: createdDate,
    );
  }

  ExpenseModel copyWith({
    String? category,
    String? description,
    double? amount,
    double? returnedAmount,
    bool? isReturned,
  }) {
    return ExpenseModel(
      id: id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date,
      type: type,
      isReturned: isReturned ?? this.isReturned,
      returnedAmount: returnedAmount ?? this.returnedAmount,
      loanee: loanee,
      originChargeId: originChargeId,
      createdAt: createdAt,
    );
  }
}
