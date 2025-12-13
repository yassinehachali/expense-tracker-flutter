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
          
          if (auth.user?.email != null) // Only show for logged in users
             ListTile(
              leading: const Icon(LucideIcons.lock),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showChangePasswordDialog(context, auth);
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
    // ... existing implementation ...
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

  void _showChangePasswordDialog(BuildContext context, AuthProvider auth) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Change Password"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Current Password"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "New Password"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Confirm New Password"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final current = currentPassController.text;
              final newPass = newPassController.text;
              final confirm = confirmPassController.text;

              if (newPass != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New passwords do not match")));
                return;
              }
              if (newPass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password must be at least 6 characters")));
                return;
              }

              try {
                // Show loading indicator or handle state? 
                // For simplicity in dialog, we await.
                await auth.changePassword(current, newPass);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully")));
                }
              } catch (e) {
                if (ctx.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            }, 
            child: const Text("Update")
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
