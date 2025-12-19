import 'dart:async';
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
  final FirestoreService _firestoreService = FirestoreService();
  String? userId;

  List<ExpenseModel> _expenses = [];
  List<CategoryModel> _categories = [];
  List<FixedChargeModel> _fixedCharges = [];
  List<InsuranceClaimModel> _insuranceClaims = [];
  
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

  List<InsuranceClaimModel> get insuranceClaims => _insuranceClaims;

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
      AppStrings.setLanguage(_settings.language);
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
    notifyListeners();
    _checkAndApplyAutoCharges(); // Check whenever cycle changes
  }

  void setYear(int year) {
    _selectedYear = year;
    notifyListeners();
    _checkAndApplyAutoCharges(); // Check whenever cycle changes
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
    final currentKey = "$_selectedYear-${_selectedMonth + 1}";
    // print("DEBUG: Rollover Check Key: $currentKey, Ignored List: ${_settings.ignoredRollovers}");
    if (_settings.ignoredRollovers.contains(currentKey)) {
      // print("DEBUG: Rollover IGNORED for $currentKey");
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
    double totalBorrowed = 0;

    for (var curr in cycleExpenses) {
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
    await _firestoreService.updateExpense(userId!, expense.id, expense.toMap());

    // Check if this expense is linked to an Insurance Claim and update it
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
         // We could also sync the title/date if we wanted, but amount is critical.
      }
    } catch (e) {
      print("Error syncing insurance claim: $e");
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

    // 2. Create Repayment Expense (deducts from balance)
    final expenseTx = ExpenseModel(
      id: '',
      amount: amountToRepay,
      category: 'Borrow Repayment', // Or just 'Repayment'
      date: DateTime.now().toIso8601String(),
      type: 'expense',
      description: 'Repayment to ${loan.loanee ?? loan.description}', // "Repayment to John"
      // User required 'Hand Coins' icon. 
      // Note: Category icon is determined by name. 
      // We should probably add 'Borrow Repayment' to default categories OR handle it visually.
      // But ExpenseModel doesn't store icon directly, it relies on category.
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

    // 1. Create the Expense (User pays upfront)
    final newExpense = ExpenseModel(
      id: '',
      amount: amount,
      category: 'Health',
      description: "$title (Insurance Pending)",
      date: date,
      type: 'expense',
    );
    
    // Get Ref ID.
    final expRef = await _firestoreService.addExpense(userId!, newExpense);
    
    // 2. Create the Claim
    final claim = InsuranceClaimModel(
      id: '',
      userId: userId!,
      title: title,
      totalAmount: amount,
      date: date,
      status: 'pending',
      relatedExpenseId: expRef,
      refundAmount: 0,
    );
    
    await _firestoreService.addInsuranceClaim(userId!, claim);
  }

  Future<void> editInsuranceClaim(InsuranceClaimModel claim, String newTitle, double newAmount, String newDate) async {
    if (userId == null) return;

    // 1. Update the Claim
    await _firestoreService.updateInsuranceClaim(userId!, claim.id, {
      'title': newTitle,
      'totalAmount': newAmount,
      'date': newDate,
    });

    // 2. Update the Linked Expense
    if (claim.relatedExpenseId != null && claim.relatedExpenseId!.isNotEmpty) {
       try {
         final original = _expenses.firstWhere((e) => e.id == claim.relatedExpenseId);
         
         // Preserve description suffix if exists
         String currentDesc = original.description;
         String suffix = "";
         if (currentDesc.contains("(Insurance Pending)")) suffix = " (Insurance Pending)";
         else if (currentDesc.contains("(Insurance Repaid)")) suffix = " (Insurance Repaid)";
         
         final updatedExpense = original.copyWith(
            description: "$newTitle$suffix",
            amount: newAmount,
            // Date logic: usually expense date matches claim date
            // We can update it or keep original. Let's update it to stay perfectly synced.
         );
         
         // We construct the map manually to include date update if copyWith doesn't handle it fully or we want explicit control
         final updateMap = updatedExpense.toMap();
         updateMap['date'] = newDate;

         await _firestoreService.updateExpense(userId!, original.id, updateMap);

       } catch (e) {
         print("Could not find or update related expense during claim edit: $e");
       }
    }
  }

  Future<void> settleInsuranceClaim(InsuranceClaimModel claim, double refundAmount, {String? date}) async {
    if (userId == null) return;

    // 1. Create Refund Income
    final incomeTx = ExpenseModel(
      id: '',
      amount: refundAmount,
      category: 'Insurance Refund', 
      description: "Refund for ${claim.title}",
      date: date ?? DateTime.now().toIso8601String(),
      type: 'income',
    );
    await addExpense(incomeTx);

    // 2. Update Claim Status
    await _firestoreService.updateInsuranceClaim(userId!, claim.id, {
      'status': 'paid',
      'refundAmount': refundAmount,
    });

    // 3. Update Original Expense Description (if linked)
    if (claim.relatedExpenseId != null && claim.relatedExpenseId!.isNotEmpty) {
       // Ideally we should fetch it first to preserve other fields, but we don't have a direct 'getExpense' in service easily exposed here 
       // or we'd have to find it in _expenses list.
       try {
         final original = _expenses.firstWhere((e) => e.id == claim.relatedExpenseId);
         // Replace "(Insurance Pending)" with "(Insurance Repaid)" or append if missing
         String baseDesc = original.description.replaceAll("(Insurance Pending)", "").trim();
         final newDesc = "$baseDesc (Insurance Repaid)";
         
         final updatedMap = original.toMap();
         updatedMap['description'] = newDesc; // Update description
         
         await _firestoreService.updateExpense(userId!, original.id, updatedMap);
       } catch (e) {
         print("Could not find or update related expense: $e");
       }
    }
  }
  
  Future<void> deleteInsuranceClaim(String claimId) async {
    if (userId == null) return;
    await _firestoreService.deleteInsuranceClaim(userId!, claimId);
  }
}

extension ListFilter<T> on List<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
