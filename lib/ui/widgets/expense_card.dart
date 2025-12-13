// File: lib/ui/widgets/expense_card.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/category_model.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../providers/expense_provider.dart';
import '../widgets/glass_container.dart';
import 'category_icon.dart';

class ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback? onTap;

  const ExpenseCard({super.key, required this.expense, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Determine Color & Icon
    Color catColor = theme.primaryColor;
    String iconKey = 'MoreHorizontal'; 
    bool isIncome = expense.type == 'income';
    bool isLoan = expense.type == 'loan';
    bool isRollover = expense.type == 'rollover'; // New Type
    
    // Strikethrough style for returned loans
    final bool isReturnedLoan = isLoan && expense.isReturned;
    
    if (isRollover) {
      iconKey = 'History'; // or RefreshCcw
      catColor = Colors.green; // User requested Green
    } else if (isIncome) {
      iconKey = 'Wallet'; 
      catColor = Colors.green;
    } else if (isReturnedLoan) {
      // Returned Loan Style (Green Check, Green Text, Strikethrough)
      iconKey = 'CheckCircle';
      catColor = Colors.green; 
    } else if (isLoan) {
      iconKey = 'Handshake';
      catColor = Colors.orange;
    } else {
      // ... category logic ...
      final provider = Provider.of<ExpenseProvider>(context, listen: false); 
      final categoryList = provider.categories;
      
      CategoryModel? cat;
      try {
        cat = categoryList.firstWhere((c) => c.name == expense.category);
      } catch (e) {
        cat = null;
      }
      
      if (cat != null) {
         catColor = hexToColor(cat.color);
         iconKey = cat.icon;
      } else {
         final def = DEFAULT_CATEGORIES.firstWhere(
            (c) => c['name'] == expense.category, 
            orElse: () => {'color': '#999999', 'icon': 'MoreHorizontal'}
         );
         catColor = hexToColor(def['color'] as String);
         iconKey = def['icon'] as String;
      }
    }

    // We allow deleting 'rollover' type now, which triggers 'ignoreRollover'
    // So we assume everything is dismissible or handled in the Dismissible logic below.

    return Dismissible(
      // ... dismissible logic ...
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (expense.type == 'rollover') return true; // Instant delete for rollover (ignore)
        
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.cardColor,
            title: const Text("Delete Transaction?"),
            content: const Text("This action cannot be undone."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true), 
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Delete")
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        final provider = Provider.of<ExpenseProvider>(context, listen: false);
        if (expense.type == 'rollover') {
           provider.ignoreRollover(provider.selectedYear, provider.selectedMonth);
        } else {
           provider.deleteExpense(expense.id);
        }
      },
      child: GestureDetector(
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(20),
          child: Row(
          children: [
            // Icon Bubble
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: CategoryIcon(iconKey: iconKey, color: catColor, size: 24),
              ),
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                     expense.description.isNotEmpty ? expense.description : expense.category,
                     style: theme.textTheme.bodyLarge?.copyWith(
                       fontWeight: FontWeight.bold,
                       decoration: isReturnedLoan ? TextDecoration.lineThrough : null,
                       color: isReturnedLoan ? Colors.grey : null, // Grey out text if returned
                     ),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                   const SizedBox(height: 4),
                   Text(
                     isReturnedLoan ? 'Loan Returned' : DateFormat.yMMMd().format(DateTime.parse(expense.date)),
                     style: theme.textTheme.bodySmall?.copyWith(
                       color: isReturnedLoan ? Colors.green : null
                     ),
                   ),
                ],
              ),
            ),
            
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'} ${Utils.formatCurrency(expense.amount)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: (isIncome || isReturnedLoan) ? Colors.green : Colors.red,
                    decoration: isReturnedLoan ? TextDecoration.lineThrough : null,
                    decorationThickness: 2.0,
                  ),
                ),
                if (isLoan && expense.returnedAmount > 0 && !isReturnedLoan)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Returned: ${Utils.formatCurrency(expense.returnedAmount)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  )
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
