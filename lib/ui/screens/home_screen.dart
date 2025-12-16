import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/global_events.dart';
import '../../providers/expense_provider.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'settings_screen.dart';
import 'add_expense_screen.dart';
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

    // Request Notification Permissions if needed (Android 13+)
    Future.delayed(const Duration(seconds: 2), () async {
       if (mounted) {
         try {
           final granted = await NotificationService().requestPermissions();
           if (granted == true && mounted) {
             // Re-schedule to ensure exact alarm intent is allowed and timezones are correct
             await NotificationService().scheduleDailyNotification(21, 0); 
           }
         } catch (e) {
           print("Permission request error: $e");
         }
       }
    });
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

    final List<Widget> screens = [
      DashboardScreen(onViewAll: () => _onItemTapped(1)),
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.layoutGrid),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.settings),
              label: 'Settings',
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
