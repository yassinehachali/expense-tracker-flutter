import 'package:flutter/material.dart';
import 'dart:async'; 
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/category_model.dart'; // Added Import
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../core/constants.dart';
import '../../core/app_strings.dart';
import '../widgets/glass_container.dart';
import '../widgets/category_icon.dart';

class AddExpenseScreen extends StatefulWidget {
  final ExpenseModel? expenseToEdit;
  final DateTime? initialDate; 
  final String? initialType; 

  const AddExpenseScreen({super.key, this.expenseToEdit, this.initialDate, this.initialType});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  
  String _selectedType = 'expense'; 
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = DEFAULT_CATEGORIES[0]['name'] as String;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      final e = widget.expenseToEdit!;
      _descriptionController.text = (e.type == 'loan' || e.type == 'borrow') && e.loanee != null ? e.loanee! : e.description;
      _amountController.text = e.amount.toString();
      _selectedType = e.type;
      _selectedDate = DateTime.parse(e.date);
      _selectedCategory = e.category; 
    } else {
      if (widget.initialType != null) _selectedType = widget.initialType!;
      if (widget.initialDate != null) _selectedDate = widget.initialDate!;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    final amountText = _amountController.text;
    if (amountText.isEmpty || double.tryParse(amountText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.invalidAmount ?? "Invalid Amount"), backgroundColor: Colors.red),
      );
      return;
    }

    final amount = double.parse(amountText);
    setState(() => _isLoading = true);

    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      
      // Removed isGuest check as it's not available in provider.
      // Removed userId check as logic handles it internally or we trust provider state.

      final newExpense = ExpenseModel(
        id: widget.expenseToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        // userId: userId, // Removed
        amount: amount,
        category: _selectedCategory,
        date: _selectedDate.toIso8601String(),
        description: _descriptionController.text, 
        type: _selectedType,
        // isSynced: false, // Not in constructor based on file view
        
        loanee: (_selectedType == 'loan' || _selectedType == 'borrow') ? _descriptionController.text : null,
        isReturned: widget.expenseToEdit?.isReturned ?? false,
        returnedAmount: widget.expenseToEdit?.returnedAmount ?? 0.0,
        relatedLoanId: widget.expenseToEdit?.relatedLoanId,
        originChargeId: widget.expenseToEdit?.originChargeId,
        excludeFromBalance: widget.expenseToEdit?.excludeFromBalance ?? false,
      );

      // Assume add/update return void/Future<void> based on previous error
      if (widget.expenseToEdit != null) {
        await expenseProvider.updateExpense(newExpense);
      } else {
        await expenseProvider.addExpense(newExpense);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        // Assume success if no exception thrown
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.expenseToEdit != null ? AppStrings.transactionUpdated : AppStrings.transactionSaved),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppStrings.errorPrefix}$e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Explicitly type to avoid dynamic errors
    // final allCategories = ... (Removed because it caused a crash and is unused)
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseToEdit == null ? AppStrings.addTransaction : (AppStrings.editTransaction ?? "Edit")),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Type Segmented Control
            GlassContainer(
              padding: const EdgeInsets.all(4),
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView( 
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    SizedBox(width: 80, child: _TypeTab(
                      label: AppStrings.filterExpenses, 
                      icon: LucideIcons.receipt, 
                      isSelected: _selectedType == 'expense', 
                      onTap: () => setState(() => _selectedType = 'expense')
                    )),
                    SizedBox(width: 80, child: _TypeTab(
                      label: AppStrings.filterLoans, 
                      icon: LucideIcons.arrowUpRight, 
                      isSelected: _selectedType == 'loan', 
                      onTap: () => setState(() => _selectedType = 'loan')
                    )),
                    SizedBox(width: 80, child: _TypeTab(
                      label: AppStrings.borrow, 
                      icon: LucideIcons.arrowDownLeft, 
                      isSelected: _selectedType == 'borrow', 
                      onTap: () => setState(() => _selectedType = 'borrow')
                    )),
                    SizedBox(width: 80, child: _TypeTab(
                      label: AppStrings.filterIncome, 
                      icon: LucideIcons.wallet, 
                      isSelected: _selectedType == 'income', 
                      onTap: () => setState(() => _selectedType = 'income')
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Amount Input
            _CustomTextField(
              controller: _amountController,
              label: AppStrings.amountLabel,
              hint: AppStrings.amountHint,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              icon: LucideIcons.dollarSign,
            ),
            
            const SizedBox(height: 16),
            
            // Description / Loan To Input
            _CustomTextField(
              controller: _descriptionController,
              label: (_selectedType == 'loan' || _selectedType == 'borrow') ? 
                      (_selectedType == 'borrow' ? AppStrings.descLabelLoan : AppStrings.descLabelLoan) 
                      : AppStrings.descLabel,
              hint: _selectedType == 'loan' ? AppStrings.descHintLoan : 
                    (_selectedType == 'borrow' ? AppStrings.descHintBorrow : AppStrings.descHint),
              icon: LucideIcons.fileText,
            ),

            const SizedBox(height: 16),

            // Category Selector (Only for Expense)
            if (_selectedType == 'expense')
              Consumer<ExpenseProvider>(
                builder: (context, provider, child) {
                  final categories = provider.categories; // Use provider categories
                  final currentCatExists = categories.any((c) => c.name == _selectedCategory);
                  // If selected not found (maybe custom deleted?), default to first
                  if (!currentCatExists && categories.isNotEmpty) {
                     // Don't auto-set state during build, but for dropdown value it matters.
                     // Just show valid one if possible.
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.categoryLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: currentCatExists ? _selectedCategory : (categories.isNotEmpty ? categories.first.name : null),
                            isExpanded: true,
                            items: categories.map((cat) {
                               return DropdownMenuItem<String>(
                                 value: cat.name,
                                 child: Row(
                                   children: [
                                     CategoryIcon(iconKey: cat.icon, size: 18, color: theme.iconTheme.color),
                                     const SizedBox(width: 12),
                                     Text(AppStrings.getCategoryName(cat.name)),
                                   ],
                                 ),
                               );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategory = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
              ),

             // Date Selector (Same as before)
             GestureDetector(
               onTap: () async {
                 final picked = await showDatePicker(
                   context: context,
                   initialDate: _selectedDate,
                   firstDate: DateTime(2020),
                   lastDate: DateTime(2030),
                   locale: Locale(AppStrings.language),
                 );
                 if (picked != null) setState(() => _selectedDate = picked);
               },
               child: Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: theme.cardColor,
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: theme.dividerColor),
                 ),
                 child: Row(
                   children: [
                     const Icon(LucideIcons.calendar),
                     const SizedBox(width: 12),
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(AppStrings.dateLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                         Text(DateFormat.yMMMd().format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                       ],
                     ),
                     const Spacer(),
                     const Icon(Icons.chevron_right, color: Colors.grey),
                   ],
                 ),
               ),
             ),

             const SizedBox(height: 32),

             SizedBox(
               width: double.infinity,
               height: 56,
               child: ElevatedButton(
                 onPressed: _isLoading ? null : _saveTransaction,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF6366f1),
                   foregroundColor: Colors.white,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                   elevation: 4,
                   shadowColor: const Color(0xFF6366f1).withOpacity(0.4),
                 ),
                 child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(AppStrings.saveTransaction, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
               ),
             ),
          ],
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final IconData icon; 
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label, 
    required this.icon, 
    required this.isSelected, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.white24) : null,
        ),
        child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(
               icon, 
               size: 20, 
               color: isSelected ? Colors.white : Colors.grey
             ),
             const SizedBox(height: 4),
             Text(
               label, 
               textAlign: TextAlign.center,
               style: TextStyle(
                 fontSize: 12,
                 fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                 color: isSelected ? Colors.white : Colors.grey,
               ),
             ),
           ]
        ),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final IconData icon;

  const _CustomTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.hintColor),
            prefixIcon: Icon(icon, color: theme.iconTheme.color),
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366f1), width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        )
      ],
    );
  }
}
