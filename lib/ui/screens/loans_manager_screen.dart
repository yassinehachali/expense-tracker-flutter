import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/app_strings.dart';
import '../../core/utils.dart';
import '../../providers/expense_provider.dart';
import '../../data/models/expense_model.dart';
import '../widgets/glass_container.dart';
import 'add_expense_screen.dart';

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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine language-specific tab order or keeping fixed?
    // Fixed: Tab 0 = Lendings (I Lent), Tab 1 = Debts (I Borrowed)
    // Adjust strings accordingly.
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.loansManager),
        centerTitle: true,
            bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: AppStrings.filterLoans, icon: const Icon(LucideIcons.arrowUpRight)), 
            Tab(text: AppStrings.borrow, icon: const Icon(LucideIcons.arrowDownLeft)), 
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
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
           final type = _tabController.index == 0 ? 'loan' : 'borrow';
           _showAddDialog(context, type);
        },
        label: Text(AppStrings.addTransaction),
        icon: const Icon(LucideIcons.plus),
        backgroundColor: _tabController.index == 0 ? Colors.indigo : Colors.orange,
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

    final sorted = List<ExpenseModel>.from(loans)
      ..sort((a, b) => b.date.compareTo(a.date));

    double totalActive = 0;
    double totalRepaid = 0;
    for (var l in sorted) {
      totalActive += l.amount;
      totalRepaid += l.returnedAmount;
    }

    final theme = Theme.of(context);
    final primaryColor = isDebts ? Colors.orange : Colors.indigo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header Card
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
                      Utils.formatCurrency(totalActive), 
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

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sorted.length,
            itemBuilder: (ctx, index) {
              final item = sorted[index];
              final remaining = item.amount - item.returnedAmount;
              final isFullyReturned = item.isReturned;

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
                                   item.description.isNotEmpty ? item.description : (item.loanee ?? AppStrings.unknownLender),
                                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                 ),
                                 Text(
                                   Utils.formatDate(DateTime.parse(item.date)),
                                   style: const TextStyle(fontSize: 12, color: Colors.grey),
                                 ),
                               ],
                             ),
                           ),
                           Text(
                             Utils.formatCurrency(item.amount),
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                           ),
                         ],
                       ),
                       const SizedBox(height: 12),
                       ClipRRect(
                         borderRadius: BorderRadius.circular(4),
                         child: LinearProgressIndicator(
                           value: item.amount == 0 ? 0 : (item.returnedAmount / item.amount),
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
                            
                            Row(
                              children: [
                                if (!isFullyReturned)
                                  TextButton(
                                    onPressed: () => _showRepayDialog(context, item, provider, isDebts),
                                    child: Text(isDebts ? AppStrings.repay : AppStrings.markAsReturned), 
                                  ),
                                PopupMenuButton<String>(
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                       Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(expenseToEdit: item)));
                                    } else if (val == 'delete') {
                                       _confirmDelete(context, item, provider);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(value: 'edit', child: Text(AppStrings.editTransaction)),
                                    PopupMenuItem(value: 'delete', child: Text(AppStrings.delete, style: const TextStyle(color: Colors.red))),
                                  ],
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(Icons.more_vert, size: 20, color: Colors.grey),
                                  ),
                                )
                              ],
                            )
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

  void _showRepayDialog(BuildContext context, ExpenseModel loan, ExpenseProvider provider, bool isDebts) {
    final controller = TextEditingController();
    final remaining = loan.amount - loan.returnedAmount;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDebts ? AppStrings.repayLoanTitle : AppStrings.receivePaymentTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text("${AppStrings.amountLabel}: ${Utils.formatCurrency(loan.amount)}"), // AppStrings.amountLabel
             Text("${AppStrings.remaining}${Utils.formatCurrency(remaining)}"),
             const SizedBox(height: 16),
             TextField(
               controller: controller,
               keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isDebts ? AppStrings.amountLabel : AppStrings.refundAmountReceivedLabel, // or similar
                  hintText: "0.00",
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
               if (val > remaining + 0.01) { // Close enough float tolerance
                  // Error
                  return;
               }
               // Reuse repayBorrowing because logic (amount returned increase) is symmetric
               provider.repayBorrowing(loan, val);
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
