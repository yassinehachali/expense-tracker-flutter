import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../data/services/update_service.dart';
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

          if (!kIsWeb) // Auto-update is only for Android APKs
            ListTile(
              leading: const Icon(LucideIcons.downloadCloud),
              title: const Text('Check for Updates'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _checkForUpdates(context);
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

  Future<void> _checkForUpdates(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final updateData = await UpdateService().checkForUpdate();
      if (context.mounted) Navigator.pop(context); // Close loading

      if (updateData != null && context.mounted) {
        // Show update available dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Update Available 🚀"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Version: ${updateData['version']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Changelog:"),
                  const SizedBox(height: 4),
                  Text(updateData['changelog']),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Later")),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _startUpdate(context, updateData['url']);
                },
                child: const Text("Update Now"),
              ),
            ],
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are up to date!")));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // ensure loading is closed
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error checking for updates: $e")));
      }
    }
  }

  void _startUpdate(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        double progress = 0;
        String status = "Starting download...";
        
        return StatefulBuilder(
          builder: (context, setState) {
            // Start download once
            if (progress == 0 && status == "Starting download...") {
               UpdateService().downloadUpdate(url, (val) {
                 if (context.mounted) {
                   setState(() {
                     progress = val;
                     status = "Downloading: ${(val * 100).toStringAsFixed(0)}%";
                   });
                 }
               }).then((path) {
                 if (context.mounted) {
                   Navigator.pop(context); // Close dialog
                   if (path != null) {
                     UpdateService().installUpdate(path);
                   } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download failed")));
                   }
                 }
               });
            }

            return AlertDialog(
              title: const Text("Updating..."),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text(status),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
