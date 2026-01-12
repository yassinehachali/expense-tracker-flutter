import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import '../../core/utils.dart';
import '../../core/app_strings.dart';
import '../../data/models/fixed_charge_model.dart';
import '../../providers/expense_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/category_selector.dart'; // Added Import

class FixedChargesScreen extends StatelessWidget {
  const FixedChargesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to provider
    final provider = Provider.of<ExpenseProvider>(context);
    final charges = provider.fixedCharges;
    final theme = Theme.of(context);

    // Group by Auto vs Manual
    final autoCharges = charges.where((c) => c.isAutoApplied).toList();
    final manualCharges = charges.where((c) => !c.isAutoApplied).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.fixedCharges),
      ),
      body: charges.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.calendarClock, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.noFixedCharges,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.fixedChargesSubtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total Summary Card
                GlassContainer(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          AppStrings.totalFixedCharges,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                           Utils.formatCurrency(charges.fold(0.0, (sum, item) => sum + item.amount)),
                           style: TextStyle(
                             fontSize: 32,
                             fontWeight: FontWeight.bold,
                             color: theme.colorScheme.primary,
                           ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (autoCharges.isNotEmpty) ...[
                  _buildSectionHeader(AppStrings.autoApply),
                  ...autoCharges.map((c) => _ChargeTile(charge: c)),
                  const SizedBox(height: 24),
                ],
                
                if (manualCharges.isNotEmpty) ...[
                  _buildSectionHeader(AppStrings.manualChargesHeader),
                  ...manualCharges.map((c) => _ChargeTile(charge: c)),
                  
                  Builder(
                    builder: (context) {
                      // Calculate pending count for UI feedback
                      // Note: This rebuilds when provider notifies, so it's accurate
                      final pendingCount = manualCharges.where((c) => !provider.isChargeAppliedInCycle(c.id, provider.selectedYear, provider.selectedMonth)).length;
                      
                      if (pendingCount == 0) {
                         return Padding(
                           padding: const EdgeInsets.all(16.0),
                           child: Center(
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 const Icon(Icons.check_circle, color: Colors.green), 
                                 const SizedBox(width: 8), 
                                 Text(AppStrings.allManualApplied, style: const TextStyle(color: Colors.green))
                               ],
                             ),
                           ),
                         );
                      }

                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          GlassContainer(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                   Text(
                                    AppStrings.applyManualTitle,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                                   ),
                                   const SizedBox(height: 8),
                                   Text(
                                     "Add $pendingCount pending charges to your current transaction list.",
                                     textAlign: TextAlign.center,
                                     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                   ),
                                   const SizedBox(height: 16),
                                   Row(
                                     children: [
                                       Expanded(
                                         child: ElevatedButton.icon(
                                           onPressed: () => _confirmApply(context, provider, false),
                                           icon: const Icon(LucideIcons.calendarCheck, size: 16),
                                           label: Text(AppStrings.applyAllThisMonth),
                                           style: ElevatedButton.styleFrom(
                                             backgroundColor: theme.colorScheme.primaryContainer,
                                             foregroundColor: theme.colorScheme.onPrimaryContainer,
                                           ),
                                         ),
                                       ),
                                     ],
                                   ),
                                     const SizedBox(height: 8),
                                   Row(
                                     children: [
                                       Expanded(
                                         child: OutlinedButton(
                                           onPressed: () => _confirmApply(context, provider, true),
                                           child: Text(AppStrings.applyAllNextMonth),
                                         ),
                                       ),
                                     ],
                                   )
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  )
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, null),
        label: Text(AppStrings.addCharge),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 1.0,
          color: Colors.grey
        ),
      ),
    );
  }

  void _confirmApply(BuildContext context, ExpenseProvider provider, bool isNextMonth) {
    final year = provider.selectedYear; // This is purely view state, careful
    final month = provider.selectedMonth; // 0-indexed
    
    // Logic: "Apply to This Month" means current VIEW month. 
    // "Apply to Next Month" means view month + 1.
    
    int targetYear = year;
    int targetMonth = isNextMonth ? month + 1 : month;
    if (targetMonth > 11) {
      targetMonth = 0;
      targetYear++;
    }

    final monthName = Utils.getMonthName(targetMonth);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.applyChargeTitle), // Using simplified title or interpolate manually later? Let's use generic for now or interpolate
        content: Text(AppStrings.manualChargesConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.applyFixedChargesToCycle(
                  targetYear, 
                  targetMonth, 
                  manualOnly: true,
                  customDate: DateTime.now() // Logic: Manual Apply uses "Now"
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppStrings.chargesApplied)),
                );
              }
            },
            child: Text(AppStrings.apply),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, FixedChargeModel? charge) {
    final nameCtrl = TextEditingController(text: charge?.name);
    final amountCtrl = TextEditingController(text: charge?.amount.toString());
    String selectedCategory = charge?.category ?? 'Others';
    int selectedDay = charge?.dayOfMonth ?? 1;
    bool isAuto = charge?.isAutoApplied ?? false;
    bool delayedAutoPay = charge?.delayedAutoPay ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(charge == null ? AppStrings.addFixedCharge : "Edit Charge"), // "Edit Charge" needs adding? Let's use generic or add it
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: AppStrings.categoryNameHint), // "Name (e.g. Rent)" -> reusing categoryNameHint ("Category Name") or add new? "Name" is better. Let's use categoryNameHint for now as it's close or add new.
                    // Actually let's just leave some common words if no exact match, but user asked for ALL.
                    // "Name (e.g. Rent)" -> I should add this key.
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    decoration: InputDecoration(labelText: AppStrings.amountLabel, prefixText: "${Utils.currencySymbol} "),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  // Simple Category Dropdown for now (can enhance to use CategoryModel list)
                  // Using Provider to get real categories
                  // Category Dropdown
                  // Category Selector
                  Consumer<ExpenseProvider>(
                    builder: (context, p, _) {
                      final cats = p.categories;
                      
                      // Safety: Ensure valid category selection
                      String currentSelection = selectedCategory;
                      bool matchFound = cats.any((c) => c.name == currentSelection);
                      
                      // Fallback logic if selection invalid
                      if (!matchFound) {
                        if (cats.any((c) => c.name == 'Others')) {
                          currentSelection = 'Others';
                        } else if (cats.isNotEmpty) {
                          currentSelection = cats.first.name;
                        }
                      }

                      return Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(AppStrings.categoryLabel, style: TextStyle(color: Theme.of(context).hintColor)), // Match label style
                           const SizedBox(height: 8),
                           CategorySelector(
                             categories: cats,
                             selectedCategory: currentSelection,
                             onCategorySelected: (val) {
                               setState(() => selectedCategory = val);
                             },
                           ),
                         ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      // Logic to determine the split
                      // Capture provider from the parent function scope explicitly if needed, or lookup again.
                      // Since 'provider' variable is available in _showAddEditDialog, we can use it directly if closures work,
                      // but the error suggests 'provider' is not found?
                      // Ah, it's because I pasted this into a Builder block where 'provider' might be shadowed or I assumed it was a class member.
                      // 'provider' is a local variable in _showAddEditDialog. It should be captured.
                      // BUT if I cannot access it, I will re-fetch it.
                      // Re-fetching provider inside builder context safely:
                      final provider = Provider.of<ExpenseProvider>(context, listen: false);

                      final s = provider.getSettingsForMonth(provider.selectedYear, provider.selectedMonth); 
                      
                      final startDay = s.startDay;
                      final offset = s.monthOffset;
                      
                      // Calculate "Previous Month" (Start side) Name
                      DateTime startSideDate = DateTime(provider.selectedYear, provider.selectedMonth + 1 + offset);
                      String startSideName = Utils.getMonthName(startSideDate.month - 1); 
                      
                      // Calculate "Current Month" (End side) Name
                      DateTime endSideDate = DateTime(provider.selectedYear, provider.selectedMonth + 1 + offset + 1);
                      String endSideName = Utils.getMonthName(endSideDate.month - 1);
                      
                      // Range A: [startDay .. EndOfStartMonth]
                      int maxDayA = Utils.getDaysInMonth(startSideDate.year, startSideDate.month);
                      List<int> rangeA = [];
                      if (startDay <= maxDayA) {
                         // Fix: explicit int cast or definition for length
                         int len = maxDayA - startDay + 1;
                         rangeA = List.generate(len, (i) => startDay + i);
                      }
                      
                      // Range B: [1 .. startDay - 1]
                      // Note: End side is usually the main month.
                      // Limit is startDay - 1. But wait, what if end month has fewer days?
                      // The cycle ends at startDay of next month.
                      // So we go usually up to startDay - 1.
                      // Exception: If End Month length < startDay, we stop at End Month length.
                      int maxDayB = Utils.getDaysInMonth(endSideDate.year, endSideDate.month);
                      int limitB = startDay - 1;
                      if (limitB > maxDayB) limitB = maxDayB;
                      
                      List<int> rangeB = List.generate(limitB, (i) => i + 1);
                      
                      // State for this widget (we need a local state variable for "Selected Period").
                      // We can assume: If selectedDay is in Range A, select A. Else B.
                      // BUT: This is ambiguous if both have Day 1? No, Range A starts at startDay.
                      // Range B ends at startDay - 1.
                      // They are mutually exclusive sets of integers?
                      // NOT NECESSARILY.
                      // If Start Day = 1. Range A: 1..31. Range B: Empty.
                      // If Start Day = 15. Range A: 15..31. Range B: 1..14.
                      // They are mutually exclusive!
                      // So we don't strictly need a radio button for data model, 
                      // BUT user requested "Pick December" vs "Pick January".
                      // So we can visually separate them.
                      
                      bool inPeriodA = selectedDay >= startDay;
                      
                      return Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(AppStrings.dayOfMonth, style: TextStyle(fontWeight: FontWeight.bold)),
                           const SizedBox(height: 8),
                           // Period A Selector (Start of Cycle)
                           if (rangeA.isNotEmpty)
                             RadioListTile<bool>(
                               title: Text("$startSideName (${rangeA.first} - ${rangeA.last})"),
                               value: true,
                               groupValue: inPeriodA,
                               onChanged: (val) {
                                  // Switch to Period A
                                  // Default to first day of A? Or keep day if in range?
                                  // Keep day if in range A? No, usually day is small (e.g. 5).
                                  // So if switching from B(5) to A, we must change to >= 26.
                                  setState(() {
                                     selectedDay = rangeA.first;
                                  });
                               },
                               contentPadding: EdgeInsets.zero,
                               dense: true,
                             ),
                             
                           // Period B Selector (End of Cycle)
                           if (rangeB.isNotEmpty)
                             RadioListTile<bool>(
                               title: Text("$endSideName (1 - ${rangeB.last})"),
                               value: false, // Represents Period B
                               groupValue: inPeriodA,
                               onChanged: (val) {
                                  // Switch to Period B
                                  setState(() {
                                     selectedDay = rangeB.isNotEmpty ? rangeB.first : 1;
                                  });
                               },
                               contentPadding: EdgeInsets.zero,
                               dense: true,
                             ),
                             
                           const SizedBox(height: 8),
                           // The actual Dropdown for the selected period
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12),
                             decoration: BoxDecoration(
                               border: Border.all(color: Colors.grey.shade300),
                               borderRadius: BorderRadius.circular(8),
                             ),
                             child: DropdownButtonHideUnderline(
                               child: DropdownButton<int>(
                                 isExpanded: true,
                                 value: selectedDay,
                                 // Ensure selectedDay is valid for the list, otherwise fallback
                                 items: (inPeriodA ? rangeA : rangeB).map((d) => DropdownMenuItem(value: d, child: Text(d.toString()))).toList(),
                                 onChanged: (val) {
                                    if (val != null) setState(() => selectedDay = val);
                                 },
                               ),
                             ),
                           ),
                         ],
                      );
                    }
                  ),
                  const Divider(height: 32),
                  SwitchListTile(
                    title: Text(AppStrings.autoApply),
                    subtitle: Text(AppStrings.autoApplySubtitle),
                    value: isAuto,
                    onChanged: (val) => setState(() => isAuto = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isAuto)
                    SwitchListTile(
                      title: Text(AppStrings.waitForDueDate),
                      subtitle: Text(AppStrings.waitForDueDateSubtitle),
                      value: delayedAutoPay,
                      activeColor: Colors.purple,
                      onChanged: (val) => setState(() => delayedAutoPay = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
              TextButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  double amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (name.isEmpty || amount <= 0) return;

                  final provider = Provider.of<ExpenseProvider>(context, listen: false);
                  
                  // Ensure saved category is valid
                  String finalCategory = selectedCategory;
                  if (!provider.categories.any((c) => c.name == finalCategory)) {
                     // Same fallback logic
                     if (provider.categories.any((c) => c.name == 'Others')) {
                        finalCategory = 'Others';
                     } else if (provider.categories.isNotEmpty) {
                        finalCategory = provider.categories.first.name;
                     }
                  }

                  final newCharge = FixedChargeModel(
                    id: charge?.id ?? '', 
                    name: name,
                    amount: amount,
                    category: finalCategory,
                    dayOfMonth: selectedDay,
                    isAutoApplied: isAuto,
                    delayedAutoPay: delayedAutoPay,
                  );

                  try {
                    if (charge == null) {
                      await provider.addFixedCharge(newCharge).timeout(const Duration(milliseconds: 500));
                    } else {
                      await provider.updateFixedCharge(newCharge).timeout(const Duration(milliseconds: 500));
                    }
                  } catch (e) {
                    // Ignore timeout, assume queued
                  }
                  
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(AppStrings.save),
              ),
            ],
          );
        }
      ),
    );
  }
}

class _ChargeTile extends StatelessWidget {
  final FixedChargeModel charge;

  const _ChargeTile({required this.charge});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final isApplied = provider.isChargeAppliedInCycle(charge.id, provider.selectedYear, provider.selectedMonth);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: charge.isAutoApplied ? Colors.indigo.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
          child: Icon(
            charge.isAutoApplied ? LucideIcons.refreshCw : LucideIcons.hammer, 
            color: charge.isAutoApplied ? Colors.indigo : Colors.orange,
            size: 18,
          ),
        ),
        title: Text(charge.name),
          subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${Utils.formatCurrency(charge.amount)} • ${charge.category}"),
            if (!isApplied)
               Padding(
                 padding: const EdgeInsets.only(top: 2),
                 child: Text("${AppStrings.dayOfMonth} ${charge.dayOfMonth}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
               ),
            if (isApplied)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    Text("${AppStrings.appliedFor} ${Utils.getMonthName(provider.selectedMonth)}", 
                      style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isApplied) // Show "Apply" button if not yet applied
              TextButton(
                onPressed: () => _confirmApplyIndividual(context, provider, charge),
                child: Text(AppStrings.apply),
              ),
            
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.grey),
              onPressed: () => _confirmDelete(context, charge),
            ),
          ],
        ),
        onTap: () {
            (context.findAncestorWidgetOfExactType<FixedChargesScreen>() as dynamic)?._showAddEditDialog(context, charge);
        },
      ),
    );
  }

  void _confirmApplyIndividual(BuildContext context, ExpenseProvider provider, FixedChargeModel charge) {
    // Determine target cycle (Current View)
    final year = provider.selectedYear;
    final month = provider.selectedMonth;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.applyChargeTitle),
        content: Text("${AppStrings.apply} '${charge.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.applyFixedChargesToCycle(
                  year, 
                  month, 
                  chargeId: charge.id,
                  customDate: DateTime.now() // Individual apply uses "Now"
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${charge.name} ${AppStrings.chargesApplied}")),
                );
              }
            },
            child: Text(AppStrings.apply),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, FixedChargeModel charge) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.deleteChargeTitle),
        content: Text("${AppStrings.delete} '${charge.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          TextButton(
            onPressed: () async {
              await Provider.of<ExpenseProvider>(context, listen: false).deleteFixedCharge(charge.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }
}
