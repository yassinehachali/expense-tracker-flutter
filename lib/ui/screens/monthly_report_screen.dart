import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/expense_provider.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/event_model.dart';
import '../../data/models/category_model.dart'; // Added
import '../../core/utils.dart';
import '../../core/app_strings.dart';
import '../widgets/glass_container.dart';
import '../widgets/expense_card.dart';
import 'add_expense_screen.dart';
import 'event_detail_screen.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  late int _selectedMonth;
  late int _selectedYear;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default to current budget cycle month from provider context logic, 
    // but simplified to just "Current Month" initially
    _selectedMonth = now.month - 1; // 0-indexed
    _selectedYear = now.year;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth += delta;
      if (_selectedMonth > 11) {
        _selectedMonth = 0;
        _selectedYear++;
      } else if (_selectedMonth < 0) {
        _selectedMonth = 11;
        _selectedYear--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 1. Determine Date Range for Selected Month/Year
    final start = provider.getCycleStartDate(_selectedYear, _selectedMonth);
    
    // End Date calculation (Next start - 1 day)
    int nextMonth = _selectedMonth + 1;
    int nextYear = _selectedYear;
    if (nextMonth > 11) {
       nextMonth = 0;
       nextYear++;
    }
    final nextStart = provider.getCycleStartDate(nextYear, nextMonth);
    final end = nextStart.subtract(const Duration(days: 1));

    // 2. Filter Transactions in this Range
    final allExpenses = provider.expenses.where((e) {
      final date = DateTime.parse(e.date);
      // Compare dates (ignoring time mostly, but keeping logic consistent)
      final target = DateTime(date.year, date.month, date.day);
      return (target.isAfter(start) || target.isAtSameMomentAs(start)) && 
             (target.isBefore(end) || target.isAtSameMomentAs(end));
    }).toList();

    // 3. Apply Search & Category Filters
    List<ExpenseModel> filteredList = allExpenses;

    if (_filterCategory != null) {
      filteredList = filteredList.where((e) => e.category == _filterCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredList = filteredList.where((e) => 
         e.description.toLowerCase().contains(q) ||
         e.category.toLowerCase().contains(q) ||
         (e.loanee?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    // 4. Calculate Stats
    final salary = provider.getSalaryForMonth(_selectedYear, _selectedMonth);
    final rollover = provider.getRolloverForMonth(_selectedYear, _selectedMonth);
    final startingBalance = salary + rollover;

    double totalIncome = 0;
    double totalExpense = 0;
    double totalLoansGiven = 0;
    double totalLoansreturned = 0;

    // Use ALL expenses in range for accurate Totals (ignoring filters for the overview stats, OR matching filter?)
    // User typically wants "Monthly Analysis" to be the MONTH's analysis.
    // If I filter by "Food", "Starting Balance" doesn't make sense.
    // BUT the previous implementation used 'filteredList'. 
    // If I filter, the Balances show "Balance for this subset".
    // "Starting Balance" is global for the month.
    // "Income" (Transaction) depends on filter.
    // "Balance" depends on filter?
    // Let's stick to using 'filteredList' for Income/Spent, but keep Starting Balance as Global?
    // OR, if filter is active, maybe hide "Starting/Balance" and only show "You spent X on Food"?
    // The user didn't specify behavior under filter. 
    // SAFEST BET: Use 'allExpenses' (unfiltered) for the top cards to show the MONTH's overview, 
    // and let the list/chart show the filtered view. 
    // OR: If filter is active, just calculate totals of that filter.
    // However, "Starting Balance" is meaningless with a Category Filter.
    // Let's assume the Stats Cards always show the MONTH's Totals (Unfiltered), 
    // because "Monthly Analysis" implies a high level view.
    // If user wants to see "How much Food", they check the Chart or the List sum.
    // Let's use 'allExpenses' for the Top Cards.

    for (var item in allExpenses) {
      if (item.excludeFromBalance) continue; 

      if (item.type == 'income') {
        totalIncome += item.amount;
      } else if (item.type == 'loan') {
         if (item.isReturned) {
           totalLoansGiven += item.amount;
           totalLoansreturned += (item.returnedAmount > 0 ? item.returnedAmount : item.amount);
         } else {
           totalLoansGiven += item.amount;
         }
      } else if (item.type == 'expense') {
        totalExpense += item.amount;
      }
    }
    
    // Net Flow from Transactions
    final transactionNet = (totalIncome + totalLoansreturned) - (totalExpense + totalLoansGiven);
    
    // Final Balance
    final currentBalance = startingBalance + transactionNet;
    
    // Sort for list
    filteredList.sort((a, b) => b.date.compareTo(a.date));

    // Chart Data ... (Use filteredList for Chart/List)
    final Map<String, double> categoryTotals = {};
    for (var e in filteredList) {
      if (e.type == 'expense') {
        categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
      }
    }
    final sortedCategories = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Monthly Analysis"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Month Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.arrow_back_ios, size: 16)),
                  Column(
                    children: [
                      Text(DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth + 1)), 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("${Utils.formatDate(start)} - ${Utils.formatDate(end)}", 
                          style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                  IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.arrow_forward_ios, size: 16)),
                ],
              ),
            ),
          ),

          // Stats Cards (Scrollable Row for 4 items)
          top_stats_section(startingBalance, totalIncome, totalExpense, totalLoansGiven, totalLoansreturned, currentBalance),

          const SizedBox(height: 16),

          // Filters (Search + Categories)
          Container(
             height: 50,
             padding: const EdgeInsets.symmetric(horizontal: 16),
             child: ListView(
               scrollDirection: Axis.horizontal,
               children: [
                 // Search Trigger
                 SizedBox(
                   width: 150,
                   child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      filled: true,
                      fillColor: theme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (val) => setState(() => _searchQuery = val),
                   ),
                 ),
                 const SizedBox(width: 8),
                 // Category Filter
                 ActionChip(
                   avatar: _filterCategory != null ? const Icon(Icons.check, size: 14) : null,
                   label: Text(_filterCategory ?? "All Categories"),
                   onPressed: () {
                     _showCategoryPicker(context, provider);
                   },
                   backgroundColor: _filterCategory != null ? Colors.indigo : theme.cardColor,
                   labelStyle: TextStyle(color: _filterCategory != null ? Colors.white : null),
                 ),
                  if (_filterCategory != null)
                   Padding(
                     padding: const EdgeInsets.only(left: 8),
                     child: ActionChip(
                       label: const Icon(Icons.close, size: 14),
                       onPressed: () => setState(() => _filterCategory = null),
                     ),
                   ),
               ],
             ),
          ),
          
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Chart (Collapsible or just on top)
                if (sortedCategories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    height: 200,
                    margin: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: sortedCategories.map((e) {
                                final catDef = provider.categories.firstWhere((c) => c.name == e.key, orElse: () => CategoryModel(name: e.key, icon: 'HelpCircle', color: '#808080')); // Fallback
                                return PieChartSectionData(
                                  value: e.value,
                                  color: Utils.hexToColor(catDef.color),
                                  title: '',
                                  radius: 30,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: ListView.builder(
                            itemCount: sortedCategories.length > 5 ? 5 : sortedCategories.length, // Top 5
                            itemBuilder: (ctx, idx) {
                               final entry = sortedCategories[idx];
                               final catDef = provider.categories.firstWhere((c) => c.name == entry.key, orElse: () => CategoryModel(name: entry.key, icon: 'HelpCircle', color: '#808080'));
                               final pct = (entry.value / (totalExpense == 0 ? 1 : totalExpense) * 100).toStringAsFixed(1);
                               return Padding(
                                 padding: const EdgeInsets.symmetric(vertical: 2),
                                 child: Row(
                                   children: [
                                     CircleAvatar(radius: 6, backgroundColor: Utils.hexToColor(catDef.color)),
                                     const SizedBox(width: 8),
                                     Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                     Text("${Utils.formatCurrency(entry.value)} ($pct%)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                   ],
                                 ),
                               );
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                // Transactions List
                if (filteredList.isEmpty)
                   SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Text("No transactions found", style: TextStyle(color: Colors.grey))))),

                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final expense = filteredList[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ExpenseCard(expense: expense, onTap: () {
                           // Show Edit/Delete (Simple version)
                        }),
                      );
                    },
                    childCount: filteredList.length,
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, ExpenseProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text("Select Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12),
                   itemCount: provider.categories.length,
                   itemBuilder: (ctx, index) {
                      final cat = provider.categories[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _filterCategory = cat.name);
                          Navigator.pop(ctx);
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Utils.hexToColor(cat.color).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Utils.getIcon(cat.icon), color: Utils.hexToColor(cat.color)),
                            ),
                            const SizedBox(height: 4),
                            Text(cat.name, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      );
                   },
                 ),
              ),
            ],
          ),
        );
      }
    );
  }
  Widget top_stats_section(double startingBalance, double totalIncome, double totalExpense, double totalLoansGiven, double totalLoansReturned, double currentBalance) {
     return SizedBox(
       height: 90, // Fixed height for the row
       child: ListView(
         scrollDirection: Axis.horizontal,
         physics: const BouncingScrollPhysics(),
         padding: const EdgeInsets.symmetric(horizontal: 16),
         children: [
             SizedBox(width: 140, child: _StatCard(label: "Starting", amount: startingBalance, color: Colors.purpleAccent, icon: Icons.wallet)),
             const SizedBox(width: 12),
             SizedBox(width: 140, child: _StatCard(label: "Income", amount: totalIncome, color: Colors.greenAccent, icon: Icons.arrow_downward)),
             const SizedBox(width: 12),
             SizedBox(width: 140, child: _StatCard(label: "Spent", amount: totalExpense + (totalLoansGiven - totalLoansReturned), color: Colors.redAccent, icon: Icons.arrow_upward)),
             const SizedBox(width: 12),
             SizedBox(width: 140, child: _StatCard(label: "Balance", amount: currentBalance, color: Colors.blueAccent, icon: Icons.account_balance)),
         ],
       ),
    );
  }
}

class _StatCard extends StatelessWidget {

  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _StatCard({required this.label, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
               Icon(icon, size: 14, color: color),
               const SizedBox(width: 4),
               Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
             ],
           ),
           const SizedBox(height: 8),
           FittedBox(
             fit: BoxFit.scaleDown,
             child: Text(Utils.formatCurrency(amount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
           ),
        ],
      ),
    );
  }
}
