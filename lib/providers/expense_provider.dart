import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/expense_model.dart';
import '../data/models/category_model.dart';
import '../data/models/user_settings_model.dart';
import '../data/services/firestore_service.dart';
import '../core/constants.dart';
import '../core/utils.dart';

class ExpenseProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  String? userId;

  List<ExpenseModel> _expenses = [];
  List<CategoryModel> _categories = [];
  
  // Settings State
  UserSettingsModel _settings = UserSettingsModel();
  
  // UI State
  int _selectedMonth = DateTime.now().month - 1; // 0-indexed (Jan=0, Dec=11)
  int _selectedYear = DateTime.now().year;
  String _filterType = 'all';

  // Streams
  StreamSubscription? _expensesSub;
  StreamSubscription? _settingsSub;
  StreamSubscription? _categoriesSub;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ExpenseModel> get expenses => _expenses;
  List<CategoryModel> get categories {
    final defaults = DEFAULT_CATEGORIES.map((c) => CategoryModel.fromMap(c)).toList();
    final Map<String, CategoryModel> uniqueCategories = {};
    for (var c in defaults) uniqueCategories[c.name] = c;
    for (var c in _categories) uniqueCategories[c.name] = c;
    return uniqueCategories.values.toList();
  }
  
  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;
  String get filterType => _filterType;

  // --- Dynamic Cycle Logic ---

  MonthlySettings _getEffectiveSettings(int year, int month) {
    // month is 0-indexed coming in, convert to 1-indexed for key
    final key = "$year-${month + 1}";
    return _settings.monthlyOverrides[key] ?? MonthlySettings(
      salary: _settings.defaultSalary,
      startDay: _settings.defaultStartDay,
      monthOffset: (_settings.defaultStartDay > 1) ? -1 : 0
      // Logic for default offset:
      // If default start day is 1, it's SAME month (Jan 1).
      // If default start day > 1 (e.g. 26), usually means PREVIOUS month (Dec 26 for Jan).
    );
  }

  // Returns the precise Start Date for a specific budget month
  DateTime getCycleStartDate(int year, int month) {
    final s = _getEffectiveSettings(year, month);
    // month is 0-indexed
    // DateTime handles overflow: DateTime(2025, 0 + (-1), 26) -> Dec 26, 2024
    return DateTime(year, month + 1 + s.monthOffset, s.startDay);
  }
  
  // Returns salary for current view
  double get currentCycleSalary => _getEffectiveSettings(_selectedYear, _selectedMonth).salary;
  
  // Returns start date for CURRENTLY selected view
  DateTime get currentCycleStart => getCycleStartDate(_selectedYear, _selectedMonth);

  // Returns end date: The day BEFORE the NEXT cycle starts
  DateTime get currentCycleEnd {
     // Next month logic
     int nextMonth = _selectedMonth + 1;
     int nextYear = _selectedYear;
     if (nextMonth > 11) {
       nextMonth = 0;
       nextYear++;
     }
     
     final nextStart = getCycleStartDate(nextYear, nextMonth);
     return nextStart.subtract(const Duration(days: 1));
  }
  
  bool isInCurrentCycle(DateTime date) {
    final start = currentCycleStart;
    final end = currentCycleEnd;
    final target = DateTime(date.year, date.month, date.day);
    return (target.isAfter(start) || target.isAtSameMomentAs(start)) && 
           (target.isBefore(end) || target.isAtSameMomentAs(end));
  }

  // ---

  void setUserId(String? uid) {
    if (userId == uid) return;
    userId = uid;
    _cancelSubscriptions();
    
    if (uid != null) {
      _initStreams(uid);
    } else {
      _expenses = [];
      _settings = UserSettingsModel();
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
    }, onError: (e) {
      _isLoading = false;
      notifyListeners();
    });

    _settingsSub = _firestoreService.getSettingsStream(uid).listen((data) {
      _settings = data;
      // Force refresh of any derived data
      notifyListeners();
    }, onError: (e) => print("Error loading settings: $e"));

    _categoriesSub = _firestoreService.getCategoriesStream(uid).listen((data) {
      _categories = data;
      notifyListeners();
    }, onError: (e) => print("Error loading categories: $e"));
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

  List<ExpenseModel> get filteredExpenses {
    List<ExpenseModel> result = _expenses.filter((exp) {
      final d = DateTime.parse(exp.date);
      final inCycle = isInCurrentCycle(d);

      if (!inCycle && exp.type != 'loan') return false; 
      
      if (exp.type == 'loan') {
         // If filter is explicitly 'loan', show ALL loans (active and returned history)
         if (_filterType == 'loan') return true;
         // Otherwise (Dashboard/All), show active loans OR loans from this cycle
         return !exp.isReturned || inCycle;
      }

      if (_filterType == 'expense') {
        return inCycle && (exp.type == 'expense' || exp.type == null);
      }
      if (_filterType == 'income') {
        return inCycle && exp.type == 'income';
      }
      return inCycle;
    }).toList();

    result.sort((a, b) {
       int dateA = DateTime.parse(a.date).millisecondsSinceEpoch;
       int dateB = DateTime.parse(b.date).millisecondsSinceEpoch;
       if (dateA != dateB) return dateB - dateA;
       
       final tA = a.createdAt?.millisecondsSinceEpoch ?? 0;
       final tB = b.createdAt?.millisecondsSinceEpoch ?? 0;
       
       if (_filterType == 'loan') {
         if (a.isReturned == b.isReturned) return tB - tA;
         return a.isReturned ? 1 : -1;
       }
       return tB - tA;
    });

    // Secondary filter optimization
    if (_filterType == 'expense') {
      result = result.where((e) => e.type == 'expense' || e.type == null).toList();
    } else if (_filterType == 'income') {
      result = result.where((e) => e.type == 'income').toList();
    } else if (_filterType == 'loan') {
       result = result.where((e) => e.type == 'loan').toList();
    }
    
    // Inject Rollover (only for 'all' or specific view logic)
    // User wants to see it as a transaction.
    if (_filterType == 'all' || _filterType == 'income') { // Maybe show in income/all?
      final rollover = _currentRolloverAmount;
      if (rollover > 0) {
        int prevMonth = _selectedMonth - 1;
        if (prevMonth < 0) prevMonth = 11;
        
        result.insert(0, ExpenseModel( // Add to top or sort? If we sort by date, this is Start Date
          id: 'rollover_virtual', // Unique virtual ID
          amount: rollover,
          category: 'Rollover',
          date: currentCycleStart.toIso8601String(),
          type: 'rollover',
          description: 'Remaining Balance from ${Utils.getMonthName(prevMonth)}',
        ));
      }
    }

    return result;
  }

  // --- Rollover Logic ---
  
  double get _currentRolloverAmount {
    int prevMonth = _selectedMonth - 1;
    int prevYear = _selectedYear;
    if (prevMonth < 0) {
      prevMonth = 11;
      prevYear--;
    }
    
    // Check if user has deleted/ignored this specific rollover
    // Key format: "YYYY-MM" (of the CURRENT view being rolled INTO)
    // Wait, if I delete the rollover shown in Feb (which is Jan's balance), do I ignore "Feb" or "Jan"?
    // The transaction is shown in the current month. "Rollover FROM Jan".
    // I should probably key it by the current month so it's easy to look up "Do I show rollover for this month?".
    final currentKey = "$_selectedYear-${_selectedMonth + 1}";
    if (_settings.ignoredRollovers.contains(currentKey)) {
      return 0.0;
    }

    // 2. Get Settings & Range for Prev Month
    final settings = _getEffectiveSettings(prevYear, prevMonth);
    final start = getCycleStartDate(prevYear, prevMonth);
    // End of prev cycle is one day before start of current cycle
    final end = currentCycleStart.subtract(const Duration(days: 1)); // or Duration(seconds: 1) if we want exact check, but day comparison is safer

    // 3. Filter Expenses for Prev Month
    final prevExpenses = _expenses.where((exp) {
       final d = DateTime.parse(exp.date);
       final target = DateTime(d.year, d.month, d.day);
       return (target.isAfter(start) || target.isAtSameMomentAs(start)) && 
              (target.isBefore(end) || target.isAtSameMomentAs(end));
    });

    // 4. Calculate Balance
    double income = 0;
    double spent = 0;
    for (var e in prevExpenses) {
       if (e.type == 'income') income += e.amount;
       else if (e.type == 'loan') spent += e.amount; 
       else spent += e.amount;
    }
    
    final balance = (settings.salary + income) - spent;
    return balance > 0 ? balance : 0.0;
  }

  Map<String, double> get dashboardStats {
    final cycleExpenses = _expenses.where((exp) {
      return isInCurrentCycle(DateTime.parse(exp.date));
    });

    double totalSpent = 0;
    double totalIncome = 0;

    for (var curr in cycleExpenses) {
       if (curr.type == 'income') {
         totalIncome += curr.amount;
       } else if (curr.type == 'loan') {
         totalSpent += curr.amount;
       } else {
         totalSpent += curr.amount;
       }
    }

    final rollover = _currentRolloverAmount;
    // Remaining = (Salary + Income + Rollover) - Spent
    final remaining = (currentCycleSalary + totalIncome + rollover) - totalSpent;

    return {
      'totalSpent': totalSpent,
      'totalIncome': totalIncome, // We keep this pure
      'remaining': remaining,
      'rollover': rollover, // Exposed if needed
    };
  }

  // ... (ChartData remains as is, logic relies on visible expenses) ...
  List<Map<String, dynamic>> get chartData {
    final Map<String, double> categoryMap = {};
    final cycleExpenses = _expenses.where((exp) {
       return isInCurrentCycle(DateTime.parse(exp.date));
    });

    for (var curr in cycleExpenses) {
      if (curr.type == 'income') continue;

      if (curr.type == 'loan') {
        categoryMap['Loan'] = (categoryMap['Loan'] ?? 0) + curr.amount;
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


  // --- Actions ---

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
    
    // 1. Update Loan
    await _firestoreService.updateExpense(userId!, loan.id, {
      'returnedAmount': newReturned,
      'isReturned': isFullyReturned,
    });

    // 2. Create Income Transaction for the Repayment Amount
    // This ensures the money is added to the current month's flow
    final incomeTx = ExpenseModel(
       id: '', 
       amount: amountToAdd,
       category: 'Loan Repayment',
       date: DateTime.now().toIso8601String(),
       type: 'income',
       description: isFullyReturned ? 'Repayment for ${loan.category}' : 'Partial Repayment for ${loan.category}',
    );
    await addExpense(incomeTx);
  }

  Future<void> setLoanReturned(ExpenseModel loan, bool isReturned) async {
    if (userId == null) return;
    
    // 1. Update the Loan Status
    await _firestoreService.updateExpense(userId!, loan.id, {
      'isReturned': isReturned,
      // We keep returnedAmount as 0 on the loan itself so it still counts as a full expense in history?
      // User said "if i retrieve the loan in february the amount of the loan should bee added in february"
      // This implies the original loan stays as a "cost" in December.
      // So we do NOT change returnedAmount on the loan to "cancel" the cost.
      // We just mark it as returned for UI status.
      'returnedAmount': isReturned ? loan.amount : 0.0, 
    });

    // 2. If we are marking it as RETURNED (not un-returning), add an INCOME transaction
    // to the CURRENT cycle.
    if (isReturned) {
       final incomeTx = ExpenseModel(
         id: '', // Generated by Firestore
         amount: loan.amount,
         category: 'Loan Repayment',
         date: DateTime.now().toIso8601String(), // NOW
         type: 'income',
         description: 'Repayment for ${loan.category}',
       );
       await addExpense(incomeTx);
    }
  }

  Future<void> deleteExpense(String id) async {
    if (userId == null) return;
    await _firestoreService.deleteExpense(userId!, id);
  }
  
  // New Methods for Settings
  
  Future<void> updateDefaultSalary(double val) async {
     if (userId == null) return;
     await _firestoreService.updateSettings(userId!, {'defaultSalary': val});
  }
  
  Future<void> updateDefaultStartDay(int day) async {
     if (userId == null) return;
     await _firestoreService.updateSettings(userId!, {'defaultStartDay': day});
  }
  
  Future<void> updateMonthlyOverride(int year, int month, double salary, int day, int offset) async {
    if (userId == null) return;
    final settings = MonthlySettings(salary: salary, startDay: day, monthOffset: offset);
    // month 0-11 -> 1-12
    await _firestoreService.updateMonthlyOverride(userId!, year, month + 1, settings);
  }

  
  Future<void> addCategory(CategoryModel cat) async {
     if (userId == null) return;
     await _firestoreService.addCategory(userId!, cat);
  }
  
  Future<void> deleteCategory(CategoryModel cat) async {
     if (userId == null) return;
     await _firestoreService.deleteCategory(userId!, cat);
  }

  Future<void> ignoreRollover(int year, int month) async {
    if (userId == null) return;
    final key = "$year-${month + 1}";
    
    // Optimistic update
    final newIgnored = List<String>.from(_settings.ignoredRollovers);
    if (!newIgnored.contains(key)) {
      newIgnored.add(key);
      _settings = UserSettingsModel(
         defaultSalary: _settings.defaultSalary,
         defaultStartDay: _settings.defaultStartDay,
         monthlyOverrides: _settings.monthlyOverrides,
         ignoredRollovers: newIgnored,
      );
      notifyListeners();
      
      // Persist
      await _firestoreService.updateSettings(userId!, {
        'ignoredRollovers': newIgnored
      });
    }
  }

  Future<void> resetData() async {
    if (userId == null) return;
    await _firestoreService.resetData(userId!);
  }
}

extension ListFilter<T> on List<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
