import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/global_events.dart';
import '../../core/utils.dart'; // Added Import
import '../../providers/expense_provider.dart';
import '../../data/models/fixed_charge_model.dart'; // Added Import
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'settings_screen.dart';
import 'add_expense_screen.dart';
import 'add_expense_screen.dart';
import '../../core/app_strings.dart';
import '../../data/services/notification_service.dart';  
import 'fixed_charges_screen.dart';
import 'loans_manager_screen.dart';
import 'insurance_screen.dart'; // Verified filename 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  
  // FAB Animation
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  bool _isFabOpen = false;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }
  
  @override
  void initState() {
    super.initState();
    
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOut,
    );

    // Listen for global navigation events
    // Listen for global navigation events
    GlobalEvents.stream.listen((event) {
      if (event == 'open_update_check') {
        if (mounted) {
           _onItemTapped(2); // Switch to Settings
        }
      } else if (event == 'switch_to_history') {
        if (mounted) {
           _onItemTapped(1); // Switch to History/Transactions
        }
      }
    });

    // Initialize Notifications
    if (!kIsWeb) {
      _initNotifications();
    }
    
    // Check for Due Variable Charges (Interactive Auto-Apply)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       await _checkStartupVariables();
    });
  }
  
  Future<void> _checkStartupVariables() async {
     final provider = Provider.of<ExpenseProvider>(context, listen: false);
     // We need to wait for data? Usually provider loads fast or is cached.
     // Adding a small delay to ensure provider has data if it's async loading
     await Future.delayed(const Duration(seconds: 1));
     if (!mounted) return;
     
     final dueCharges = provider.checkDueVariableCharges();
     
     if (dueCharges.isNotEmpty) {
        // Show dialogs sequentially
        for (final charge in dueCharges) {
           if (!mounted) break;
           await _showVariableChargeDialog(charge);
        }
     }
  }
  
  Future<void> _showVariableChargeDialog(dynamic charge) async { // dynamic to avoid import if not needed, but better to import model
     // Import FixedChargeModel or cast
     // Let's assume we can import it or use dynamic if import is missing (I'll add import below)
     final provider = Provider.of<ExpenseProvider>(context, listen: false);
     final monthName = Utils.getMonthName(provider.selectedMonth);
     
     final controller = TextEditingController(text: charge.amount.toString());
     
     await showDialog(
       context: context,
       barrierDismissible: false, // Force decision
       builder: (ctx) => AlertDialog(
         title: Row(
           children: [
             const Icon(LucideIcons.zap, color: Colors.amber), // Dynamic icon?
             const SizedBox(width: 8),
             Text(charge.name),
           ],
         ), 
         content: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text("This variable charge is due for $monthName."),
             const SizedBox(height: 16),
             Text("Estimated Amount: ${Utils.formatCurrency(charge.amount)}", style: TextStyle(fontSize: 12, color: Colors.grey)),
             const SizedBox(height: 8),
             TextField(
               controller: controller,
               keyboardType: TextInputType.number,
               decoration: const InputDecoration(
                 labelText: "Enter Actual Amount",
                 border: OutlineInputBorder(),
               ),
               autofocus: true,
             ),
           ],
         ),
         actions: [
           TextButton(
             onPressed: () {
               // User wants to skip for now
               Navigator.pop(ctx);
             }, 
             child: const Text("Skip"),
           ),
           ElevatedButton(
             onPressed: () async {
                final val = double.tryParse(controller.text);
                if (val == null || val <= 0) return;
                
                Navigator.pop(ctx);
                
                await provider.applyFixedChargesToCycle(
                   provider.selectedYear, 
                   provider.selectedMonth,
                   chargeId: charge.id,
                   customDate: DateTime.now(),
                   amountOverride: val
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${charge.name} applied!")));
                }
             }, 
             child: const Text("Confirm"),
           )
         ],
       ),
     );
  }

  Future<void> _initNotifications() async {
    try {
      final ns = NotificationService();
      
      // 1. Initialize (Create channels, load timezone, set listeners)
      await ns.init((response) {
         if (response.payload == 'update_check') {
            GlobalEvents.trigger('open_update_check');
         }
      });

      // 2. Wait for UI to settle before asking permissions
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      // 3. Request Permissions
      final granted = await ns.requestPermissions();
      
      // 3.1 Request Exact Alarm Permission (Android 12+)
      await ns.checkAndroidScheduleExactAlarmPermission();
      
      // 4. Schedule Daily Reminder
      // (If granted is null, it means Android <13, permission implied)
      if (granted != false) {
         await ns.scheduleDailyNotification(21, 0); 
      }
    } catch (e) {
      print("Notification init error: $e");
    }
  }

  void _openAddExpense() {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final now = DateTime.now();
    
    // Determine the smart initial date
    // If we are viewing a specific month (e.g. Dec), we want the date to default to that month.
    // Logic: 
    // 1. Get current cycle range for the selected view.
    // 2. If 'now' is inside that range, use 'now'.
    // 3. If 'now' is outside, default to the start or end of that range (clamped).
    
    final start = provider.currentCycleStart;
    final end = provider.currentCycleEnd;
    
    DateTime initialDate = now;
    
    // Check if 'now' is outside the range
    // We add 1 day to end for comparison to include the full end day if times are midnight
    // But provider.currentCycleEnd is already "last day". 
    // Let's just compare YMD.
    
    if (now.isBefore(start)) {
      initialDate = start;
    } else if (now.isAfter(end.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)))) {
       // If now is AFTER the cycle end (e.g. today is Jan, view is Dec)
       // We default to the last day of the cycle.
       initialDate = end;
    }
  
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(initialDate: initialDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Listen to provider to rebuild when Language changes (via notifyListeners)
    Provider.of<ExpenseProvider>(context);

    final List<Widget> screens = [
      // Add Key to force rebuild if language changes, though Provider listen should suffice
      DashboardScreen(
        key: ValueKey(AppStrings.language), 
        onViewAll: () => _onItemTapped(1)
      ),
      const TransactionsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false, // Critical for PWA overlay mode: prevents blank space under keyboard
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _selectedIndex,
              children: screens,
            ),
          ),
          
          // Dimming Overlay when FAB is open
          if (_isFabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleFab,
                child: Container(
                  color: Colors.black54,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedIndex != 2 ? _buildExpandableFab(theme) : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor)),
          color: theme.cardColor,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.indigo,
          unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[400],
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(LucideIcons.layoutGrid),
              label: AppStrings.dashboard,
            ),
            BottomNavigationBarItem(
              icon: const Icon(LucideIcons.history),
              label: AppStrings.historyTitle,
            ),
            BottomNavigationBarItem(
              icon: const Icon(LucideIcons.settings),
              label: AppStrings.settingsTitle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableFab(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isFabOpen) ...[
          // 4. Loans Manager
          _buildFabItem(
            theme,
            icon: LucideIcons.userCheck,
            label: AppStrings.loansManager,
            onTap: () {
              _toggleFab();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoansManagerScreen()));
            },
          ),
          const SizedBox(height: 16),

          // 3. Health Insurance
          _buildFabItem(
            theme,
            icon: LucideIcons.heartPulse,
            label: AppStrings.healthInsuranceTitle,
            onTap: () {
               _toggleFab();
               // Ensure correct import
               Navigator.push(context, MaterialPageRoute(builder: (_) => const InsuranceScreen())); 
            },
          ),
          const SizedBox(height: 16),

          // 2. Fixed Charges
          _buildFabItem(
            theme,
            icon: LucideIcons.calendarClock,
            label: AppStrings.fixedCharges,
            onTap: () {
               _toggleFab();
               Navigator.push(context, MaterialPageRoute(builder: (_) => const FixedChargesScreen()));
            },
          ),
          const SizedBox(height: 16),
          
          // 1. Add Expense (Standard)
          _buildFabItem(
            theme,
            icon: LucideIcons.receipt,
            label: AppStrings.addTransaction,
            onTap: () {
               _toggleFab();
               _openAddExpense();
            },
          ),
          const SizedBox(height: 16),
        ],

        // Main Toggle Button
        FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: Colors.indigo,
          elevation: 4,
          child: RotationTransition(
            turns: Tween(begin: 0.0, end: 0.125).animate(_fabController), // 45 degrees
            child: const Icon(LucideIcons.plus, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildFabItem(ThemeData theme, {required IconData icon, required String label, required VoidCallback onTap}) {
    return ScaleTransition(
      scale: _fabAnimation,
      alignment: Alignment.bottomRight,
      child: FadeTransition(
        opacity: _fabAnimation,
        child: Material(
          color: theme.cardColor,
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
             onTap: onTap,
             borderRadius: BorderRadius.circular(12),
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                   const SizedBox(width: 12),
                   Icon(icon, color: Colors.indigo, size: 24),
                 ],
               ),
             ),
          ),
        ),
      ),
    );
  }
}
