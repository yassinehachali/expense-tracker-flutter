// File: lib/ui/screens/transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/expense_provider.dart';
import '../widgets/expense_card.dart';
import 'add_expense_screen.dart';
import '../../data/models/expense_model.dart';
import '../../core/utils.dart'; // Ensure utils has formatCurrency

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final theme = Theme.of(context);
    
    // Grouping Logic
    final groupedExpenses = <String, List<ExpenseModel>>{};
    for (var expense in provider.filteredExpenses) {
      final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(expense.date));
      if (!groupedExpenses.containsKey(dateKey)) {
        groupedExpenses[dateKey] = [];
      }
      groupedExpenses[dateKey]!.add(expense);
    }
    
    final sortedKeys = groupedExpenses.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All', 
                  selected: provider.filterType == 'all',
                  onTap: () => provider.setFilterType('all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Expenses', 
                  selected: provider.filterType == 'expense',
                  onTap: () => provider.setFilterType('expense'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Loans', 
                  selected: provider.filterType == 'loan',
                  onTap: () => provider.setFilterType('loan'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Income', 
                  selected: provider.filterType == 'income',
                  onTap: () => provider.setFilterType('income'),
                ),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: provider.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : groupedExpenses.isEmpty
                ? Center(child: Text("No transactions found", style: theme.textTheme.bodyLarge))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      final dateKey = sortedKeys[index];
                      final expenses = groupedExpenses[dateKey]!;
                      final date = DateTime.parse(dateKey);
                      final dayName = DateFormat('EEEE').format(date); // e.g. Friday
                      final dayNum = DateFormat('d').format(date); // e.g. 12
                      
                      // Calculate Daily Total
                      double dailyTotal = 0;
                      for (var e in expenses) {
                         if (e.type == 'income') {
                           dailyTotal += e.amount;
                         } else {
                           dailyTotal -= e.amount;
                         }
                      }
                      
                      Color totalColor = dailyTotal >= 0 ? Colors.greenAccent : Colors.redAccent;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Daily Header
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$dayName $dayNum',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.textTheme.bodyLarge?.color?.withOpacity(0.9)
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  Utils.formatCurrency(dailyTotal),
                                  style: TextStyle(
                                    color: totalColor, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Transactions for this day
                          ...expenses.map((expense) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ExpenseCard(
                              expense: expense,
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: theme.cardColor,
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                  builder: (ctx) => SafeArea(
                                    bottom: false, // Ignore the bottom (keyboard/home bar) area
                                    child: Wrap(
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.edit),
                                          title: const Text("Edit Transaction"),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(expenseToEdit: expense)));
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.delete, color: Colors.red),
                                          title: const Text("Delete Transaction", style: TextStyle(color: Colors.red)),
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            await provider.deleteExpense(expense.id);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          )),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected 
              ? (isDark ? Colors.indigo : Colors.indigo) 
              : theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? Colors.transparent : theme.dividerColor,
          ),
          boxShadow: selected ? [
            BoxShadow(color: Colors.indigo.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
          ] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
