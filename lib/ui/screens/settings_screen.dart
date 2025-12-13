import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../data/services/update_service.dart';
import 'category_screen.dart';
import '../../core/utils.dart';

import '../../core/global_events.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  
  @override
  void initState() {
    super.initState();
    GlobalEvents.stream.listen((event) {
       if (event == 'open_update_check' && mounted) {
          // Small delay to ensure tab switch animation is done/frame is ready
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _checkForUpdates(context);
          });
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    try {
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
                child: Text(auth.user?.email != null && auth.user!.email!.isNotEmpty 
                  ? auth.user!.email![0].toUpperCase() 
                  : 'G', 
                  style: const TextStyle(color: Colors.white)),
              ),
              title: Text(auth.user?.email ?? 'Guest User'),
              subtitle: Text(auth.user?.uid ?? ''),
            ),
            const Divider(),

            // Salary Configuration
            ListTile(
              leading: const Icon(LucideIcons.briefcase),
              title: const Text('Salary & Cycle'),
              subtitle: Text("${Utils.formatCurrency(expenseProvider.currentCycleSalary)} (${Utils.formatDate(expenseProvider.currentCycleStart)} - ${Utils.formatDate(expenseProvider.currentCycleEnd)})"),
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
            
            const SizedBox(height: 24),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Center(
                    child: Text(
                      "v${snapshot.data!.version}",
                      style: TextStyle(
                        color: theme.brightness == Brightness.dark ? Colors.grey[600] : Colors.grey[400],
                        fontSize: 12
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    } catch (e, stack) {
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text("Error loading Settings:\n$e\n\n$stack", style: const TextStyle(color: Colors.red)),
          ),
        ),
      );
    }
  }

  void _showSalaryDialog(BuildContext context, ExpenseProvider provider) {
    // Current Dashboard Context
    final selectedYear = provider.selectedYear;
    final selectedMonth = provider.selectedMonth; // 0-indexed
    final monthName = Utils.getMonthName(selectedMonth);

    // Initial Values (From currently effective settings)
    final initialSalary = provider.currentCycleSalary;
    final initialStart = provider.currentCycleStart; // This is the calculated start date
    // We need to reverse engineer the 'day' and 'offset' from the effective settings logic
    // But better to just expose the raw settings if possible.
    // Since we don't expose the raw settings object, we'll infer:
    // If start date is in previous month -> Offset -1
    // If start date is in current month -> Offset 0
    
    int initialDay = initialStart.day;
    int initialOffset = (initialStart.month == (selectedMonth + 1)) ? 0 : -1;
    // Edge case: Year boundary (Jan selected, starts in Dec)
    if (selectedMonth == 0 && initialStart.month == 12) initialOffset = -1;

    final controller = TextEditingController(text: initialSalary.toString());
    int selectedDay = initialDay;
    int selectedOffset = initialOffset; // 0 = Same Month, -1 = Prev Month

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          // Dynamic Label for "Start Month"
          // If offset 0: "November"
          // If offset -1: "October"
          final startMonthIndex = (selectedMonth + selectedOffset) % 12;
          // Handle negative modulo in Dart? (0-1 = -1)
          final normalizedIndex = startMonthIndex < 0 ? 12 + startMonthIndex : startMonthIndex;
          
          final startMonthName = Utils.getMonthName(normalizedIndex);

          return AlertDialog(
            title: Text("Cycle for $monthName $selectedYear"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                    "Customize the salary and start date for this specific month.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Salary Amount", 
                      prefixText: "DH "
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Cycle Starts In:"),
                  Row(
                    children: [
                      // Month Selector (Prev vs Current)
                      DropdownButton<int>(
                        value: selectedOffset,
                        items: [
                          DropdownMenuItem(value: -1, child: Text(Utils.getMonthName((selectedMonth - 1) < 0 ? 11 : selectedMonth - 1))),
                          DropdownMenuItem(value: 0, child: Text(monthName)),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => selectedOffset = val);
                        },
                      ),
                      const SizedBox(width: 12),
                      // Day Selector
                      DropdownButton<int>(
                        value: selectedDay,
                        items: List.generate(28, (index) => index + 1).map((day) {
                          return DropdownMenuItem(
                            value: day,
                            child: Text("Day $day"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedDay = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Helper Text
                  Text(
                    "This cycle will start on $startMonthName $selectedDay.",
                     style: const TextStyle(fontSize: 12, color: Colors.indigo),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              TextButton(
                onPressed: () async {
                  final val = double.tryParse(controller.text) ?? 0;
                  
                  // Save as override for this month
                  await provider.updateMonthlyOverride(
                    selectedYear, 
                    selectedMonth, 
                    val, 
                    selectedDay, 
                    selectedOffset
                  );
                  
                  if (ctx.mounted) Navigator.pop(ctx);
                }, 
                child: const Text("Save")
              ),
            ],
          );
        }
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

      if (updateData != null) {
        if (updateData['error'] != null) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${updateData['error']}")));
           return;
        }

        if (updateData['updateAvailable'] == true) {
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
        } else {
          // Debugging info in user feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Up to date! (Local: ${updateData['localVersion']} vs Remote: ${updateData['version']})"))
          );
        }
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Check failed (No response)")));
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
               }).then((path) async {
                 if (context.mounted) {
                   setState(() {
                     status = "Launching Installer...";
                     progress = 1.0;
                   });
                   
                   // Small delay to let user see the completion
                   await Future.delayed(const Duration(seconds: 1));
                   
                   if (path != null) {
                      final error = await UpdateService().installUpdate(path);
                      if (context.mounted) {
                        Navigator.pop(context); // Close dialog
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Install failed: $error")));
                        }
                      }
                   } else {
                     if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download failed")));
                     }
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
