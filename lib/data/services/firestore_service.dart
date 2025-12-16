import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../models/category_model.dart';
import '../models/category_model.dart';
import '../models/user_settings_model.dart';
import '../models/fixed_charge_model.dart';
import '../models/insurance_claim_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String appId = 'expense-tracker';

  // --- Paths ---
  // artifacts/{appId}/users/{uid}/expenses
  // artifacts/{appId}/users/{uid}/settings/general
  // artifacts/{appId}/users/{uid}/settings/categories

  CollectionReference _getExpensesRef(String uid) {
    return _db
        .collection('artifacts')
        .doc(appId)
        .collection('users')
        .doc(uid)
        .collection('expenses');
  }

  DocumentReference _getSettingsRef(String uid) {
    return _db
        .collection('artifacts')
        .doc(appId)
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('general');
  }

  DocumentReference _getCategoriesRef(String uid) {
    return _db
        .collection('artifacts')
        .doc(appId)
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('categories');
  }

  CollectionReference _getFixedChargesRef(String uid) {
    return _db
        .collection('artifacts')
        .doc(appId)
        .collection('users')
        .doc(uid)
        .collection('fixed_charges');
  }

  // --- Streams ---

  Stream<List<ExpenseModel>> getExpensesStream(String uid) {
    return _getExpensesRef(uid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();
    });
  }

  Stream<UserSettingsModel> getSettingsStream(String uid) {
    return _getSettingsRef(uid).snapshots().map((doc) {
      if (!doc.exists) return UserSettingsModel();
      return UserSettingsModel.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  Stream<List<CategoryModel>> getCategoriesStream(String uid) {
    return _getCategoriesRef(uid).snapshots().map((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      if (data['list'] != null) {
        return (data['list'] as List).map((c) => CategoryModel.fromMap(c)).toList();
      }
      return [];
    });
  }

  // --- Actions ---

  Future<String> addExpense(String uid, ExpenseModel expense) async {
    final docRef = await _getExpensesRef(uid).add({
      ...expense.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateExpense(String uid, String expenseId, Map<String, dynamic> data) async {
    await _getExpensesRef(uid).doc(expenseId).update(data);
  }

  Future<void> deleteExpense(String uid, String expenseId) async {
    await _getExpensesRef(uid).doc(expenseId).delete();
  }

  Future<void> updateSettings(String uid, Map<String, dynamic> data) async {
    await _getSettingsRef(uid).set(data, SetOptions(merge: true));
  }

  Future<void> updateMonthlyOverride(String uid, int year, int month, MonthlySettings settings) async {
    // month is 1-12
    final key = "$year-$month"; 
    await _getSettingsRef(uid).set({
      'monthlyOverrides': {
        key: settings.toMap()
      }
    }, SetOptions(merge: true));
  }

  Future<void> addCategory(String uid, CategoryModel category) async {
    // We use arrayUnion to append to the list. 
    // SetOptions(merge: true) combined with arrayUnion essentially "updates if exists, creates if not"
    // However, if the doc doesn't exist, arrayUnion works fine with set/merge.
    // The issue might be that a plain set() overwrites. 
    // Ensure we are appending to 'list'.
    
    final docRef = _getCategoriesRef(uid);
    // Use update if you know it exists, or set(merge) effectively. 
    // To be safe against overwriting entire document if it was structured differently:
    await docRef.set({
      'list': FieldValue.arrayUnion([category.toMap()])
    }, SetOptions(merge: true));
  }

  Future<void> deleteCategory(String uid, CategoryModel category) async {
    await _getCategoriesRef(uid).update({
      'list': FieldValue.arrayRemove([category.toMap()])
    });
  }
  
  Future<void> resetData(String uid) async {
    // 1. Reset Salary
    await _getSettingsRef(uid).set({'salary': 0}, SetOptions(merge: true));
    
    // 2. Delete all expenses
    final snapshot = await _getExpensesRef(uid).get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // --- Fixed Charges ---

  Stream<List<FixedChargeModel>> getFixedChargesStream(String uid) {
    return _getFixedChargesRef(uid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => FixedChargeModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> addFixedCharge(String uid, FixedChargeModel charge) async {
    await _getFixedChargesRef(uid).add({
      ...charge.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateFixedCharge(String uid, FixedChargeModel charge) async {
    await _getFixedChargesRef(uid).doc(charge.id).update(charge.toMap());
  }

  Future<void> deleteFixedCharge(String uid, String chargeId) async {
    await _getFixedChargesRef(uid).doc(chargeId).delete();
  }
  // --- Insurance Claims ---

  CollectionReference _getInsuranceClaimsRef(String uid) {
    return _db
        .collection('artifacts')
        .doc(appId)
        .collection('users')
        .doc(uid)
        .collection('insurance_claims');
  }

  Stream<List<InsuranceClaimModel>> getInsuranceClaimsStream(String uid) {
    return _getInsuranceClaimsRef(uid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => InsuranceClaimModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<String> addInsuranceClaim(String uid, InsuranceClaimModel claim) async {
    final docRef = await _getInsuranceClaimsRef(uid).add({
      ...claim.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateInsuranceClaim(String uid, String claimId, Map<String, dynamic> data) async {
    await _getInsuranceClaimsRef(uid).doc(claimId).update(data);
  }

  Future<void> deleteInsuranceClaim(String uid, String claimId) async {
    await _getInsuranceClaimsRef(uid).doc(claimId).delete();
  }
}
