// File: lib/providers/expense_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/expense_model.dart';
import '../data/models/category_model.dart';
import '../data/models/user_settings_model.dart';
import '../data/services/firestore_service.dart';
import '../core/constants.dart';

class ExpenseProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  String? userId;

  List<ExpenseModel> _expenses = [];
  List<CategoryModel> _categories = [];
  double _salary = 0.0;
  
  // UI State
  int _selectedMonth = DateTime.now().month - 1; // 0-indexed for consistent logic
  int _selectedYear = DateTime.now().year;
  String _filterType = 'all'; // 'all', 'expense', 'loan', 'income'

  // Streams
  StreamSubscription? _expensesSub;
  StreamSubscription? _settingsSub;
  StreamSubscription? _categoriesSub;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ExpenseModel> get expenses => _expenses;
  List<CategoryModel> get categories {
    final defaults = DEFAULT_CATEGORIES.map((c) => CategoryModel.fromMap(c)).toList();
    // Combine and deduplicate by name, preferring user categories
    final Map<String, CategoryModel> uniqueCategories = {};
    
    // Add defaults first
    for (var c in defaults) {
      uniqueCategories[c.name] = c;
    }
    
    // Override/Add user categories
    for (var c in _categories) {
      uniqueCategories[c.name] = c;
    }
    
    return uniqueCategories.values.toList();
  }
  double get salary => _salary;
  
  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;
  String get filterType => _filterType;

  void setUserId(String? uid) {
    if (userId == uid) return;
    userId = uid;
    _cancelSubscriptions();
    
    if (uid != null) {
      _initStreams(uid);
    } else {
      _expenses = [];
      _salary = 0;
      notifyListeners();
    }
  }

  void _initStreams(String uid) {
    _isLoading = true;
    notifyListeners();

    _expensesSub = _firestoreService.getExpensesStream(uid).listen((data) {
      _expenses = data;
      _isLoading = false;
      notifyListeners();
    });

    _settingsSub = _firestoreService.getSettingsStream(uid).listen((data) {
      _salary = data.salary;
      notifyListeners();
    });

    _categoriesSub = _firestoreService.getCategoriesStream(uid).listen((data) {
      _categories = data;
      notifyListeners();
    });
  }

  void _cancelSubscriptions() {
    _expensesSub?.cancel();
    _settingsSub?.cancel();
    _categoriesSub?.cancel();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  // --- UI Logic ---

  void setMonth(int month) {
    _selectedMonth = month;
    notifyListeners();
  }

  void setYear(int year) {
    _selectedYear = year;
    notifyListeners();
  }

  void setFilterType(String type) {
    _filterType = type;
    notifyListeners();
  }

  // Filtered List
  List<ExpenseModel> get filteredExpenses {
    List<ExpenseModel> result = _expenses.filter((exp) {
      final d = DateTime.parse(exp.date);
      // JS getMonth is 0-indexed, Dart DateTime.month is 1-indexed
      // Our _selectedMonth is 0-indexed (because we use it for index in MONTHS array)
      final expMonthIndex = d.month - 1; 
      
      final isCurrentMonth = expMonthIndex == _selectedMonth && d.year == _selectedYear;

      if (_filterType == 'expense') {
        return isCurrentMonth && (exp.type == 'expense' || exp.type == null);
      }
      if (_filterType == 'loan') {
        return exp.type == 'loan' && (!exp.isReturned || isCurrentMonth);
      }
      if (_filterType == 'income') {
        return isCurrentMonth && exp.type == 'income';
      }
      // 'all'
      return isCurrentMonth;
    }).toList();

    // Sort
    result.sort((a, b) {
       int dateA = DateTime.parse(a.date).millisecondsSinceEpoch;
       int dateB = DateTime.parse(b.date).millisecondsSinceEpoch;
       if (dateA != dateB) return dateB - dateA;
       
       // Secondary sort by createdAt
       final tA = a.createdAt?.millisecondsSinceEpoch ?? 0;
       final tB = b.createdAt?.millisecondsSinceEpoch ?? 0;
       
       if (_filterType == 'loan') {
         if (a.isReturned == b.isReturned) return tB - tA;
         return a.isReturned ? 1 : -1;
       }
       return tB - tA;
    });

    return result;
  }

  // Dashboard Stats
  Map<String, double> get dashboardStats {
    final monthlyExpenses = _expenses.where((exp) {
      final d = DateTime.parse(exp.date);
      return (d.month - 1) == _selectedMonth && d.year == _selectedYear;
    });

    double totalSpent = 0;
    double totalIncome = 0;

    for (var curr in monthlyExpenses) {
       if (curr.type == 'income') {
         totalIncome += curr.amount;
       } else if (curr.type == 'loan') {
         final returned = curr.returnedAmount; 
         // cost = amount - returned
         totalSpent += (curr.amount - returned);
       } else {
         totalSpent += curr.amount;
       }
    }

    final remaining = (_salary + totalIncome) - totalSpent;

    return {
      'totalSpent': totalSpent,
      'totalIncome': totalIncome,
      'remaining': remaining,
    };
  }

  // Chart Data
  List<Map<String, dynamic>> get chartData {
    final Map<String, double> categoryMap = {};

    for (var curr in filteredExpenses) {
      if (curr.type == 'income') continue;

      if (curr.type == 'loan') {
        if (curr.isReturned) continue;
        double cost = curr.amount - curr.returnedAmount;
        if (cost <= 0) continue;
        categoryMap['Loan'] = (categoryMap['Loan'] ?? 0) + cost;
      } else {
        categoryMap[curr.category] = (categoryMap[curr.category] ?? 0) + curr.amount;
      }
    }

    final List<Map<String, dynamic>> result = categoryMap.entries.map((e) {
      return {'name': e.key, 'value': e.value};
    }).toList();

    result.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    return result;
  }

  // Actions delegate
  Future<void> addExpense(ExpenseModel expense) async {
    if (userId == null) return;
    await _firestoreService.addExpense(userId!, expense);
  }
  
  Future<void> updateExpense(ExpenseModel expense) async {
    if (userId == null) return;
    await _firestoreService.updateExpense(userId!, expense.id, expense.toMap());
  }

  Future<void> updateRepayment(ExpenseModel loan, double amountToAdd) async {
    if (userId == null) return;
    final newReturned = loan.returnedAmount + amountToAdd;
    final isFullyReturned = newReturned >= loan.amount;
    
    await _firestoreService.updateExpense(userId!, loan.id, {
      'returnedAmount': newReturned,
      'isReturned': isFullyReturned,
    });
  }

  Future<void> deleteExpense(String id) async {
    if (userId == null) return;
    await _firestoreService.deleteExpense(userId!, id);
  }
  
  Future<void> updateSalary(double val) async {
    if (userId == null) return;
    await _firestoreService.updateSalary(userId!, val);
  }
  
  Future<void> addCategory(CategoryModel cat) async {
     if (userId == null) return;
     await _firestoreService.addCategory(userId!, cat);
  }
  
  Future<void> deleteCategory(CategoryModel cat) async {
     if (userId == null) return;
     await _firestoreService.deleteCategory(userId!, cat);
  }

  Future<void> resetData() async {
    if (userId == null) return;
    await _firestoreService.resetData(userId!);
  }
}

extension ListFilter<T> on List<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
