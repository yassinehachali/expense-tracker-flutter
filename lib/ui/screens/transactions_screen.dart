// File: lib/ui/screens/transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/expense_provider.dart';
import '../widgets/expense_card.dart';
import 'add_expense_screen.dart';
import '../../data/models/expense_model.dart';
import '../../core/utils.dart'; // Ensure utils has formatCurrency

import '../../core/app_strings.dart';
import '../../data/models/event_model.dart';
import 'event_detail_screen.dart';
import '../widgets/glass_container.dart';
import 'package:lucide_icons/lucide_icons.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final theme = Theme.of(context);
    
    // Grouping Logic
    final groupedItems = <String, List<dynamic>>{};
    
    // 1. Expenses (excluding those linked to events)
    final expenses = provider.filteredExpenses.where((e) => e.eventId == null || e.eventId!.trim().isEmpty).toList();
    for (var expense in expenses) {
      final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(expense.date));
      if (!groupedItems.containsKey(dateKey)) groupedItems[dateKey] = [];
      groupedItems[dateKey]!.add(expense);
    }

    // 2. Events (if filter is All or Expense, assuming Events count as "Spending")
    if (provider.filterType == 'all' || provider.filterType == 'expense') {
      for (var event in provider.events) {
         // Use lastUpdated for sorting/grouping in history
         final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(event.lastUpdated));
         if (!groupedItems.containsKey(dateKey)) groupedItems[dateKey] = [];
         groupedItems[dateKey]!.add(event);
      }
    }
    
    final sortedKeys = groupedItems.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.historyTitle),
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
                  label: AppStrings.filterAll, 
                  selected: provider.filterType == 'all',
                  onTap: () => provider.setFilterType('all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: AppStrings.filterExpenses, 
                  selected: provider.filterType == 'expense',
                  onTap: () => provider.setFilterType('expense'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: AppStrings.filterLoans, 
                  selected: provider.filterType == 'loan',
                  onTap: () => provider.setFilterType('loan'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: AppStrings.filterIncome, 
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
              : groupedItems.isEmpty
                ? Center(child: Text(AppStrings.noTransactions, style: theme.textTheme.bodyLarge))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      final dateKey = sortedKeys[index];
                      final items = groupedItems[dateKey]!;
                      
                      // Sort items within the day by time/lastUpdated desc
                      items.sort((a, b) {
                         DateTime dA = a is ExpenseModel ? DateTime.parse(a.date) : DateTime.parse((a as EventModel).lastUpdated);
                         DateTime dB = b is ExpenseModel ? DateTime.parse(b.date) : DateTime.parse((b as EventModel).lastUpdated);
                         return dB.compareTo(dA);
                      });

                      final date = DateTime.parse(dateKey);
                      final inCycle = provider.isInCurrentCycle(date);
                      
                      String dateLabel;
                      if (inCycle) {
                         dateLabel = '${DateFormat('EEEE', AppStrings.language).format(date)} ${DateFormat('d', AppStrings.language).format(date)}';
                      } else {
                         dateLabel = DateFormat('MMM d', AppStrings.language).format(date);
                      }

                      // Calculate Daily Total
                      double dailyTotal = 0;
                      for (var item in items) {
                         if (item is ExpenseModel) {
                           if (item.type == 'income') {
                             dailyTotal += item.amount;
                           } else if (item.type == 'loan') {
                              dailyTotal -= item.amount;
                           } else if (item.type == 'rollover') {
                              dailyTotal += item.amount; 
                           } else {
                             dailyTotal -= item.amount;
                           }
                         } else if (item is EventModel) {
                           // For Events, we subtract the total Amount?
                           // Or is it just informational? If we removed expenses, we should subtract.
                           // User said "event not expenses".
                           // If filteredExpenses doesn't contain the event's expenses, then we must count the event's total.
                           dailyTotal -= item.totalAmount;
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
                                      dateLabel,
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
                          ...items.map((item) {
                            if (item is EventModel) {
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 12),
                                 child: _EventHistoryCard(event: item),
                               );
                            }
                            
                            final expense = item as ExpenseModel;
                            return Padding(
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
                                          if (expense.type == 'loan')
                                            ListTile(
                                              leading: Icon(
                                                expense.isReturned ? Icons.undo : Icons.check_circle_outline, 
                                                color: expense.isReturned ? Colors.orange : Colors.green
                                              ),
                                              title: Text(expense.isReturned ? AppStrings.markAsPending : AppStrings.markAsReturned),
                                              onTap: () async {
                                                Navigator.pop(ctx);
                                                await provider.setLoanReturned(expense, !expense.isReturned);
                                              },
                                            ),
                                          if (expense.type != 'rollover') // Rollover is not editable
                                            ListTile(
                                              leading: const Icon(Icons.edit),
                                              title: Text(AppStrings.editTransaction),
                                              onTap: () {
                                                Navigator.pop(ctx);
                                                Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(expenseToEdit: expense)));
                                              },
                                            ),
                                          ListTile(
                                            leading: const Icon(Icons.delete, color: Colors.red),
                                            title: Text(AppStrings.deleteTransaction, style: const TextStyle(color: Colors.red)),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              if (expense.type == 'rollover') {
                                                 await provider.ignoreRollover(provider.selectedYear, provider.selectedMonth);
                                              } else {
                                                 await provider.deleteExpense(expense.id);
                                              }
                                            },
                                          ),
                                        ],
                                    ),
                                    ),
                                  );
                              },
                            ),
                          );
                          }),
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

class _EventHistoryCard extends StatelessWidget {
  final EventModel event;
  const _EventHistoryCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
         Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)));
      },
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Utils.getIcon(event.icon == 'Calendar' ? 'Plane' : event.icon), color: Colors.purple),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                       const Icon(LucideIcons.plane, size: 12, color: Colors.grey),
                       const SizedBox(width: 4),
                       Text(event.isClosed ? "Completed" : "Active Event", style: TextStyle(color: event.isClosed ? Colors.green : Colors.grey, fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Utils.formatCurrency(event.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purpleAccent)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
