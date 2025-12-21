import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/global_events.dart';
import '../../providers/expense_provider.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'settings_screen.dart';
import 'add_expense_screen.dart';
import '../../core/app_strings.dart';
import '../../data/services/notification_service.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // ...
  @override
  void initState() {
    super.initState();
    // Listen for global navigation events
    GlobalEvents.stream.listen((event) {
      if (event == 'open_update_check') {
        if (mounted) {
           _onItemTapped(2); // Switch to Settings
        }
      }
    });

    // Initialize Notifications
    if (!kIsWeb) {
      _initNotifications();
    }
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
      body: SafeArea(
        bottom: false, // Ignore the bottom (keyboard/home bar) area
        child: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
      ),
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
      floatingActionButton: _selectedIndex != 2 ? FloatingActionButton(
        onPressed: _openAddExpense,
        backgroundColor: Colors.indigo,
        elevation: 4,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ) : null,
    );
  }
}
