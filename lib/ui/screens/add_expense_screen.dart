// File: lib/ui/screens/add_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/expense_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../core/constants.dart';
import '../../core/app_strings.dart'; // Add import
import '../widgets/glass_container.dart';
import '../widgets/category_icon.dart';

class AddExpenseScreen extends StatefulWidget {
  final ExpenseModel? expenseToEdit;
  final DateTime? initialDate; 

  const AddExpenseScreen({super.key, this.expenseToEdit, this.initialDate});

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
      _descriptionController.text = (e.type == 'loan') && e.loanee != null ? e.loanee! : e.description;
      _amountController.text = e.amount.toString();
      _selectedType = e.type;
      _selectedDate = DateTime.parse(e.date);
      // Ensure category exists in default list or handle custom
      _selectedCategory = e.category; 
    } else if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
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
    if (amountText.isEmpty) return;
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.invalidAmount)));
       return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

      if (auth.user == null) throw Exception(AppStrings.userNotLoggedIn);

      final newExpense = ExpenseModel(
        id: widget.expenseToEdit?.id ?? '', 
        amount: amount,
        category: _selectedType == 'expense' ? _selectedCategory : 
                  (_selectedType == 'income' ? 'Income' : 
                  (_selectedType == 'borrow' ? 'Borrowed' : 'Lending')),
        date: _selectedDate.toIso8601String(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        isReturned: false, 
        loanee: (_selectedType == 'loan' || _selectedType == 'borrow') ? _descriptionController.text.trim() : null,
      );

      if (widget.expenseToEdit != null) {
        await expenseProvider.updateExpense(newExpense);
      } else {
        await expenseProvider.addExpense(newExpense);
      }
      
      if (!mounted) return;
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.expenseToEdit != null ? AppStrings.transactionUpdated : AppStrings.transactionSaved)));
      
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false); // Stop loading only on error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.errorPrefix}$e")));
      }
    } 
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final allCategories = expenseProvider.categories;
    
    // Ensure selected category is valid logic remains same (omitted comments for brevity)
    String currentDropdownValue = _selectedCategory;
    if (!allCategories.any((c) => c.name == currentDropdownValue)) {
      if (allCategories.isNotEmpty) {
        currentDropdownValue = allCategories[0].name;
      }
    }
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Ensure consistent background
      resizeToAvoidBottomInset: false, // Prevents keyboard from pushing/resizing layout
      appBar: AppBar(
        title: Text(widget.expenseToEdit != null ? AppStrings.editTransaction : AppStrings.addTransaction),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          children: [
            // Type Segmented Control
            GlassContainer(
              padding: const EdgeInsets.all(4),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  _TypeTab(
                    label: AppStrings.filterExpenses, 
                    icon: LucideIcons.receipt, // or Banknote
                    isSelected: _selectedType == 'expense', 
                    onTap: () => setState(() => _selectedType = 'expense')
                  ),
                  _TypeTab(
                    label: AppStrings.filterLoans, 
                    icon: Icons.handshake, 
                    isSelected: _selectedType == 'loan', 
                    onTap: () => setState(() => _selectedType = 'loan')
                  ),
                  _TypeTab(
                    label: AppStrings.borrow, 
                    icon: LucideIcons.coins, 
                    isSelected: _selectedType == 'borrow', 
                    onTap: () => setState(() => _selectedType = 'borrow')
                  ),
                  _TypeTab(
                    label: AppStrings.filterIncome, 
                    icon: LucideIcons.wallet, 
                    isSelected: _selectedType == 'income', 
                    onTap: () => setState(() => _selectedType = 'income')
                  ),
                ],
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
                      (_selectedType == 'borrow' ? AppStrings.descLabelLoan : AppStrings.descLabelLoan) // Use same label 'Person Name'
                      : AppStrings.descLabel,
              hint: _selectedType == 'loan' ? AppStrings.descHintLoan : 
                    (_selectedType == 'borrow' ? AppStrings.descHintBorrow : AppStrings.descHint),
              icon: LucideIcons.fileText,
            ),

            const SizedBox(height: 16),

            // Category Selector (Only for Expense)
            if (_selectedType == 'expense')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(AppStrings.categoryLabel, style: TextStyle(fontWeight: FontWeight.bold)),
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
                        value: currentDropdownValue,
                        isExpanded: true,
                        items: allCategories.map((cat) {
                           return DropdownMenuItem(
                             value: cat.name,
                             child: Row(
                               children: [
                                 CategoryIcon(iconKey: cat.icon, size: 18, color: theme.iconTheme.color),
                                 const SizedBox(width: 12),
                                 Text(cat.name),
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
              ),

             // Date Selector
             GestureDetector(
               onTap: () async {
                 final picked = await showDatePicker(
                   context: context,
                   initialDate: _selectedDate,
                   firstDate: DateTime(2020),
                   lastDate: DateTime(2030),
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
                         const Text(AppStrings.dateLabel, style: TextStyle(fontSize: 12, color: Colors.grey)),
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

             // Save Button
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
                    : const Text(AppStrings.saveTransaction, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  final IconData icon; // Added icon
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label, 
    required this.icon, // Required now
    required this.isSelected, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
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
                 icon, // Use passed icon
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
