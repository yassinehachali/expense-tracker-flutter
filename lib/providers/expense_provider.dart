import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../data/models/expense_model.dart';
import '../data/models/event_model.dart'; // Added
import '../data/models/category_model.dart';
import '../data/models/user_settings_model.dart';
import '../data/models/fixed_charge_model.dart';
import '../data/models/insurance_claim_model.dart';
import '../data/models/beneficiary_model.dart';
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
  List<BeneficiaryModel> _beneficiaries = [];
  List<EventModel> _events = []; // Added
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
  StreamSubscription? _beneficiariesSub;
  StreamSubscription? _eventsSub; // Added

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
  
  // Privacy Mode (Global)
  bool _isPrivacyEnabled = true; // Default visible
  bool get isPrivacyEnabled => _isPrivacyEnabled;
  
  void togglePrivacy() {
    _isPrivacyEnabled = !_isPrivacyEnabled;
    notifyListeners();
    _savePrivacyPreference();
  }

  Future<void> _savePrivacyPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_privacy_enabled', _isPrivacyEnabled);
  }

  List<ExpenseModel> get expenses => _expenses;
  List<FixedChargeModel> get fixedCharges => _fixedCharges;
  List<BeneficiaryModel> get beneficiaries => _beneficiaries;
  List<EventModel> get events => _events; // Added
  List<CategoryModel> get categories {
    final Map<String, CategoryModel> uniqueCategories = {};
    
    // 1. Add Defaults with Implicit Order
    for (int i = 0; i < DEFAULT_CATEGORIES.length; i++) {
      final map = DEFAULT_CATEGORIES[i];
      // We assume defaults have order = index
      final c = CategoryModel.fromMap({...map, 'order': i});
      uniqueCategories[c.name] = c;
    }
    
    // 2. Override with DB Categories (which hold the persisted order)
    for (var c in _categories) {
       uniqueCategories[c.name] = c;
    }
    
    // 3. Sort
    final list = uniqueCategories.values.toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (userId == null) return;
    
    // 1. Get current list (Hybrid of Defaults + DB)
    final list = categories; 
    
    // 2. Perform Reorder
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    
    // 3. Re-assign 'order' and create full list to persist
    final List<CategoryModel> materializedList = [];
    for (int i = 0; i < list.length; i++) {
       final old = list[i];
       materializedList.add(CategoryModel(
         name: old.name,
         color: old.color,
         icon: old.icon,
         order: i, 
       ));
    }
    
    // 4. Update Local & Remote
    _categories = materializedList;
    notifyListeners();
    
    await _firestoreService.updateCategoryList(userId!, materializedList);
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

  // Public accessor for specific month salary
  double getSalaryForMonth(int year, int month) {
    return _getEffectiveSettings(year, month).salary;
  }
  
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

      // Update App Currency
       Utils.setCurrency(_settings.currency ?? 'MAD'); // Default to MAD if null

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
    
    _beneficiariesSub = _firestoreService.getBeneficiaries(uid).listen((data) {
      _beneficiaries = data;
      notifyListeners();
    }, onError: (e) => print("Error loading beneficiaries: $e"));

    _eventsSub = _firestoreService.getEventsStream(uid).listen((data) {
      _events = data;
      notifyListeners();
    }, onError: (e) => print("Error loading events: $e"));
  }
  
  void _cancelSubscriptions() {
    _expensesSub?.cancel();
    _settingsSub?.cancel();
    _categoriesSub?.cancel();
    _fixedChargesSub?.cancel();
    _insuranceClaimsSub?.cancel();
    _beneficiariesSub?.cancel();
    _eventsSub?.cancel();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  Future<void> updateCurrency(String currencyCode) async {
    if (userId == null) return;
    await _firestoreService.updateSettings(userId!, {'currency': currencyCode});
    // The stream will trigger and update Utils via _settingsSub
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
    if (prefs.containsKey('is_privacy_enabled')) {
      _isPrivacyEnabled = prefs.getBool('is_privacy_enabled')!;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> _saveLastViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_view_year', _selectedYear);
    await prefs.setInt('last_view_month', _selectedMonth);
  }


  String? _filterCategory; // null = no category filter

  // ... (Other Setters)

  void setFilterType(String type) {
    _filterType = type;
    _filterCategory = null; // Reset category when changing main filter type
    notifyListeners();
  }

  void setFilterCategory(String? category) {
    _filterCategory = category;
    notifyListeners();
  }
  
  String? get filterCategory => _filterCategory;

  List<ExpenseModel> get filteredExpenses {
    // Optimization: Calculate cycle boundary once
    final cutoff = currentCycleEnd.add(const Duration(days: 1)); // Start of next cycle

    List<ExpenseModel> result = _expenses.where((exp) {
      if (exp.excludeFromBalance) return false; // Hide past debts from main lists
      
      final d = DateTime.parse(exp.date);
      final inCycle = isInCurrentCycle(d);

      if (!inCycle && exp.type != 'loan') return false; 
      
      if (_filterType == 'expense') {
        return inCycle && (exp.type == 'expense' || exp.type == null);
      }
      if (_filterType == 'income') {
        return inCycle && exp.type == 'income';
      }
      // Strict cycle check for EVERYTHING (including loans)
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
    
    // Category Filter
    if (_filterCategory != null) {
      result = result.where((e) => e.category == _filterCategory).toList();
    }
    
    // Inject Rollover (only for 'all' or specific view logic)
    
    // Inject Rollover (only for 'all' or specific view logic)
    // User wants to see it as a transaction.
    if ((_filterType == 'all' || _filterType == 'income') && _filterCategory == null) { // Maybe show in income/all?
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

  // Public accessor for specific month rollover
  double getRolloverForMonth(int year, int month) {
    int prevMonth = month - 1;
    int prevYear = year;
    if (prevMonth < 0) {
      prevMonth = 11;
      prevYear--;
    }
    
    final currentKey = "$year-${month + 1}";
    if (!_settings.acceptedRollovers.contains(currentKey)) {
        // If not accepted for this specific month, it's 0 (unless we want to show 'Potential'?)
        // User asked for "Using remaining balance of month before".
        // Usually we respect the "Rollover Accepted" flag. 
        // If they didn't accept it, it shouldn't be part of the "Starting Balance" for the new month essentially.
        return 0.0;
    }
    return _calculateMonthlyBalance(prevYear, prevMonth);
  }

  double get totalIncome {
    // Only Income + Borrowing (Cash In)
    // Rollover is separate concept, usually added to balance directly or treated as income.
    // Here we sum 'income' + 'borrow' types.
    // EXCLUDE legacy transactions from Borrowing.
    
    // Note: Borrowings are "Cash In" so they increase wallet balance.
    return _expenses
      .where((e) => isInCurrentCycle(DateTime.parse(e.date)))
      .where((e) => e.type == 'income' || (e.type == 'borrow' && !e.excludeFromBalance))
      .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get totalExpenses {
    // Expense + Lending (Cash Out)
    // EXCLUDE legacy transactions from Lending.
    
    // Note: Lending is "Cash Out" so it decreases wallet balance.
    return _expenses
      .where((e) => isInCurrentCycle(DateTime.parse(e.date)))
      .where((e) => e.type == 'expense' || (e.type == 'loan' && !e.excludeFromBalance))
      .fold(0.0, (sum, e) => sum + e.amount);
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

      // Event Handling: If expense belongs to an event, we group it under the Event Name
      if (curr.eventId != null && curr.eventId!.isNotEmpty) {
         final event = _events.firstWhere((e) => e.id == curr.eventId, orElse: () => EventModel(id: '', userId: '', name: 'Unknown Event', lastUpdated: ''));
         // Use "Event: Name" or just "Name" (e.g. "Trip to Marrakesh")
         // To avoid collision with Categories, maybe prefix? User wants "Trip..."
         final key = event.name; 
         categoryMap[key] = (categoryMap[key] ?? 0) + curr.amount;
      } 
      else if (curr.type == 'loan') {
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

    // Event Aggregation Logic
    if (expense.eventId != null && expense.eventId!.isNotEmpty) {
      final eventIndex = _events.indexWhere((e) => e.id == expense.eventId);
      if (eventIndex != -1) {
        final event = _events[eventIndex];
        final updatedEvent = event.copyWith(
          totalAmount: event.totalAmount + expense.amount,
          lastUpdated: DateTime.now().toIso8601String(),
        );
        _events[eventIndex] = updatedEvent;
        notifyListeners();
        await updateEvent(updatedEvent);
      }
    }
  }
  
  Future<void> updateExpense(ExpenseModel expense) async {
    if (userId == null) return;
    
    // 1. Fetch OLD expense for diff calculation (before update)
    final oldExpense = _expenses.firstWhere((e) => e.id == expense.id, orElse: () => expense);
    
    await _firestoreService.updateExpense(userId!, expense.id, expense.toMap());

    // --- EVENT LOGIC START ---
    // Case A: Amount changed within same event
    if (oldExpense.eventId == expense.eventId && expense.eventId != null) {
       final diff = expense.amount - oldExpense.amount;
       if (diff != 0) {
         await _adjustEventTotal(expense.eventId!, diff);
       }
    }
    // Case B: Event Changed (Moved from Event A to Event B)
    else if (oldExpense.eventId != expense.eventId) {
       // Remove from Old (if exists)
       if (oldExpense.eventId != null) {
         await _adjustEventTotal(oldExpense.eventId!, -oldExpense.amount);
       }
       // Add to New (if exists)
       if (expense.eventId != null) {
         await _adjustEventTotal(expense.eventId!, expense.amount);
       }
    }
    // --- EVENT LOGIC END ---

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

  // --- Beneficiaries Logic ---

  Future<void> addBeneficiary(BeneficiaryModel beneficiary) async {
    if (userId == null) return;
    
    // Duplicate Check (Case-Insensitive)
    final normalize = (String s) => s.trim().toLowerCase();
    if (_beneficiaries.any((b) => normalize(b.name) == normalize(beneficiary.name))) {
       throw Exception("Beneficiary '${beneficiary.name}' already exists.");
    }

    await _firestoreService.addBeneficiary(userId!, beneficiary);
  }

  Future<void> deleteBeneficiary(String beneficiaryId) async {
    if (userId == null) return;
    await _firestoreService.deleteBeneficiary(userId!, beneficiaryId);
  }

  Future<void> migrateCurrentLoansToBeneficiaries() async {
    if (userId == null) return;
    
    final normalize = (String s) => s.trim().toLowerCase();
    final existingNames = _beneficiaries.map((b) => normalize(b.name)).toSet();
    final Set<String> newNames = {};

    // Scan all expenses (borrow/loan)
    for (var exp in _expenses) {
       if (exp.type == 'loan' || exp.type == 'borrow') {
          // loanee field or fallback to description (legacy)
          String? name = exp.loanee;
          if (name == null || name.isEmpty) {
             // Heuristic: If description is short and looks like a name? 
             // Or just take description if type is loan/borrow.
             // User said: "names that they lended money to or borrowed money to"
             name = exp.description;
          }
          
          if (name.isNotEmpty) {
             final norm = normalize(name);
             if (!existingNames.contains(norm) && !newNames.contains(norm)) {
                newNames.add(norm);
                // We add the original casing found first
                final newPerson = BeneficiaryModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString() + newNames.length.toString(), // unique seed
                  name: name.trim(),
                  createdAt: DateTime.now().toIso8601String()
                );
                // Add sequentially to avoid race conditions or heavy batch? 
                // Firestore write is async. Let's await.
                try {
                  await _firestoreService.addBeneficiary(userId!, newPerson);
                  // Update local set to prevent adding 'ALICE' then 'Alice' in same loop if we didn't await
                  // But we are awaiting, so getBeneficiaries stream updates later. 
                  // Ideally we trust 'newNames' set for this loop duration.
                } catch (e) {
                  print("Error migrating $name: $e");
                }
             }
          }

          // FIX: Ensure category is correct (Legacy might allow 'Housing' or 'Default' > fix to Lending/Borrowing)
          // We only fix if it's NOT already correct.
          final correctCategory = exp.type == 'loan' ? 'Lending' : 'Borrowing';
          if (exp.category != correctCategory) {
             // We need to update this expense record
             final updatedExp = exp.copyWith(category: correctCategory);
             try {
                await updateExpense(updatedExp); 
             } catch (e) {
                print("Error correcting category for ${exp.id}: $e");
             }
          }
       }
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
  Future<void> applyFixedChargesToCycle(int year, int month, {bool manualOnly = false, String? chargeId, DateTime? customDate}) async {
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
        await _applyChargeToCycle(charge, year, month, dateOverride: customDate);
      } else {
        print("Skipping ${charge.name}, already applied.");
      }
    }
  }

  Future<void> _applyChargeToCycle(FixedChargeModel charge, int year, int month, {DateTime? dateOverride}) async {
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
    
    // Use helper to determine scheduled date
    targetDate = _calculateChargeDate(year, month, charge.dayOfMonth);

    // Override if manual application requested "Now"
    if (dateOverride != null) {
      targetDate = dateOverride;
    }
    
    // Create Expense
    final newExpense = ExpenseModel(
      id: '', // Firestore gen
      amount: charge.amount, // For Fixed Charge application
      category: charge.category,
      description: charge.name, // "Rent"
      date: targetDate.toIso8601String(),
      type: 'expense',
      originChargeId: charge.id,
    );
    
    await addExpense(newExpense);
  }

  // --- Event CRUD ---

  Future<void> addEvent(EventModel event) async {
    if (userId == null) return;
    await _firestoreService.addEvent(userId!, event);
    // Stream will update local list
  }

  Future<void> updateEvent(EventModel event) async {
    if (userId == null) return;
    await _firestoreService.updateEvent(userId!, event);
  }

  Future<void> deleteEvent(String eventId) async {
    if (userId == null) return;
    
    // Cascade Delete: Find all expenses linked to this event
    final linkedExpenses = _expenses.where((e) => e.eventId == eventId).toList();
    
    // Delete them one by one (or batch if service supported it, but loop is fine for now)
    for (final exp in linkedExpenses) {
       await _firestoreService.deleteExpense(userId!, exp.id);
       // Local list update handled by stream or we can remove manually for instant feedback
       // _expenses.removeWhere((e) => e.id == exp.id);
    }
    
    await _firestoreService.deleteEvent(userId!, eventId);
  }

  Future<void> _adjustEventTotal(String eventId, double delta) async {
      final eventIndex = _events.indexWhere((e) => e.id == eventId);
      if (eventIndex != -1) {
        final event = _events[eventIndex];
        final updatedEvent = event.copyWith(
          totalAmount: event.totalAmount + delta,
          lastUpdated: DateTime.now().toIso8601String(),
        );
        _events[eventIndex] = updatedEvent;
        notifyListeners();
        await updateEvent(updatedEvent);
      }
  }
    
  DateTime _calculateChargeDate(int year, int month, int dayOfMonth) {
    // Logic:
    // A cycle is defined as [StartDay of Month S, StartDay of Month S+1).
    // Where Month S is determined by the offset.
    
    final s = _getEffectiveSettings(year, month); // Added: Define 's'

    // Calculate Reference Start Date first.
    int startMonthIndex = month + s.monthOffset; // 0-based
    int startYear = year;
    if (startMonthIndex < 0) {
      startMonthIndex = 11;
      startYear--;
    }
    
    // So Cycle starts in (startYear, startMonthIndex + 1).
    // Compare Day vs StartDay.
    
    int targetYear;  // Added: Declaration
    int targetMonth; // Added: Declaration

    if (dayOfMonth >= s.startDay) {
       // It belongs to the "Start Month" side of the cycle.
       targetYear = startYear;
       targetMonth = startMonthIndex + 1;
    } else {
       // It belongs to the "End Month" side of the cycle.
       // E.g. Dec 26 - Jan 26.
       // Day 5 belongs to Jan. (Month+1 of Start).
       
       int nextMonthIndex = startMonthIndex + 1;
       int nextYear = startYear;
       if (nextMonthIndex > 11) {
         nextMonthIndex = 0;
         nextYear++;
       }
       targetYear = nextYear;
       targetMonth = nextMonthIndex + 1;
    }
    
    // Clamp day to max days in that target month
    final maxDays = Utils.getDaysInMonth(targetYear, targetMonth); 
    final safeDay = dayOfMonth > maxDays ? maxDays : dayOfMonth;
    
    return DateTime(targetYear, targetMonth, safeDay);
  }

  Future<void> deleteExpense(String id) async {
    if (userId == null) return;
    
    // Check if it's a linked repayment before deleting
    final exp = _expenses.firstWhere((e) => e.id == id, orElse: () => ExpenseModel(id: '', amount: 0, category: '', description: '', date: '', type: ''));
    
    // Decrease Event Total if applicable (Added)
    if (exp.eventId != null) {
       await _adjustEventTotal(exp.eventId!, -exp.amount);
    } // End Added

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

  // Public wrapper for UI access
  MonthlySettings getSettingsForMonth(int year, int month) {
    return _getEffectiveSettings(year, month);
  }

  
  Future<void> addCategory(CategoryModel cat) async {
     if (userId == null) return;
     
     // Assign Order: Put at the end of the list
     // We need the current full list to determine the max order
     final currentList = categories; // Uses the getter which merges defaults
     int maxOrder = -1;
     if (currentList.isNotEmpty) {
       maxOrder = currentList.map((c) => c.order).reduce((curr, next) => curr > next ? curr : next);
     }
     
     final newCat = CategoryModel(
       name: cat.name,
       color: cat.color,
       icon: cat.icon,
       order: maxOrder + 1,
     );
     
     await _firestoreService.addCategory(userId!, newCat);
     // Note: This appends to the list. If we want it to be sortable immediately alongside others, 
     // it needs to have the order field saved. CategoryModel.toMap() uses the field, which we set. 
     
     // Force refresh local list (optional, as stream will update)
     // _categories.add(newCat); 
     // notifyListeners();
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
