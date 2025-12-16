import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/app_strings.dart';
import '../../core/utils.dart';
import '../../providers/expense_provider.dart';
import '../../data/models/expense_model.dart';
import '../widgets/glass_container.dart';

class LoansManagerScreen extends StatelessWidget {
  const LoansManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<ExpenseProvider>(context);
    
    // Filter for all Borrowed type transactions
    // We scan ALL expenses, not just the current month, because debt persists.
    // Provider.expenses contains everything loaded? 
    // Wait, provider._expenses currently loads ALL for the user.
    final loans = provider.expenses.where((e) => e.type == 'borrow').toList();
    
    // Move active loans to top
    loans.sort((a, b) {
      if (a.isReturned == b.isReturned) return b.date.compareTo(a.date);
      return a.isReturned ? 1 : -1;
    });

    // Calculate Total Borrowed vs Repaid
    double totalBorrowed = 0;
    double totalRepaid = 0; // This is 'returnedAmount' on the borrow tx
    for (var l in loans) {
      totalBorrowed += l.amount;
      totalRepaid += l.returnedAmount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.loansManager),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Summary Card
            GlassContainer(
              padding: const EdgeInsets.all(24),
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(AppStrings.totalBorrowed, style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text(
                        Utils.formatCurrency(totalBorrowed),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                       Text(
                        "Repaid: ${Utils.formatCurrency(totalRepaid)}",
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: const Icon(LucideIcons.coins, color: Colors.white, size: 32),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (loans.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(LucideIcons.checkCircle, size: 60, color: theme.dividerColor),
                      const SizedBox(height: 16),
                      Text("You have no debts!", style: theme.textTheme.titleMedium?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: loans.length,
                itemBuilder: (ctx, index) {
                  final loan = loans[index];
                  final remaining = loan.amount - loan.returnedAmount;
                  final isFullyRepaid = loan.isReturned;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Row(
                               children: [
                                 Container(
                                   padding: const EdgeInsets.all(10),
                                   decoration: BoxDecoration(
                                     color: isFullyRepaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                     shape: BoxShape.circle,
                                   ),
                                   child: Icon(
                                      isFullyRepaid ? LucideIcons.check : LucideIcons.clock,
                                      size: 20,
                                      color: isFullyRepaid ? Colors.green : Colors.orange,
                                   ),
                                 ),
                                 const SizedBox(width: 12),
                                 Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(
                                       loan.description.isNotEmpty ? loan.description : "Unknown Lender",
                                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                     ),
                                     Text(
                                       Utils.formatDate(DateTime.parse(loan.date)),
                                       style: theme.textTheme.bodySmall,
                                     ),
                                   ],
                                 ),
                               ],
                             ),
                             Text(
                               Utils.formatCurrency(loan.amount),
                               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                             ),
                           ],
                         ),
                         const SizedBox(height: 16),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text("Remaining", style: theme.textTheme.bodySmall),
                                 Text(
                                   Utils.formatCurrency(remaining),
                                   style: TextStyle(
                                     fontWeight: FontWeight.bold, 
                                     color: isFullyRepaid ? Colors.green : theme.textTheme.bodyLarge?.color
                                   ),
                                 ),
                               ],
                             ),
                             if (!isFullyRepaid)
                               ElevatedButton(
                                 onPressed: () => _showRepayDialog(context, loan, provider),
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: theme.primaryColor,
                                   foregroundColor: Colors.white,
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                 ),
                                 child: const Text(AppStrings.repay),
                               )
                           ],
                         ),
                         const SizedBox(height: 8),
                         LinearProgressIndicator(
                           value: loan.amount == 0 ? 0 : (loan.returnedAmount / loan.amount),
                           backgroundColor: theme.dividerColor,
                           color: Colors.green,
                           borderRadius: BorderRadius.circular(4),
                         ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showRepayDialog(BuildContext context, ExpenseModel loan, ExpenseProvider provider) {
    final controller = TextEditingController();
    final remaining = loan.amount - loan.returnedAmount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Repay Loan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text("Total Borrowed: ${Utils.formatCurrency(loan.amount)}"),
             Text("Remaining: ${Utils.formatCurrency(remaining)}"),
             const SizedBox(height: 16),
             TextField(
               controller: controller,
               keyboardType: const TextInputType.numberWithOptions(decimal: true),
               decoration: const InputDecoration(
                 labelText: "Repayment Amount",
                 hintText: "Enter amount",
                 border: OutlineInputBorder(),
                 prefixIcon: Icon(Icons.attach_money),
               ),
             ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
               final val = double.tryParse(controller.text);
               if (val == null || val <= 0) return;
               if (val > remaining) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Amount exceeds remaining debt")));
                  return;
               }
               
               provider.repayBorrowing(loan, val);
               Navigator.pop(ctx);
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Repaid ${Utils.formatCurrency(val)}")));
            }, 
            child: const Text("Confirm")
          ),
        ],
      ),
    );
  }
}
