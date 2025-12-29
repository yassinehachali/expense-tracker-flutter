import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/app_strings.dart';
import '../../core/utils.dart';
import '../../providers/expense_provider.dart';
import '../screens/beneficiary_detail_screen.dart';
import '../widgets/glass_container.dart';
import '../../data/models/beneficiary_model.dart';
import '../../data/models/expense_model.dart';

class BeneficiariesTab extends StatelessWidget {
  const BeneficiariesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final beneficiaries = provider.beneficiaries;

        if (beneficiaries.isEmpty) {
           return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(LucideIcons.users, size: 64, color: Colors.grey.withOpacity(0.5)),
                 const SizedBox(height: 16),
                 Text("No People Added", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
               ],
             ),
           );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: beneficiaries.length,
          itemBuilder: (ctx, index) {
            final person = beneficiaries[index];
            
            // Calculate Balance
            // Positive = They owe me (I Lent them > They returned)
            // Negative = I owe them (I Borrowed > I returned)
            double balance = 0;
            
            // Get all loans related to this person (by name matching for now, later ID based)
            // Since we are migrating, we match by name. 
            // Ideally we store beneficiaryId in ExpenseModel, but for now name match is easier for mix of old/new.
            // Actually, we should probably stick to name matching for simplicity across the app 
            // until we fully migrate expense model.
            
            // Filter all expenses where description or loanee matches name
            // Note: This matches "Alice" string.
            final related = provider.expenses.where((e) {
               final name = e.loanee ?? e.description;
               return name.toLowerCase() == person.name.toLowerCase();
            }).toList();

            for (var e in related) {
               double remaining = e.amount - e.returnedAmount;
               if (e.type == 'loan') {
                  balance += remaining; // They owe me
               } else if (e.type == 'borrow') {
                  balance -= remaining; // I owe them
               }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey.withOpacity(0.1),
                  child: Text(person.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ),
                title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: balance == 0 
                  ? const Text("Settled", style: TextStyle(color: Colors.grey, fontSize: 12)) 
                  : Text(
                      balance > 0 
                        ? "Owes you ${Utils.formatCurrency(balance)}" 
                        : "You owe ${Utils.formatCurrency(balance.abs())}",
                      style: TextStyle(
                        color: balance > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                      ),
                    ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => BeneficiaryDetailScreen(beneficiary: person)));
                },
              ),
            );
          },
        );
      },
    );
  }
}
