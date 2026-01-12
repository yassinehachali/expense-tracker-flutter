// File: lib/ui/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import '../../core/app_strings.dart'; 
import '../../data/services/notification_service.dart'; // Add import 
import 'package:intl/intl.dart'; // Add intl import
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'transactions_screen.dart'; // Not needed if we use callback
import 'add_expense_screen.dart'; // Needed for Edit
import 'insurance_screen.dart'; // Redirect for insurance claims
import 'event_detail_screen.dart'; // Added Import
import '../../data/models/event_model.dart'; // Added Import
import '../../data/models/expense_model.dart'; // Added Explicit Import
import '../../providers/expense_provider.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../widgets/summary_card.dart';
import '../widgets/expense_card.dart';
import '../widgets/glass_container.dart';
import 'add_expense_screen.dart';
import '../../data/models/category_model.dart';
import '../../providers/expense_provider.dart';
import '../../core/theme.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onViewAll;
  const DashboardScreen({super.key, this.onViewAll});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isPieChart = true;
  int? _checkedYear;
  int? _checkedMonth;

  @override
  void initState() {
    super.initState();
    // Check Alarm Permissions on startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       await NotificationService().checkAndroidScheduleExactAlarmPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    
    // Auto-prompt for Rollover
    // We check if we are on a new view (year/month changed) or haven't checked yet
    if (!provider.isLoading && (_checkedYear != provider.selectedYear || _checkedMonth != provider.selectedMonth)) {
      _checkedYear = provider.selectedYear;
      _checkedMonth = provider.selectedMonth;
      
      // Delay to allow UI to render first
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (provider.pendingRolloverAmount > 0) {
            _showRolloverDialog(context, provider);
         }
      });
    }

    final stats = provider.dashboardStats;
    final chartData = provider.chartData;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Mixed List Logic
    final mixedList = _getMixedList(provider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Date Selectors
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              
              final headerTitle = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.wallet, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.appTitle,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppStrings.welcomeBack,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final dateSelectors = GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     // Month Dropdown
                    DropdownButton<int>(
                      value: provider.selectedMonth,
                      underline: Container(),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      items: List.generate(12, (index) { // Use 12 instead of MONTHS.length
                        final date = DateTime(2025, index + 1); // Year doesn't matter for month name
                        return DropdownMenuItem(
                          value: index,
                          child: Text(DateFormat.MMMM(AppStrings.language).format(date)), // Full name localized
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) provider.setMonth(val);
                      },
                    ),
                    const SizedBox(width: 12),
                    Container(height: 16, width: 1, color: theme.dividerColor),
                    const SizedBox(width: 12),
                    // Year Dropdown
                    DropdownButton<int>(
                      value: provider.selectedYear,
                      underline: Container(),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      items: List.generate(5, (index) {
                        final year = DateTime.now().year - 2 + index; // e.g. 2023-2027
                         return DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) provider.setYear(val);
                      },
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                // Mobile Layout: Compact Single Row
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Compact Title (Icon + Text)
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6), // Smaller padding
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
                              borderRadius: BorderRadius.circular(8), // Smaller radius
                            ),
                            child: const Icon(LucideIcons.wallet, color: Colors.white, size: 18), // Smaller Icon
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              AppStrings.appTitle,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), // Smaller Text
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Compact Date Selector
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Tighter padding
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Month Dropdown (Smaller text)
                          DropdownButton<int>(
                            value: provider.selectedMonth,
                            underline: Container(),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 14),
                            isDense: true, // Reduces height
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                            items: List.generate(12, (index) {
                               final date = DateTime(2025, index + 1);
                              return DropdownMenuItem(
                                value: index,
                                child: Text(DateFormat.MMM(AppStrings.language).format(date)), // Short month localized
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) provider.setMonth(val);
                            },
                          ),
                          const SizedBox(width: 8),
                          Container(height: 12, width: 1, color: theme.dividerColor),
                          const SizedBox(width: 8),
                          // Year Dropdown
                          DropdownButton<int>(
                            value: provider.selectedYear,
                            underline: Container(),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 14),
                            isDense: true,
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                            items: List.generate(5, (index) {
                              final year = DateTime.now().year - 2 + index;
                              return DropdownMenuItem(
                                value: year,
                                child: Text(year.toString()),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) provider.setYear(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                // Desktop/Tablet Layout: Full Size
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: headerTitle),
                    dateSelectors,
                  ],
                );
              }
            }
          ),
          const SizedBox(height: 24),

          // Total Balance / Remaining
          GlassContainer(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            gradient: LinearGradient(
              colors: isDark 
                ? [const Color(0xFF6366f1), const Color(0xFF4338ca)] 
                : [const Color(0xFF6366f1), const Color(0xFF818cf8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppStrings.totalRemaining, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                    InkWell(
                      onTap: () => provider.togglePrivacy(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          provider.isPrivacyEnabled ? LucideIcons.eye : LucideIcons.eyeOff, 
                          color: Colors.white, 
                          size: 18
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  provider.isPrivacyEnabled ? Utils.formatCurrency(stats['remaining'] ?? 0) : "*****",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                     _MiniStat(
                       label: AppStrings.income,
                       amount: stats['totalIncome'] ?? 0,
                       icon: LucideIcons.arrowUpCircle,
                       color: Colors.greenAccent,
                       isVisible: provider.isPrivacyEnabled,
                     ),
                     Container(height: 40, width: 1, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 24)),
                     _MiniStat(
                       label: AppStrings.spent,
                       amount: stats['totalSpent'] ?? 0,
                       icon: LucideIcons.arrowDownCircle,
                       color: Colors.redAccent,
                       isVisible: provider.isPrivacyEnabled,
                     ),
                  ],
                )
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Chart Section
          GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Icon(LucideIcons.pieChart, size: 18, color: Colors.orange),
                        ),
                        const SizedBox(width: 12),
                        Text(AppStrings.topSpending, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    // Toggle Button
                    Row(
                      children: [
                        _ChartToggle(
                          icon: LucideIcons.pieChart, 
                          isSelected: _isPieChart, 
                          onTap: () => setState(() => _isPieChart = true)
                        ),
                        const SizedBox(width: 8),
                        _ChartToggle(
                          icon: LucideIcons.barChart, 
                          isSelected: !_isPieChart, 
                          onTap: () => setState(() => _isPieChart = false)
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: chartData.isEmpty
                      ? Center(child: Text(AppStrings.noDataMonth, style: theme.textTheme.bodyMedium))
                      : (_isPieChart 
                        ? _buildPieChart(chartData, stats['totalSpent'] ?? 1, provider) 
                        : _buildBarChart(chartData, provider, theme)
                      ),
                ),
                
                const SizedBox(height: 24),
                
                // Detailed Legend
                if (chartData.isNotEmpty)
                  Column(
                    children: chartData.map((data) {
                      final details = _getCategoryDetails(data, provider);
                      final percent = (details.value / (stats['totalSpent']! == 0 ? 1 : stats['totalSpent']!) * 100);
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: details.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Utils.getIconData(details.iconKey), color: details.color, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(details.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(Utils.formatCurrency(details.value), style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${percent.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                              ],
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: LinearProgressIndicator(
                                value: percent / 100, 
                                backgroundColor: theme.dividerColor.withOpacity(0.2),
                                color: details.color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recent Activity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.recentActivity,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: widget.onViewAll, 
                child: Text(AppStrings.viewAll)
              )
            ],
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mixedList.take(5).length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, index) {
               final item = mixedList[index];
               
               if (item is EventModel) {
                  return _EventCard(event: item);
               }
               
               final expense = item as ExpenseModel;
               return ExpenseCard(
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
                              if (expense.type != 'rollover')
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: Text(AppStrings.editTransaction),
                                  onTap: () {
                                    Navigator.pop(ctx);

                                    // Check if this expense is linked to a pending insurance claim
                                    bool isInsurance = false;
                                    try {
                                      final claim = provider.insuranceClaims.firstWhere(
                                        (c) => c.relatedExpenseId == expense.id && c.status == 'pending',
                                      );
                                      isInsurance = true;
                                    } catch (_) {}

                                    if (isInsurance) {
                                      // Redirect to Insurance Screen
                                      String? claimId;
                                      try {
                                         claimId = provider.insuranceClaims.firstWhere(
                                          (c) => c.relatedExpenseId == expense.id && c.status == 'pending',
                                        ).id;
                                      } catch (_) {}
                                      
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => InsuranceScreen(initialEditClaimId: claimId)));
                                      
                                    } else {
                                      // Standard Edit
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(expenseToEdit: expense)));
                                    }
                                  },
                                ),
                            if (expense.type == 'loan' && !expense.isReturned)
                              ListTile(
                                leading: const Icon(LucideIcons.banknote, color: Colors.green),
                                title: Text(AppStrings.recordRepayment),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _showRepaymentDialog(context, expense, provider);
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
               ); 
            },
          ),
        ],
      ),
    );
  }

  List<dynamic> _getMixedList(ExpenseProvider provider) {
     // 1. Get Expenses for current view (filtered by Provider mostly)
     // BUT we must exclude those that belong to an Event
     // 1. Get Expenses for current view (filtered by Provider mostly)
     // BUT we must exclude those that belong to an Event
     final viewExpenses = provider.filteredExpenses.where((e) => e.eventId == null || e.eventId!.trim().isEmpty).toList();

     // 2. Get Events relevant to current view?
     // User requirement: "reactive that every time we add a new expense to the event , the event becomes first"
     // This implies we should show events that were UPDATED in this timeframe.
     final start = provider.currentCycleStart;
     final end = provider.currentCycleEnd;
     
     final activeEvents = provider.events.where((e) {
        final lastUp = DateTime.parse(e.lastUpdated);
        return lastUp.isAfter(start) && lastUp.isBefore(end);
     }).toList();

     // 3. Merge
     final List<dynamic> mixed = [...viewExpenses, ...activeEvents];

     // 4. Sort
     mixed.sort((a, b) {
        DateTime dateA;
        if (a is ExpenseModel) dateA = DateTime.parse(a.date);
        else dateA = DateTime.parse((a as EventModel).lastUpdated);

        DateTime dateB;
        if (b is ExpenseModel) dateB = DateTime.parse(b.date);
        else dateB = DateTime.parse((b as EventModel).lastUpdated);
        
        return dateB.compareTo(dateA); // Descending
     });

     return mixed;
  }

  Widget _buildPieChart(List<Map<String, dynamic>> chartData, double totalSpent, ExpenseProvider provider) {
     return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 40,
        sections: chartData.map((data) {
          final details = _getCategoryDetails(data, provider);
          final percent = (details.value / (totalSpent == 0 ? 1 : totalSpent) * 100);

          return PieChartSectionData(
            color: details.color,
            value: details.value,
            title: '${percent.toStringAsFixed(0)}%',
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
            radius: 60,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> chartData, ExpenseProvider provider, ThemeData theme) {
    // Find max value for Y-axis scaling
    double maxVal = 0;
    for (var data in chartData) {
      if ((data['value'] as num).toDouble() > maxVal) maxVal = (data['value'] as num).toDouble();
    }
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.2,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
             sideTitles: SideTitles(
               showTitles: true,
               getTitlesWidget: (val, meta) {
                 if (val.toInt() >= 0 && val.toInt() < chartData.length) {
                   final details = _getCategoryDetails(chartData[val.toInt()], provider);
                   // Show Icon or first letter? Icon is better but complex in FlTitles.
                   // Let's show first 3 chars
                   return Padding(
                     padding: const EdgeInsets.only(top: 8),
                     child: Text(details.name.substring(0, details.name.length > 3 ? 3 : details.name.length), style: const TextStyle(fontSize: 10)),
                   );
                 }
                 return const SizedBox();
               }
             )
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: chartData.asMap().entries.map((entry) {
           final index = entry.key;
           final data = entry.value;
           final details = _getCategoryDetails(data, provider);
           
           return BarChartGroupData(
             x: index,
             barRods: [
               BarChartRodData(
                 toY: details.value,
                 color: details.color,
                 width: 16,
                 borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                 backDrawRodData: BackgroundBarChartRodData(
                   show: true,
                   toY: maxVal * 1.2,
                   color: theme.dividerColor.withOpacity(0.1),
                 )
               )
             ]
           );
        }).toList(),
      ),
    );
  }

  _CategoryDetails _getCategoryDetails(Map<String, dynamic> data, ExpenseProvider provider) {
      final name = data['name'] as String;
      final value = (data['value'] as num).toDouble();
      final isLoan = name.toLowerCase() == 'loan' || name.toLowerCase() == 'lending';
      final isIncome = name.toLowerCase() == 'income';
      
      Color color;
      String iconKey;

      if (isLoan) {
        color = Colors.orange;
        iconKey = 'Handshake';
      } else if (name == 'Borrow Repayment') {
        color = Colors.orangeAccent;
        iconKey = 'Coins';
      } else if (isIncome) {
        color = Colors.green;
        iconKey = 'Wallet';
      } else {
        // Check if this is an Event Name (from chart grouping)
        try {
          final event = provider.events.firstWhere((e) => e.name == name);
           color = Colors.purple;
           iconKey = 'Plane'; // User requested Plane icon for events (or specific to travel events)
        } catch (_) {
          // Not an event, check Categories
          final allCats = provider.categories;
          CategoryModel? catConfig;
          try {
            catConfig = allCats.firstWhere((c) => c.name.toLowerCase() == name.toLowerCase());
          } catch (_) {}
          
          color = catConfig != null 
              ? hexToColor(catConfig.color) 
              : hexToColor('#999999');
          iconKey = catConfig?.icon ?? 'MoreHorizontal';
        }
      }
      
      return _CategoryDetails(AppStrings.getCategoryName(name), value, color, iconKey);
  }

  void _showRepaymentDialog(BuildContext context, dynamic expense, ExpenseProvider provider) {
    final controller = TextEditingController();
    final remaining = expense.amount - expense.returnedAmount;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.recordRepayment),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${AppStrings.totalLoan}${Utils.formatCurrency(expense.amount)}"),
            Text("${AppStrings.remaining}${Utils.formatCurrency(remaining)}"),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppStrings.amountReturned,
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
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.errorAmountExceeds)));
                 return;
              }
              
              provider.updateRepayment(expense, val);
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

class _CategoryDetails {
  final String name;
  final double value;
  final Color color;
  final String iconKey;
  _CategoryDetails(this.name, this.value, this.color, this.iconKey);
}

class _ChartToggle extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChartToggle({required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? theme.primaryColor : Colors.transparent)
        ),
        child: Icon(icon, size: 16, color: isSelected ? theme.primaryColor : theme.iconTheme.color?.withOpacity(0.5)),
      ),
    );
  }
}

void _showRolloverDialog(BuildContext context, ExpenseProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(LucideIcons.wallet, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(AppStrings.rolloverAvailable)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.rolloverMessage),
            const SizedBox(height: 12),
            Center(
              child: Text(
                Utils.formatCurrency(provider.pendingRolloverAmount),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
            const SizedBox(height: 12),
            Text(AppStrings.applyRolloverConfirm),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.ignoreRollover(provider.selectedYear, provider.selectedMonth);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: Text(AppStrings.no ?? "No"),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              provider.acceptRollover(provider.selectedYear, provider.selectedMonth);
            },
            icon: const Icon(Icons.check, size: 16),
            label: Text(AppStrings.yesApply),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

class _MiniStat extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isVisible;

  const _MiniStat({
    required this.label, 
    required this.amount, 
    required this.icon, 
    required this.color,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isVisible ? Utils.formatCurrency(amount) : "*****",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
         Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)));
      },
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 4),
                Text(Utils.formatDate(DateTime.parse(event.lastUpdated)), style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String iconKey;
  final double size;
  final Color borderColor;

  const _Badge({
    required this.iconKey,
    required this.size,
    required this.borderColor,
  });

  // We can't import CategoryIcon easily due to circular deps if we are not careful,
  // but let's assume we can or duplicate for now safely.
  // Actually dashboard_screen imports expense_card which imports category_icon.
  // But wait, category_icon is in widgets.
  
  @override
  Widget build(BuildContext context) {
     // Re-implementing mini-icon logic safely
     return Container(
       width: size,
       height: size,
       decoration: BoxDecoration(
         color: Colors.white,
         shape: BoxShape.circle,
         border: Border.all(color: borderColor, width: 2),
         boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
         ]
       ),
       child: Center(
         child: Icon(
           // Mapping logic or just fallback
           Icons.category, 
           size: size * 0.5, 
           color: borderColor
         ),
       ),
     );
  }
}
