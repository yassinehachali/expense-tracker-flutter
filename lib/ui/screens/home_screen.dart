// File: lib/ui/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'settings_screen.dart'; // Will be created next
import 'add_expense_screen.dart';

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

  void _openAddExpense() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
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
