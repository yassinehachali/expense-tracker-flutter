import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
        title: Text(AppStrings.loansManager),
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
                      Text(AppStrings.totalBorrowed, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text(
                        Utils.formatCurrency(totalBorrowed),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                       Text(
                        "${AppStrings.repaidPrefix}${Utils.formatCurrency(totalRepaid)}",
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
                      Text(AppStrings.noDebtsMessage, style: theme.textTheme.titleMedium?.copyWith(color: theme.hintColor)),
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
                                       loan.description.isNotEmpty ? loan.description : AppStrings.unknownLender,
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
                                 Text(AppStrings.remaining.replaceAll(':', ''), style: theme.textTheme.bodySmall),
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
                                 child: Text(AppStrings.repay),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLoanDialog(context, provider),
        label: Text(AppStrings.addTransaction),
        icon: const Icon(LucideIcons.plus),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showAddLoanDialog(BuildContext context, ExpenseProvider provider) {
    final amountController = TextEditingController();
    final personController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isPastDebt = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Add Borrowed Amount"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: AppStrings.amountLabel,
                    prefixIcon: const Icon(LucideIcons.dollarSign),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: personController,
                  decoration: InputDecoration(
                    labelText: "Lender (Person/Bank)",
                    prefixIcon: const Icon(LucideIcons.user),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.calendar),
                  title: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                         selectedDate = picked;
                         // Auto-check "Past Debt" if older than 30 days? 
                         // Optional, user can manual check.
                      });
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Pre-existing Debt?"),
                  subtitle: const Text("Does not affect current balance"),
                  value: isPastDebt,
                  onChanged: (val) => setState(() => isPastDebt = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text(AppStrings.cancel)
            ),
            ElevatedButton(
              onPressed: () async {
                 final amountText = amountController.text;
                 final amount = double.tryParse(amountText);
                 if (amount == null || amount <= 0) return;
                 
                 final person = personController.text.trim();
                 if (person.isEmpty) return;

                 final newExpense = ExpenseModel(
                   id: '', // provider assigns ID if Firestore not used directly? 
                   // Wait, ExpenseModel needs ID on creation? 
                   // FirestoreService usually generates ID. 
                   // ExpenseProvider.addExpense calls FirestoreService.addExpense which sets ID?
                   // Let's check provider.addExpense. 
                   // Usually models created locally have empty ID then replaced by Firestore ID.
                   // Or UUID. 
                   // I'll leave ID empty string, assuming Provider/Service handles it.
                   // Checking addExpense: it calls _firestoreService.addExpense.
                   
                   amount: amount,
                   category: 'Borrowed',
                   description: "Borrowed from $person",
                   date: selectedDate.toIso8601String(),
                   type: 'borrow',
                   isReturned: false,
                   loanee: person,
                   excludeFromBalance: isPastDebt,
                 );
                 
                 await provider.addExpense(newExpense);
                 if (context.mounted) Navigator.pop(ctx);
              }, 
              child: Text(AppStrings.confirm)
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
        title: Text(AppStrings.repayLoanTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text("${AppStrings.totalBorrowed}${Utils.formatCurrency(loan.amount)}"),
             Text("${AppStrings.remaining}${Utils.formatCurrency(remaining)}"),
             const SizedBox(height: 16),
             TextField(
               controller: controller,
               keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: AppStrings.amountLabel,
                  hintText: AppStrings.enterAmount,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                ),
             ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          ElevatedButton(
            onPressed: () {
               final val = double.tryParse(controller.text);
               if (val == null || val <= 0) return;
               if (val > remaining) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.amountExceedsDebt)));
                  return;
               }
               
               provider.repayBorrowing(loan, val);
               Navigator.pop(ctx);
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.repaidPrefix}${Utils.formatCurrency(val)}")));
            }, 
            child: Text(AppStrings.confirm)
          ),
        ],
      ),
    );
  }
}
