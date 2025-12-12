// File: lib/ui/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'transactions_screen.dart'; // Not needed if we use callback
import 'add_expense_screen.dart'; // Needed for Edit
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final stats = provider.dashboardStats;
    final chartData = provider.chartData;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Date Selectors
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expense Tracker',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Welcome back',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GlassContainer(
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
                      items: List.generate(MONTHS.length, (index) {
                        return DropdownMenuItem(
                          value: index,
                          child: Text(MONTHS[index]),
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
              ),
            ],
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
                    Text('Total Remaining', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                    const Icon(LucideIcons.wallet, color: Colors.white, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  Utils.formatCurrency(stats['remaining'] ?? 0),
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
                       label: 'Income',
                       amount: stats['totalIncome'] ?? 0,
                       icon: LucideIcons.arrowUpCircle,
                       color: Colors.greenAccent,
                     ),
                     Container(height: 40, width: 1, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 24)),
                     _MiniStat(
                       label: 'Spent',
                       amount: stats['totalSpent'] ?? 0,
                       icon: LucideIcons.arrowDownCircle,
                       color: Colors.redAccent,
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
                          child: const Icon(LucideIcons.pieChart, size: 18, color: Colors.orange),
                        ),
                        const SizedBox(width: 12),
                        const Text('Top Spending', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      ? Center(child: Text("No data for this month", style: theme.textTheme.bodyMedium))
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
                'Recent Activity',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: widget.onViewAll, 
                child: const Text('View All')
              )
            ],
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: provider.filteredExpenses.take(5).length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, index) {
               final expense = provider.filteredExpenses[index];
               return ExpenseCard(
                 expense: expense,
                 onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: theme.cardColor,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (ctx) => SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text("Edit Transaction"),
                              onTap: () {
                                Navigator.pop(ctx);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(expenseToEdit: expense)));
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete, color: Colors.red),
                              title: const Text("Delete Transaction", style: TextStyle(color: Colors.red)),
                              onTap: () async {
                                Navigator.pop(ctx);
                                await provider.deleteExpense(expense.id);
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
      final isLoan = name.toLowerCase() == 'loan';
      final isIncome = name.toLowerCase() == 'income';
      
      Color color;
      String iconKey;

      if (isLoan) {
        color = Colors.orange;
        iconKey = 'Handshake';
      } else if (isIncome) {
        color = Colors.green;
        iconKey = 'Wallet';
      } else {
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
      
      return _CategoryDetails(name, value, color, iconKey);
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

class _MiniStat extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _MiniStat({required this.label, required this.amount, required this.icon, required this.color});

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
          Utils.formatCurrency(amount),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
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
