// File: lib/ui/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import 'category_screen.dart';
import '../../core/utils.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: ListView(
        children: [
          // Profile Section
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo,
              child: Text(auth.user?.email != null ? auth.user!.email![0].toUpperCase() : 'G', 
                style: const TextStyle(color: Colors.white)),
            ),
            title: Text(auth.user?.email ?? 'Guest User'),
            subtitle: Text(auth.user?.uid ?? ''),
          ),
          const Divider(),

          // Salary Configuration
          ListTile(
            leading: const Icon(LucideIcons.briefcase),
            title: const Text('Monthly Salary'),
            subtitle: Text(Utils.formatCurrency(expenseProvider.salary)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showSalaryDialog(context, expenseProvider);
            },
          ),
          
          ListTile(
            leading: const Icon(LucideIcons.list),
            title: const Text('Categories'),
            subtitle: const Text('Manage your categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryScreen()));
            },
          ),
          
          const Divider(),

          // Danger Zone
          ListTile(
            leading: const Icon(LucideIcons.trash2, color: Colors.red),
            title: const Text('Reset All Data', style: TextStyle(color: Colors.red)),
            onTap: () {
               _showResetDialog(context, expenseProvider);
            },
          ),
          
           ListTile(
            leading: const Icon(LucideIcons.logOut),
            title: const Text('Log Out'),
            onTap: () async {
              await auth.signOut();
            },
          ),
        ],
      ),
    );
  }

  void _showSalaryDialog(BuildContext context, ExpenseProvider provider) {
    final controller = TextEditingController(text: provider.salary.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Update Salary"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Salary Amount", prefixText: "DH "),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(controller.text) ?? 0;
              await provider.updateSalary(val);
              if (ctx.mounted) Navigator.pop(ctx);
            }, 
            child: const Text("Save")
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, ExpenseProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset Data"),
        content: const Text("Are you sure you want to delete ALL expenses and reset your salary? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await provider.resetData();
              if (ctx.mounted) Navigator.pop(ctx);
            }, 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete All")
          ),
        ],
      ),
    );
  }
}
