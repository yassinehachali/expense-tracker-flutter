import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/app_strings.dart';
import '../../core/utils.dart';
import '../../providers/expense_provider.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/beneficiary_model.dart';
import '../widgets/glass_container.dart';
import 'add_expense_screen.dart';
import '../widgets/beneficiaries_tab.dart'; // Added Import

class LoansManagerScreen extends StatefulWidget {
  const LoansManagerScreen({super.key});

  @override
  State<LoansManagerScreen> createState() => _LoansManagerScreenState();
}

class _LoansManagerScreenState extends State<LoansManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Trigger migration of legacy loan names
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExpenseProvider>(context, listen: false).migrateCurrentLoansToBeneficiaries();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.loansManager),
        centerTitle: true,
            bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: AppStrings.filterLoans, icon: const Icon(LucideIcons.arrowUpRight)), 
            Tab(text: AppStrings.borrow, icon: const Icon(LucideIcons.arrowDownLeft)), 
            Tab(text: "Beneficiaries", icon: const Icon(LucideIcons.users)), 
          ],
        ),
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          final lendings = provider.expenses.where((e) => e.type == 'loan').toList();
          final debts = provider.expenses.where((e) => e.type == 'borrow').toList();
          
          return TabBarView(
            controller: _tabController,
            children: [
              _LoansList(
                loans: lendings, 
                isDebts: false, 
                provider: provider,
                emptyMessage: AppStrings.noLendingsMessage, 
              ),
              _LoansList(
                loans: debts, 
                isDebts: true, 
                provider: provider,
                emptyMessage: AppStrings.noDebtsMessage,
              ),
              const BeneficiariesTab(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
            final type = _tabController.index == 0 ? 'loan' : 'borrow';
            if (_tabController.index == 2) {
               _showAddBeneficiaryDialog(context);
            } else {
               _showAddDialog(context, type);
            }
        },
        label: Text(_tabController.index == 2 ? "Add Beneficiary" : AppStrings.addTransaction),
        icon: const Icon(LucideIcons.plus),
        backgroundColor: _tabController.index == 2 ? Colors.blueGrey : (_tabController.index == 0 ? Colors.indigo : Colors.orange),
      ),
    );
  }



  void _showAddDialog(BuildContext context, String type) {
     Navigator.push(
       context, 
       MaterialPageRoute(
         builder: (_) => AddExpenseScreen(initialType: type) 
       )
     );
  }

  void _showAddBeneficiaryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Person"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Name", hintText: "e.g. Alice"),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          ElevatedButton(
            onPressed: () async {
               final name = controller.text.trim();
               if (name.isNotEmpty) {
                  final newPerson = BeneficiaryModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    createdAt: DateTime.now().toIso8601String()
                  );
                  
                  try {
                    await Provider.of<ExpenseProvider>(context, listen: false).addBeneficiary(newPerson);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red)
                       );
                    }
                  }
               }
            }, 
            child: const Text("Add")
          )
        ],
      )
    );
  }
}

class _LoansList extends StatelessWidget {
  final List<ExpenseModel> loans;
  final bool isDebts; 
  final ExpenseProvider provider;
  final String emptyMessage;

  const _LoansList({
    required this.loans, 
    required this.isDebts, 
    required this.provider,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isDebts ? LucideIcons.checkCircle : LucideIcons.wallet, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(emptyMessage, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
          ],
        ),
      );
    }

    // 1. Group by Person
    final Map<String, List<ExpenseModel>> grouped = {};
    for (var loan in loans) {
      final name = loan.loanee ?? loan.description; // Fallback
      if (!grouped.containsKey(name)) {
        grouped[name] = [];
      }
      grouped[name]!.add(loan);
    }

    // 2. Create Summary Objects
    final List<_PersonLoanSummary> summaries = [];
    grouped.forEach((name, personLoans) {
      double totalAmount = 0;
      double totalReturned = 0;
      for (var l in personLoans) {
        totalAmount += l.amount;
        totalReturned += l.returnedAmount;
      }
      if (totalAmount > 0) { // Only show if there's actual history
         summaries.add(_PersonLoanSummary(
           name: name,
           totalAmount: totalAmount,
           totalReturned: totalReturned,
           loans: personLoans,
         ));
      }
    });

    // 3. Sort by "Most Remaining" desc
    summaries.sort((a, b) {
      final remA = a.totalAmount - a.totalReturned;
      final remB = b.totalAmount - b.totalReturned;
      return remB.compareTo(remA);
    });

    double totalActive = 0;
    double totalRepaid = 0;
    for (var s in summaries) {
      totalActive += s.totalAmount;
      totalRepaid += s.totalReturned;
    }

    final theme = Theme.of(context);
    final primaryColor = isDebts ? Colors.orange : Colors.indigo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header Card (Overall Total)
          GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: isDebts 
                ? [Colors.orange.shade800, Colors.orange.shade500] 
                : [Colors.indigo.shade800, Colors.indigo.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDebts ? AppStrings.totalBorrowed : AppStrings.totalLoan, 
                      style: const TextStyle(color: Colors.white70)
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Utils.formatCurrency(totalActive - totalRepaid), 
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${AppStrings.repaidPrefix}${Utils.formatCurrency(totalRepaid)}",
                      style: const TextStyle(fontSize: 13, color: Colors.white60)
                    ),
                  ],
                ),
                Icon(isDebts ? LucideIcons.alertCircle : Icons.handshake, size: 40, color: Colors.white30)
              ],
            ),
          ),
          const SizedBox(height: 20),

          // List of People
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summaries.length,
            itemBuilder: (ctx, index) {
              final summary = summaries[index];
              final remaining = summary.totalAmount - summary.totalReturned;
              final isFullyReturned = remaining <= 0.01; // Tolerance

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                       Row(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(10),
                             decoration: BoxDecoration(
                               color: isFullyReturned 
                                 ? Colors.green.withOpacity(0.1) 
                                 : primaryColor.withOpacity(0.1),
                               shape: BoxShape.circle
                             ),
                             child: Icon(
                               isFullyReturned ? LucideIcons.check : (isDebts ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight),
                               color: isFullyReturned ? Colors.green : primaryColor,
                               size: 20,
                             ),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   summary.name,
                                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                 ),
                                 Text(
                                   "${summary.loans.length} transactions",
                                   style: const TextStyle(fontSize: 12, color: Colors.grey),
                                 ),
                               ],
                             ),
                           ),
                           Text(
                             Utils.formatCurrency(summary.totalAmount),
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                           ),
                         ],
                       ),
                       const SizedBox(height: 12),
                       ClipRRect(
                         borderRadius: BorderRadius.circular(4),
                         child: LinearProgressIndicator(
                           value: summary.totalAmount == 0 ? 0 : (summary.totalReturned / summary.totalAmount),
                           backgroundColor: theme.dividerColor.withOpacity(0.2),
                           color: isFullyReturned ? Colors.green : primaryColor,
                           minHeight: 6,
                         ),
                       ),
                       const SizedBox(height: 12),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                            Text(
                              "${AppStrings.remaining} ${Utils.formatCurrency(remaining)}",
                              style: TextStyle(
                                fontSize: 13, 
                                color: isFullyReturned ? Colors.green : theme.textTheme.bodyMedium?.color
                              ),
                            ),
                            
                            // Repay Button
                            if (!isFullyReturned)
                            TextButton(
                                onPressed: () => _showRepayDialog(context, summary, provider, isDebts),
                                child: Text(isDebts ? AppStrings.repay : AppStrings.markAsReturned), 
                            ),
                         ],
                       )
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRepayDialog(BuildContext context, _PersonLoanSummary summary, ExpenseProvider provider, bool isDebts) {
    final controller = TextEditingController();
    final remaining = summary.totalAmount - summary.totalReturned;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDebts ? AppStrings.repayLoanTitle : AppStrings.receivePaymentTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text("${AppStrings.amountLabel}: ${Utils.formatCurrency(summary.totalAmount)}"), 
             Text("${AppStrings.remaining} ${Utils.formatCurrency(remaining)}"),
             const SizedBox(height: 16),
             TextField(
               controller: controller,
               keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isDebts ? AppStrings.amountLabel : AppStrings.refundAmountReceivedLabel,
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
               if (val > remaining + 0.01) { // Close enough 
                  // Could show error
                  return;
               }
               
               // Use Bulk Repayment
               provider.repayBeneficiary(summary.name, val, isDebts ? 'borrow' : 'loan');
               Navigator.pop(ctx);
            }, 
            child: Text(AppStrings.confirm)
          ),
        ],
      ),
    );
  }
  
  void _confirmDelete(BuildContext context, ExpenseModel item, ExpenseProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.deleteConfirmationTitle),
        content: Text(AppStrings.deleteConfirmationBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          TextButton(
            onPressed: () {
               provider.deleteExpense(item.id);
               Navigator.pop(ctx);
            },
            child: Text(AppStrings.delete, style: const TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }
}

class _PersonLoanSummary {
  final String name;
  final double totalAmount;
  final double totalReturned;
  final List<ExpenseModel> loans;

  _PersonLoanSummary({
    required this.name,
    required this.totalAmount,
    required this.totalReturned,
    required this.loans,
  });
}

