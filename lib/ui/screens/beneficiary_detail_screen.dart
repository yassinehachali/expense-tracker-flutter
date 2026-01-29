import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/app_strings.dart';
import '../../core/utils.dart';
import '../../data/models/beneficiary_model.dart';
import '../../providers/expense_provider.dart';
import '../widgets/glass_container.dart';

class BeneficiaryDetailScreen extends StatelessWidget {
  final BeneficiaryModel beneficiary;

  const BeneficiaryDetailScreen({super.key, required this.beneficiary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(beneficiary.name),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          )
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          final related = provider.expenses.where((e) {
             final name = e.loanee ?? e.description;
             return name.toLowerCase() == beneficiary.name.toLowerCase();
          }).toList();

          // Sort by date desc
          related.sort((a, b) => b.date.compareTo(a.date));

          double balance = 0;
           for (var e in related) {
             double remaining = e.amount - e.returnedAmount;
             if (e.type == 'loan') {
                balance += remaining; 
             } else if (e.type == 'borrow') {
                balance -= remaining;
             }
          }

          return Column(
            children: [
              // Summary Card
              Padding(
                padding: const EdgeInsets.all(16),
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                       Text("Net Balance", style: TextStyle(color: Colors.grey[400])),
                       const SizedBox(height: 8),
                       Text(
                         balance == 0 
                           ? "All Settled" 
                           : (balance > 0 ? "Rows you ${Utils.formatCurrency(balance)}" : "You owe ${Utils.formatCurrency(balance.abs())}"),
                         style: TextStyle(
                           fontSize: 24, 
                           fontWeight: FontWeight.bold,
                           color: balance == 0 ? Colors.white : (balance > 0 ? Colors.green : Colors.red)
                         ),
                       ),
                    ],
                  ),
                ),
              ),
              
              if (balance.abs() > 0.01)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => _showRepayDialog(context, beneficiary.name, balance.abs(), balance < 0, provider),
                    icon: Icon(balance < 0 ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft),
                    label: Text(balance < 0 ? "Repay Debt" : "Receive Payment"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: balance < 0 ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              
              const Divider(),
              
              Expanded(
                child: related.isEmpty 
                  ? Center(child: Text("No transactions found", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: related.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (ctx, index) {
                        final item = related[index];
                        final isLoan = item.type == 'loan';
                        final isRepayment = item.category.contains('Repayment'); 
                        // Note: Real logic for repayment might differ if we separate them, 
                        // but here we just list what we found.
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              isLoan ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
                              color: isLoan ? Colors.indigo : Colors.orange,
                            ),
                            title: Text(item.category), // e.g. "Personal Loan" or "Repayment..."
                            subtitle: Text(Utils.formatDate(DateTime.parse(item.date))),
                            trailing: Text(
                              Utils.formatCurrency(item.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
              )
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Person?"),
        content: const Text("This removes them from your list, but keeps their transaction history."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          TextButton(
            onPressed: () async {
              await Provider.of<ExpenseProvider>(context, listen: false).deleteBeneficiary(beneficiary.id);
              if (context.mounted) {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Go back
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  void _showRepayDialog(BuildContext context, String personName, double amount, bool isDebt, ExpenseProvider provider) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDebt ? "Repay Debt" : "Receive Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text("Total Outstanding: ${Utils.formatCurrency(amount)}"),
             const SizedBox(height: 16),
             TextField(
               controller: controller,
               keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isDebt ? "Amount to Repay" : "Amount Received",
                  hintText: "0.00",
                  border: const OutlineInputBorder(),
                  prefixText: "${Utils.currencySymbol} ",
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
               if (val > amount + 0.01) { 
                  // Could show error
                  return;
               }
               
               // Use Bulk Repayment
               // If isDebt (I owe them), type is 'borrow' (I borrowed from them)
               // If !isDebt (They owe me), type is 'loan' (I lent to them)
               provider.repayBeneficiary(personName, val, isDebt ? 'borrow' : 'loan');
               Navigator.pop(ctx);
            }, 
            child: Text(AppStrings.confirm)
          ),
        ],
      ),
    );
  }
}
