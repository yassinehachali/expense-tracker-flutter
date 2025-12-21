import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../data/models/expense_model.dart';
import '../data/models/category_model.dart';
import '../data/models/user_settings_model.dart';
import '../data/models/fixed_charge_model.dart';
import '../data/models/insurance_claim_model.dart';
import '../data/services/firestore_service.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../core/app_strings.dart';

class ExpenseProvider with ChangeNotifier {
  ExpenseProvider() {
    _loadLastViewed();
  }
  final FirestoreService _firestoreService = FirestoreService();
  String? userId;

  List<ExpenseModel> _expenses = [];
  List<CategoryModel> _categories = [];
  List<FixedChargeModel> _fixedCharges = [];
  List<InsuranceClaimModel> _insuranceClaims = [];
  final List<InsuranceClaimModel> _localPendingClaims = []; // Store offline creations here
  final Set<String> _localDeletedClaimIds = {}; // Store pending deletes to suppress "Zombie" reappearance

  // Settings State
  UserSettingsModel _settings = UserSettingsModel();
  UserSettingsModel get settings => _settings;
  
  // UI State
  int _selectedMonth = DateTime.now().month - 1; // 0-indexed (Jan=0, Dec=11)
  int _selectedYear = DateTime.now().year;
  String _filterType = 'all';

  // Streams
  StreamSubscription? _expensesSub;
  StreamSubscription? _settingsSub;
  StreamSubscription? _categoriesSub;
  StreamSubscription? _fixedChargesSub;
  StreamSubscription? _insuranceClaimsSub;

  List<InsuranceClaimModel> get insuranceClaims {
    // Merge Pending + Stream (Prefer Stream if ID exists)
    final streamIds = _insuranceClaims.map((c) => c.id).toSet();
    final visiblePending = _localPendingClaims.where((c) => !streamIds.contains(c.id)).toList();
    
    final combined = [...visiblePending, ..._insuranceClaims];
    
    // Filter out any locally deleted IDs (resolving the "Zombie Reappearance" issue)
    return combined.where((c) => !_localDeletedClaimIds.contains(c.id)).toList();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ExpenseModel> get expenses => _expenses;
  List<FixedChargeModel> get fixedCharges => _fixedCharges;
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
      
      // Update App Language
      if (_settings.language != null) {
        // Server has a preference, use it.
        AppStrings.setLanguage(_settings.language!);
      } else {
        // Server has no preference (new user/guest). 
        // Keep the current local preference (set by LoginScreen) and SAVE it to server.
        // This ensures the Login selection overrides the "default" state.
        _firestoreService.updateSettings(uid, {'language': AppStrings.language});
      }

      // Force refresh of any derived data
      notifyListeners();
    }, onError: (e) => print("Error loading settings: $e"));

    _categoriesSub = _firestoreService.getCategoriesStream(uid).listen((data) {
      _categories = data;
      notifyListeners();
    }, onError: (e) => print("Error loading categories: $e"));

    _fixedChargesSub = _firestoreService.getFixedChargesStream(uid).listen((data) {
      _fixedCharges = data;
      notifyListeners();
      _checkAndApplyAutoCharges(); // Check whenever definitions change
    }, onError: (e) => print("Error loading fixed charges: $e"));

    _insuranceClaimsSub = _firestoreService.getInsuranceClaimsStream(uid).listen((data) {
      _insuranceClaims = data;
      // Clean up pending items that have arrived in the stream
      final dataIds = data.map((c) => c.id).toSet();
      _localPendingClaims.removeWhere((c) => dataIds.contains(c.id));
      
      // Clean up pending deletes that have been confirmed (item is gone from stream)
      // If the ID is NOT in the stream, it is safe to stop tracking it as "pending delete"
      _localDeletedClaimIds.removeWhere((id) => !dataIds.contains(id));
      
      notifyListeners();
    }, onError: (e) => print("Error loading insurance claims: $e"));
  }
  
  void _cancelSubscriptions() {
    _expensesSub?.cancel();
    _settingsSub?.cancel();
    _categoriesSub?.cancel();
    _fixedChargesSub?.cancel();
    _insuranceClaimsSub?.cancel();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  void setMonth(int month) {
    _selectedMonth = month;
    _saveLastViewed();
    notifyListeners();
    _checkAndApplyAutoCharges(); // Check whenever cycle changes
  }

  void setYear(int year) {
    _selectedYear = year;
    _saveLastViewed();
    notifyListeners();
    _checkAndApplyAutoCharges(); // Check whenever cycle changes
  }

  Future<void> _loadLastViewed() async {
    final prefs = await SharedPreferences.getInstance();
    bool changed = false;
    if (prefs.containsKey('last_view_year')) {
      _selectedYear = prefs.getInt('last_view_year')!;
      changed = true;
    }
    if (prefs.containsKey('last_view_month')) {
      _selectedMonth = prefs.getInt('last_view_month')!;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> _saveLastViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_view_year', _selectedYear);
    await prefs.setInt('last_view_month', _selectedMonth);
  }

  void setFilterType(String type) {
    _filterType = type;
    notifyListeners();
  }

  List<ExpenseModel> get filteredExpenses {
    // Optimization: Calculate cycle boundary once
    final cutoff = currentCycleEnd.add(const Duration(days: 1)); // Start of next cycle

    List<ExpenseModel> result = _expenses.where((exp) {
      if (exp.excludeFromBalance) return false; // Hide past debts from main lists
      
      final d = DateTime.parse(exp.date);
      final inCycle = isInCurrentCycle(d);

      if (!inCycle && exp.type != 'loan') return false; 
      
      if (exp.type == 'loan') {
         // If filter is explicitly 'loan', show ALL loans (active and returned history)
         if (_filterType == 'loan') return true;
         
         // Fix: Only show loans that exist relative to this cycle (Date < NextCycleStart)
         // Prevents Future Loans from leaking into Past Months
         // Using 'cutoff' handles time components correctly (e.g. Last Day 23:59 is < Next Day 00:00)
         if (d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff)) return false; 
         
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
        
        // Add to list (will be sorted below)
        result.add(ExpenseModel(
          id: 'rollover_virtual', // Unique virtual ID
          amount: rollover,
          category: 'Rollover',
          date: currentCycleStart.toIso8601String(),
          type: 'rollover',
          description: 'Remaining Balance from ${Utils.getMonthName(prevMonth)}',
        ));
      }
    }

    // Sort Result (Including Rollover)
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

    return result;
  }

  // --- Rollover Logic ---
  
  double _calculateMonthlyBalance(int year, int month, {int depth = 0}) {
    if (depth > 24) return 0.0; // Infinite loop safety

    final settings = _getEffectiveSettings(year, month);
    final start = getCycleStartDate(year, month);
    
    // Determine end of this cycle (Start of next cycle - 1 sec)
    var nextM = month + 1;
    var nextY = year;
    if (nextM > 11) { nextM = 0; nextY++; }
    final end = getCycleStartDate(nextY, nextM).subtract(const Duration(seconds: 1));

    final monthlyExpenses = _expenses.where((exp) {
       final d = DateTime.parse(exp.date);
       // Check range
       return (d.isAfter(start) || d.isAtSameMomentAs(start)) && 
              (d.isBefore(end) || d.isAtSameMomentAs(end));
    });

    double income = settings.salary;
    double spent = 0;
    
    for (var e in monthlyExpenses) {
       if (e.excludeFromBalance) continue; // Skip if excluded
       if (e.type == 'income') income += e.amount;
       else if (e.type == 'rollover') {} // Skip virtual if present
       else spent += e.amount;
    }

    // Check if THIS month accepted a rollover from previous
    final key = "$year-${month + 1}";
    if (_settings.acceptedRollovers.contains(key)) {
        var prevM = month - 1;
        var prevY = year;
        if (prevM < 0) { prevM = 11; prevY--; }
        
        // Add previous balance to income recursion
        income += _calculateMonthlyBalance(prevY, prevM, depth: depth + 1);
    }

    final balance = income - spent;
    return balance > 0 ? balance : 0.0;
  }

  double get _currentRolloverAmount {
    int prevMonth = _selectedMonth - 1;
    int prevYear = _selectedYear;
    if (prevMonth < 0) {
      prevMonth = 11;
      prevYear--;
    }
    
    final currentKey = "$_selectedYear-${_selectedMonth + 1}";
    
    // If NOT accepted, we show NOTHING (0.0).
    if (!_settings.acceptedRollovers.contains(currentKey)) {
       return 0.0;
    }
    
    return _calculateMonthlyBalance(prevYear, prevMonth);
  }

  Map<String, double> get dashboardStats {
    final cycleExpenses = _expenses.where((exp) {
      return isInCurrentCycle(DateTime.parse(exp.date));
    });

    double totalSpent = 0;
    double totalIncome = 0;
    double totalBorrowed = 0;

    for (var curr in cycleExpenses) {
       if (curr.excludeFromBalance) continue; // Skip excluded transactions (e.g. past debts) from Current Balance stats

       if (curr.type == 'income') {
         totalIncome += curr.amount;
       } else if (curr.type == 'loan') {
         totalSpent += curr.amount;
       } else if (curr.type == 'borrow') {
         totalBorrowed += curr.amount;
       } else {
         totalSpent += curr.amount;
       }
    }

    final rollover = _currentRolloverAmount;
    // Remaining = (Salary + Income + Rollover + Borrowed) - Spent
    final remaining = (currentCycleSalary + totalIncome + totalBorrowed + rollover) - totalSpent;

    return {
      'totalSpent': totalSpent,
      'totalIncome': totalIncome, 
      'totalBorrowed': totalBorrowed,
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
      if (curr.type == 'income' || curr.type == 'borrow') continue; // Borrowing is cash in, not spending

      if (curr.type == 'loan') {
        categoryMap['Lending'] = (categoryMap['Lending'] ?? 0) + curr.amount;
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
    
    // 1. Fetch OLD expense for diff calculation (before update)
    final oldExpense = _expenses.firstWhere((e) => e.id == expense.id, orElse: () => expense);
    
    await _firestoreService.updateExpense(userId!, expense.id, expense.toMap());

    // 2. Sync if this is a Repayment (Linked to a Loan)
    if (expense.relatedLoanId != null && expense.relatedLoanId!.isNotEmpty) {
       final diff = expense.amount - oldExpense.amount;
       if (diff.abs() > 0.01) {
          await _syncLoanRepayment(expense.relatedLoanId!, diff);
       }
    }

    // 3. Check if this expense is linked to an Insurance Claim and update it
    try {
      final linkedClaim = _insuranceClaims.firstWhere(
        (c) => c.relatedExpenseId == expense.id, 
        orElse: () => InsuranceClaimModel(id: '', userId: '', title: '', totalAmount: 0, date: '', status: '')
      );

      if (linkedClaim.id.isNotEmpty && linkedClaim.status == 'pending') {
         // Update the claim amount to match the new expense amount
         await _firestoreService.updateInsuranceClaim(userId!, linkedClaim.id, {
           'totalAmount': expense.amount,
         });
      }
    } catch (e) {
      print("Error syncing insurance claim: $e");
    }
  }

  /// Helper to sync repayment changes back to the original loan
  Future<void> _syncLoanRepayment(String loanId, double deltaReturnedAmount) async {
    if (userId == null) return;

    ExpenseModel? loan;
    
    // 1. Try to find the loan in memory first (Fast)
    final loanIndex = _expenses.indexWhere((e) => e.id == loanId);
    if (loanIndex != -1) {
       loan = _expenses[loanIndex];
    } else {
       // 2. If not in memory (e.g. historical/filtered), fetch from Firestore
       try {
          final doc = await _firestoreService.getExpense(userId!, loanId);
          if (doc != null) {
            loan = doc;
          }
       } catch (e) {
          print("Error fetching parent loan for sync: $e");
       }
    }

    if (loan != null) {
       final newReturned = loan.returnedAmount + deltaReturnedAmount;
       final isReturned = newReturned >= loan.amount; 
       
       // Update Firestore
       await _firestoreService.updateExpense(userId!, loan.id, {
         'returnedAmount': newReturned,
         'isReturned': isReturned,
       });
    } else {
       print("Warning: Parent Loan $loanId not found (Memory or DB) to sync repayment.");
    }
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

  Future<void> repayBorrowing(ExpenseModel loan, double amountToRepay) async {
    if (userId == null) return;
    
    final newReturned = loan.returnedAmount + amountToRepay;
    final isFullyReturned = newReturned >= loan.amount;

    // 1. Update the Borrow Transaction
    await _firestoreService.updateExpense(userId!, loan.id, {
      'returnedAmount': newReturned,
      'isReturned': isFullyReturned,
    });

    // 2. Create Repayment Transaction
    // If I Lent (loan), receiving repayment is INCOME.
    // If I Borrowed (borrow), paying back is EXPENSE.
    final isLending = loan.type == 'loan';
    
    final type = isLending ? 'income' : 'expense';
    final category = isLending ? 'Loan Repayment' : 'Borrow Repayment';
    
    final personName = loan.loanee ?? loan.description;
    final prefix = isFullyReturned ? 'Repayment' : 'Partial Repayment';
    final desc = isLending ? '$prefix from $personName' : '$prefix to $personName';

    final expenseTx = ExpenseModel(
      id: '',
      amount: amountToRepay,
      category: category, 
      date: DateTime.now().toIso8601String(),
      type: type,
      description: desc,
      relatedLoanId: loan.id, // Link to loan
    );
    await addExpense(expenseTx);
  }

  // --- Fixed Charges Logic ---

  Future<void> addFixedCharge(FixedChargeModel charge) async {
    if (userId == null) return;
    await _firestoreService.addFixedCharge(userId!, charge);
  }

  Future<void> updateFixedCharge(FixedChargeModel charge) async {
    if (userId == null) return;
    
    // Check previous state to see if we toggled Auto -> Manual
    final oldCharge = _fixedCharges.firstWhere((c) => c.id == charge.id, orElse: () => charge);
    
    await _firestoreService.updateFixedCharge(userId!, charge);

    // If it WAS Auto and is NOW Manual, we should remove the auto-generated expense for THIS cycle 
    // to give the user a "clean slate" as requested.
    if (oldCharge.isAutoApplied && !charge.isAutoApplied) {
       // Find the expense in current cycle
       final expenseToDelete = _expenses.firstWhere((exp) {
          return exp.originChargeId == charge.id && isInCurrentCycle(DateTime.parse(exp.date));
       }, orElse: () => ExpenseModel(id: '', amount: 0, category: '', description: '', date: '', type: ''));
       
       if (expenseToDelete.id.isNotEmpty) {
         print("Removing auto-generated expense ${expenseToDelete.id} because charge became manual.");
         await deleteExpense(expenseToDelete.id);
       }
    } else if (!oldCharge.isAutoApplied && charge.isAutoApplied) {
       // If toggled Manual -> Auto, maybe apply it immediately?
       _checkAndApplyAutoCharges();
    }
  }

  Future<void> deleteFixedCharge(String chargeId) async {
    if (userId == null) return;
    await _firestoreService.deleteFixedCharge(userId!, chargeId);

    // Also remove from current cycle if it exists
    // This supports the "Undo" use case where user adds then deletes.
    // We only touch the CURRENT cycle to preserve history.
    final expensesToDelete = _expenses.where((exp) {
      return exp.originChargeId == chargeId && isInCurrentCycle(DateTime.parse(exp.date));
    }).toList();

    for (var exp in expensesToDelete) {
      print("Deleting cleanup expense ${exp.id} for fixed charge $chargeId");
      await deleteExpense(exp.id);
    }
  }

  /// Checks if any AUTO fixed charges need to be applied to the CURRENT view cycle.
  /// Only applies if they don't already exist (deduplication via originChargeId).
  Future<void> _checkAndApplyAutoCharges() async {
    if (userId == null || _fixedCharges.isEmpty) return;

    // We check against the CURRENT selected month/year view.
    // If the user scrolls to a future month, this will auto-fill it!
    // If the user scrolls to a past month, it might back-fill if missing 
    // (though usually past months already have data).

    // 1. Filter for Auto Charges
    final autos = _fixedCharges.where((c) => c.isAutoApplied).toList();
    if (autos.isEmpty) return;

    // 2. Initial Setup
    final start = currentCycleStart;
    final end = currentCycleEnd;
    
    // Fix: Strictly prevent backfilling for ANY past cycle.
    // If the cycle has ended (end date is in the past), we do NOT auto-apply charges.
    // This allows users to delete charges from previous months without them regenerating.
    final now = DateTime.now();
    if (end.isBefore(now)) {
       return;
    }

    final targetMonth = DateTime(_selectedYear, _selectedMonth + 1); // For constructing dates

    for (var charge in autos) {
      // 3. Check if we already have an expense from this origin in this cycle
      final alreadyExists = _expenses.any((exp) {
        if (exp.originChargeId != charge.id) return false;
        // Double check date is within cycle range.
        // If we found one, we assume it's for this cycle.
        // We could be stricter but originChargeId check + current view context is usually enough for the "Auto Apply" logic
        final d = DateTime.parse(exp.date);
        return isInCurrentCycle(d);
      });

      if (!alreadyExists) {
        // CHECK DELAY LOGIC
        if (charge.delayedAutoPay) {
           final targetDate = _calculateChargeDate(_selectedYear, _selectedMonth, charge.dayOfMonth);
           final now = DateTime.now();
           // Compare just date parts to be precise, or just isBefore.
           // If today is 2nd, target is 3rd. isBefore -> true. Skip.
           // If today is 3rd. isBefore -> false (if time matches? usually now is later than midnight).
           // Let's strip time for safety.
           final today = DateTime(now.year, now.month, now.day);
           
           if (today.isBefore(targetDate)) {
             // Too early to pay
             continue;
           }
        }

        print("Applying Auto Charge: ${charge.name} for $_selectedMonth/$_selectedYear");
        await _applyChargeToCycle(charge, _selectedYear, _selectedMonth);
      }
    }
  }

  DateTime _calculateChargeDate(int year, int month, int dayOfMonth) {
    // Determine the likely date for this charge in the requested cycle (year, month).
    // Our cycles can be offset. 
    // Cycle for "January" (month=0) might start Dec 26.
    // If charge day is 5 -> Jan 5.
    // If charge day is 28 -> Dec 28.
    
    final s = _getEffectiveSettings(year, month);
    // Logic: 
    // If startOffset == -1 (Starts previous month)
    //   if day >= startDay -> Date is in Previous Month
    //   else -> Date is in Current Month
    // If startOffset == 0 (Starts same month)
    //   Date is in Current Month
    
    // Note: 'month' param is 0-indexed (0=Jan).
    // DateTime accepts month 1-12 usually or handles overflow 13 -> Jan Next Year.
    // Lets use 1-based month for variable m to be clear.
    
    int targetYear = year;
    int targetMonth = month + 1; // 1 = Jan
    
    if (s.monthOffset == -1) {
      if (dayOfMonth >= s.startDay) {
        // Belongs to previous month part of the cycle
        targetMonth = targetMonth - 1;
      }
    }
    // Handle year rollover if targetMonth became 0 (Dec prev year) or we incremented (not here but possible)
    if (targetMonth < 1) {
      targetMonth = 12;
      targetYear--;
    } else if (targetMonth > 12) {
      targetMonth = 1;
      targetYear++;
    }
    
    return DateTime(targetYear, targetMonth, dayOfMonth);
  }

  // Helper to check status for UI
  bool isChargeAppliedInCycle(String chargeId, int year, int month) {
    // We assume the provider is currently viewing [year, month] or we can't easily check without fetching.
    // But usually the UI asks for "Current View" context.
    // If year/month match _selected..., we use _expenses.
    
    // Simplification for UI: We only support checking against the LOADED expenses (Current View).
    // If user asks for next month data while viewing this month, we don't have it.
    // So we'll limit this check to the current view or assume the caller knows what they are doing.
    
    if (year != _selectedYear || month != _selectedMonth) {
      // We can't strictly check without data. Default to false or maybe we should only show status for current view?
      return false; 
    }

    return _expenses.any((exp) {
      if (exp.originChargeId != chargeId) return false;
      return isInCurrentCycle(DateTime.parse(exp.date));
    });
  }

  /// Manually apply charges (e.g. via UI button).
  /// Can apply [manualOnly] or all.
  /// [chargeId]: Optional, apply ONLY this specific charge (Manual Individual Apply)
  Future<void> applyFixedChargesToCycle(int year, int month, {bool manualOnly = false, String? chargeId}) async {
    List<FixedChargeModel> targets;
    
    if (chargeId != null) {
      targets = _fixedCharges.where((c) => c.id == chargeId).toList();
    } else {
      targets = _fixedCharges.where((c) => manualOnly ? !c.isAutoApplied : true).toList();
    }
    
    for (var charge in targets) {
       // Check duplication! 
       final alreadyExists = _expenses.any((exp) {
        if (exp.originChargeId != charge.id) return false;
        // Check if date is in target cycle. 
        // We really rely on 'isInCurrentCycle' logic which uses _selectedYear/Month.
        // If year/month passed here are NOT _selectedYear/Month, this check is flawed.
        // But the UI usually calls this for the current/next month view.
        
        // Let's match against the requested year/month params roughly
        // or rely on the fact that if we are applying to "Next Month", we assume we haven't loaded it?
        
        // Fix: If applying to Current View, use _expenses check.
        if (year == _selectedYear && month == _selectedMonth) {
           return isInCurrentCycle(DateTime.parse(exp.date));
        }
        
        // If applying to different month (e.g. Next Month), we probably don't have the data in _expenses 
        // unless we fetched it. So we might create a duplicate if we blindly add.
        // Risk: User applies to Next Month blindly.
        // For MVP: We only support checking duplicates for the ACTIVE view.
        return false; 
      });

      if (!alreadyExists) {
        await _applyChargeToCycle(charge, year, month);
      } else {
        print("Skipping ${charge.name}, already applied.");
      }
    }
  }

  Future<void> _applyChargeToCycle(FixedChargeModel charge, int year, int month) async {
    // Determine Date
    // logic: cycle start + (day - 1)? Or just day of month?
    // "dayOfMonth" usually means "5th of the month".
    // If cycle starts Dec 26 and ends Jan 25 (for Jan cycle).
    // Charge Day 5 -> Jan 5.
    // Charge Day 28 -> Dec 28.
    
    // We need to find the correct date within the cycle that matches 'dayOfMonth'.
    final start = getCycleStartDate(year, month);
    final end = start.add(Duration(days: 40)); // rough upper bound to find end
    // actually we have currentCycleEnd logic but parameterized.
    
    // Simplest approach:
    // If cycle is roughly "Month X", we target "Day Y of Month X".
    // If "Day Y" is outside cycle (e.g. cycle is Dec 26-Jan 25, target is Jan 28), it belongs to NEXT cycle?
    // User expectation for "Fixed Charge" is usually calendar month based or "Same date every month".
    // If I set "Rent on 1st", and my cycle is Jan 1 - Jan 31, date is Jan 1.
    // If cycle is Dec 26 - Jan 25. Rent on 1st is Jan 1. (Inside cycle).
    // If Rent on 28th. Dec 28 (Inside cycle). Jan 28 (Next cycle).
    
    // So for "Cycle M", we look for "Day D" that falls within "Cycle M".
    // 1. Try Month M, Day D. Check if in cycle.
    // 2. Try Month M-1, Day D. Check if in cycle.
    // 3. Try Month M+1, Day D. Check if in cycle.
    
    final s = _getEffectiveSettings(year, month);
    final cycleStart = DateTime(year, month + 1 + s.monthOffset, s.startDay);
    // End is not easily available without next settings.
    // But we know a cycle is approx 1 month.
    
    DateTime targetDate;
    
    // Candidate 1: The 'main' month (year, month+1)
    final candidate1 = DateTime(year, month + 1, charge.dayOfMonth);
    
    // Candidate 2: The 'previous' month (associated with offset starts)
    final candidate2 = DateTime(year, month, charge.dayOfMonth);
    
    // We need to see which one falls >= cycleStart
    // and < cycleStart + 1 month roughly.
    // Actually, we define cycle by [Start, NextStart).
    
    // Let's use simpler logic: 
    // Construct date using the SAME month logic as the cycle start?
    // If cycle starts Dec 26. "Month" is Jan.
    // If charge is Day 5. -> Jan 5.
    // If charge is Day 28. -> Dec 28.
    
    // Heuristic:
    // If charge.dayOfMonth < s.startDay: It's likely in the "Main" month (Jan).
    // If charge.dayOfMonth >= s.startDay: It's likely in the "Start" month (Dec).
    // Example: Start Dec 26. 
    // Day 5 < 26 -> Jan 5.
    // Day 26 >= 26 -> Dec 26.
    
    // Start Jan 1.
    // Day 5 >= 1 -> Jan 5.
    // This heuristic fails for StartDay=1.
    
    // Let's rely on standard logic:
    // "Target Month" = (month+1).
    // If s.monthOffset == -1 (Starts previous month).
    //   If day >= startDay -> Date is (year, month, day) // Dec
    //   Else -> Date is (year, month+1, day) // Jan
    // If s.monthOffset == 0 (Starts same month).
    //   Date is (year, month+1, day) // Jan (Careful of overlap if day < startDay? No, startDay usually 1)
    
    int y = year;
    int m = month + 1; // 1-12
    
    if (s.monthOffset == -1) {
       // Starts prev month (e.g. Dec 26 for Jan)
       if (charge.dayOfMonth >= s.startDay) {
         m = m - 1; 
       }
    } else {
       // Starts same month (e.g. Jan 1 for Jan)
       // Usually means day is in this month.
       // What if charge is Day 31 and month has 30? DateTime handles overflow automatically (Oct 31 -> Nov 1)
       // We accept that.
    }
    
    if (m < 1) { m = 12; y--; }
    if (m > 12) { m = 1; y++; }
    
    targetDate = DateTime(y, m, charge.dayOfMonth);
    
    // Create Expense
    final newExpense = ExpenseModel(
      id: '', // Firestore gen
      amount: charge.amount,
      category: charge.category,
      description: charge.name, // "Rent"
      date: targetDate.toIso8601String(),
      type: 'expense',
      originChargeId: charge.id,
    );
    
    await addExpense(newExpense);
  }

  Future<void> deleteExpense(String id) async {
    if (userId == null) return;
    
    // Check if it's a linked repayment before deleting
    final exp = _expenses.firstWhere((e) => e.id == id, orElse: () => ExpenseModel(id: '', amount: 0, category: '', description: '', date: '', type: ''));
    
    if (exp.id.isNotEmpty && exp.relatedLoanId != null && exp.relatedLoanId!.isNotEmpty) {
       // Revert the repayment amount from the loan
       await _syncLoanRepayment(exp.relatedLoanId!, -exp.amount);
    }

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
    
    // Remove from accepted if present
    final newAccepted = List<String>.from(_settings.acceptedRollovers);
    newAccepted.remove(key);

    if (!newIgnored.contains(key)) {
      newIgnored.add(key);
    }
      
    _settings = UserSettingsModel(
       defaultSalary: _settings.defaultSalary,
       defaultStartDay: _settings.defaultStartDay,
       monthlyOverrides: _settings.monthlyOverrides,
       ignoredRollovers: newIgnored,
       acceptedRollovers: newAccepted,
       language: _settings.language,
    );
    notifyListeners();
      
    // Persist
    await _firestoreService.updateSettings(userId!, {
      'ignoredRollovers': newIgnored,
      'acceptedRollovers': newAccepted,
    });
  }

  Future<void> acceptRollover(int year, int month) async {
    if (userId == null) return;
    final key = "$year-${month + 1}";
    
    final newAccepted = List<String>.from(_settings.acceptedRollovers);
    if (!newAccepted.contains(key)) {
      newAccepted.add(key);
      
      // Ensure it's not in ignored
      final newIgnored = List<String>.from(_settings.ignoredRollovers);
      newIgnored.remove(key);

      _settings = UserSettingsModel(
         defaultSalary: _settings.defaultSalary,
         defaultStartDay: _settings.defaultStartDay,
         monthlyOverrides: _settings.monthlyOverrides,
         ignoredRollovers: newIgnored,
         acceptedRollovers: newAccepted,
         language: _settings.language,
      );
      notifyListeners();
      
      await _firestoreService.updateSettings(userId!, {
        'ignoredRollovers': newIgnored,
        'acceptedRollovers': newAccepted,
      });
    }
  }

  /// Calculates potential rollover for the current selected month WITHOUT filtering by accepted/ignored status.
  /// Used to determine if we should prompt the user.
  double get pendingRolloverAmount {
    int prevMonth = _selectedMonth - 1;
    int prevYear = _selectedYear;
    if (prevMonth < 0) {
      prevMonth = 11;
      prevYear--;
    }
    
    final key = "$_selectedYear-${_selectedMonth + 1}";
    
    // If already accepted or ignored, it is NOT pending.
    if (_settings.acceptedRollovers.contains(key) || _settings.ignoredRollovers.contains(key)) {
      return 0.0;
    }

    // Calculate recursive balance of previous month
    return _calculateMonthlyBalance(prevYear, prevMonth);
  }

  Future<void> resetData() async {
    if (userId == null) return;
    await _firestoreService.resetData(userId!);
  }

  Future<void> setLanguage(String lang) async {
    if (userId == null) return;
    await _firestoreService.updateSettings(userId!, {'language': lang});
    // AppStrings will update via stream, but we can optimistically set it too
    AppStrings.setLanguage(lang);
    notifyListeners();
  }

  // --- Insurance Logic ---

  Future<void> addInsuranceClaim({
    required String title,
    required double amount,
    required String date,
  }) async {
    if (userId == null) return;

    // 1. Generate IDs Synchronously
    final expId = _firestoreService.getNewExpenseId(userId!);
    final claimId = _firestoreService.getNewInsuranceClaimId(userId!);

    // 2. Create Objects with these IDs
    final newExpense = ExpenseModel(
      id: expId,
      amount: amount,
      category: 'Health',
      description: "$title (Insurance Pending)",
      date: date,
      type: 'expense',
    );
    
    final claim = InsuranceClaimModel(
      id: claimId,
      userId: userId!,
      title: title,
      totalAmount: amount,
      date: date,
      status: 'pending',
      relatedExpenseId: expId,
      refundAmount: 0,
    );

    // 3. Optimistic Update: Add to LOCAL PENDING list & Notify IMMEDIATELY
    // This runs synchronously, ensuring UI updates before any potential network blocking
    _localPendingClaims.add(claim);
    notifyListeners();
    
    // 4. Perform Firestore Writes (These might wait for server ack, but UI is already happy)
    await _firestoreService.setExpense(userId!, newExpense);
    await _firestoreService.setInsuranceClaim(userId!, claim);
  }

  Future<void> editInsuranceClaim(InsuranceClaimModel claim, String newTitle, double newAmount, String newDate) async {
    if (userId == null) return;

    // 1. Create Updated Claim Object (Optimistic)
    final updatedClaim = InsuranceClaimModel(
      id: claim.id,
      userId: claim.userId,
      title: newTitle,
      totalAmount: newAmount,
      refundAmount: claim.refundAmount,
      date: newDate,
      status: claim.status,
      relatedExpenseId: claim.relatedExpenseId,
    );

    // 2. Optimistic UI Update: Replace in lists & Notify
    final index = _insuranceClaims.indexWhere((c) => c.id == claim.id);
    if (index != -1) {
      _insuranceClaims[index] = updatedClaim;
    }
    final pendingIndex = _localPendingClaims.indexWhere((c) => c.id == claim.id);
    if (pendingIndex != -1) {
      _localPendingClaims[pendingIndex] = updatedClaim;
    }
    notifyListeners(); // UI Updates Instantly

    // 3. Perform Firestore Writes (Background)
    await _firestoreService.updateInsuranceClaim(userId!, claim.id, {
      'title': newTitle,
      'totalAmount': newAmount,
      'date': newDate,
    });

    // 4. Update the Linked Expense (Background + Optimistic)
    if (claim.relatedExpenseId != null && claim.relatedExpenseId!.isNotEmpty) {
       try {
         final originalIndex = _expenses.indexWhere((e) => e.id == claim.relatedExpenseId);
         if (originalIndex != -1) {
            final original = _expenses[originalIndex];
            
            String currentDesc = original.description;
            String suffix = "";
            if (currentDesc.contains("(Insurance Pending)")) suffix = " (Insurance Pending)";
            else if (currentDesc.contains("(Insurance Repaid)")) suffix = " (Insurance Repaid)";
            
            final updatedExpense = original.copyWith(
                description: "$newTitle$suffix",
                amount: newAmount,
            );

            // Optimistic Update of Expense List
            _expenses[originalIndex] = updatedExpense.copyWith(date: newDate); // Local update
            notifyListeners(); // Ensure UI sees expense change

            final updateMap = updatedExpense.toMap();
            updateMap['date'] = newDate;

            await _firestoreService.updateExpense(userId!, original.id, updateMap);
         }

       } catch (e) {
         print("Could not find or update related expense during claim edit: $e");
       }
    }
  }

  Future<void> settleInsuranceClaim(InsuranceClaimModel claim, double refundAmount, {String? date}) async {
    if (userId == null) return;

    // 1. Generate Refund ID Synchronously
    final refundId = _firestoreService.getNewExpenseId(userId!);
    final refundDate = date ?? DateTime.now().toIso8601String();

    final incomeTx = ExpenseModel(
      id: refundId,
      amount: refundAmount,
      category: 'Insurance Refund', 
      description: "Refund for ${claim.title}",
      date: refundDate,
      type: 'income',
    );

    // 2. Create Updated Claim Object (Paid)
    final paidClaim = InsuranceClaimModel(
      id: claim.id,
      userId: claim.userId,
      title: claim.title,
      totalAmount: claim.totalAmount,
      refundAmount: refundAmount,
      date: claim.date,
      status: 'paid',
      relatedExpenseId: claim.relatedExpenseId,
    );

    // 3. Optimistic UI Update: Replace in lists & Notify
    // Handle Main List
    final index = _insuranceClaims.indexWhere((c) => c.id == claim.id);
    if (index != -1) {
      _insuranceClaims[index] = paidClaim;
    }
    // Handle Pending List (if it's still there)
    final pendingIndex = _localPendingClaims.indexWhere((c) => c.id == claim.id);
    if (pendingIndex != -1) {
      _localPendingClaims[pendingIndex] = paidClaim;
    }
    
    notifyListeners(); // UI updates to "History" instantly

    // 4. Perform Firestore Writes (Background)
    // Add Refund (using set for consistency)
    await _firestoreService.setExpense(userId!, incomeTx);
    
    // Update Claim Status
    await _firestoreService.updateInsuranceClaim(userId!, claim.id, {
      'status': 'paid',
      'refundAmount': refundAmount,
    });

    // 5. Update Original Expense Description (if linked)
    if (claim.relatedExpenseId != null && claim.relatedExpenseId!.isNotEmpty) {
       try {
         final original = _expenses.firstWhere((e) => e.id == claim.relatedExpenseId);
         String baseDesc = original.description.replaceAll("(Insurance Pending)", "").trim();
         final newDesc = "$baseDesc (Insurance Repaid)";
         
         await _firestoreService.updateExpense(userId!, original.id, {
           'description': newDesc
         });
       } catch (e) {
         print("Could not find or update related expense during claim edit: $e");
       }
    }
  }

  
  Future<void> deleteInsuranceClaim(String claimId) async {
    if (userId == null) return;

    // 1. Find the claim to get relatedExpenseId (Check both lists)
    InsuranceClaimModel? claimToDelete;
    
    // Check local suppression
    if (_localDeletedClaimIds.contains(claimId)) {
        // Already marked for deletion
        return; 
    }
    
    // Check main list first
    final index = _insuranceClaims.indexWhere((c) => c.id == claimId);
    if (index != -1) {
      claimToDelete = _insuranceClaims[index];
      // Do NOT remove from _insuranceClaims directly since it is stream-managed.
      // Instead, mark as locally deleted to suppress it.
       _localDeletedClaimIds.add(claimId);
    }
    
    // Check pending list
    final pendingIndex = _localPendingClaims.indexWhere((c) => c.id == claimId);
    if (pendingIndex != -1) {
      claimToDelete = _localPendingClaims[pendingIndex];
      _localPendingClaims.removeAt(pendingIndex);
      // CRITICAL: Also mark as deleted, because the "Add" op might still be queued in Firestore.
      // When it syncs, the stream will return this ID, and we must be ready to suppress it.
      _localDeletedClaimIds.add(claimId);
    }
    
    // Fallback: If found neither in memory nor pending, but user passed ID, add to suppression just in case
    // (Optimization: Only if we suspect it might come from stream later)
    if (claimToDelete == null) {
       _localDeletedClaimIds.add(claimId);
    }
    
    if (claimToDelete == null) {
      // Fallback to ID delete if not found locally
      await _firestoreService.deleteInsuranceClaim(userId!, claimId);
      return;
    }

    // 2. Optimistic UI Update: Remove Linked Expense Locally (BEFORE AWAIT)
    if (claimToDelete.relatedExpenseId != null && claimToDelete.relatedExpenseId!.isNotEmpty) {
      final relatedId = claimToDelete.relatedExpenseId!;
      // Optimistic Removal from Expenses List
      _expenses.removeWhere((e) => e.id == relatedId);
    } 
    
    notifyListeners(); // UI Updates Instantly (Both lists updated)

    // 3. Perform Firestore Writes (Background)
    
    // Delete the Claim
    await _firestoreService.deleteInsuranceClaim(userId!, claimId);
    
    // Delete the Linked Expense
    if (claimToDelete.relatedExpenseId != null && claimToDelete.relatedExpenseId!.isNotEmpty) {
      await _firestoreService.deleteExpense(userId!, claimToDelete.relatedExpenseId!);
    }
  }


}

extension ListFilter<T> on List<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
