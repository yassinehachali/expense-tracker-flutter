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
import '../../core/app_strings.dart'; // Add import

import '../../core/global_events.dart';
import 'loans_manager_screen.dart';
import 'fixed_charges_screen.dart';
import 'insurance_screen.dart';

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
        appBar: AppBar(title: const Text(AppStrings.settingsTitle), centerTitle: false),
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
              title: Text(auth.user?.email ?? AppStrings.guestUser),
              subtitle: Text(auth.user?.uid ?? ''),
            ),
            const Divider(),

            // Salary Configuration
            ListTile(
              leading: const Icon(LucideIcons.briefcase),
              title: const Text(AppStrings.salaryCycleOption),
              subtitle: Text("${Utils.formatCurrency(expenseProvider.currentCycleSalary)} (${Utils.formatDate(expenseProvider.currentCycleStart)} - ${Utils.formatDate(expenseProvider.currentCycleEnd)})"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showSalaryDialog(context, expenseProvider);
              },
            ),
            
            ListTile(
              leading: const Icon(LucideIcons.list),
              title: const Text(AppStrings.categoriesOption),
              subtitle: const Text(AppStrings.categoriesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryScreen()));
              },
            ),
            
            ListTile(
              leading: const Icon(LucideIcons.calendarClock),
              title: const Text("Fixed Charges"),
              subtitle: const Text("Manage recurring expenses"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FixedChargesScreen()));
              },
            ),
            
            ListTile(
              leading: const Icon(LucideIcons.heartPulse),
              title: const Text("Health Insurance"),
              subtitle: const Text("Track claims and refunds"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const InsuranceScreen()));
              },
            ),
            
            ListTile(
              leading: const Icon(LucideIcons.coins),
              title: const Text(AppStrings.loansManager),
              subtitle: const Text("Manage borrowed debts"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoansManagerScreen()));
              },
            ),
            
            if (auth.user?.email != null) // Only show for logged in users
               ListTile(
                leading: const Icon(LucideIcons.lock),
                title: const Text(AppStrings.changePasswordOption),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showChangePasswordDialog(context, auth);
                },
              ),

            if (!kIsWeb) // Auto-update is only for Android APKs
              ListTile(
                leading: const Icon(LucideIcons.downloadCloud),
                title: const Text(AppStrings.checkUpdatesOption),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _checkForUpdates(context);
                },
              ),

            const Divider(),

            // Danger Zone
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.red),
              title: const Text(AppStrings.resetDataOption, style: TextStyle(color: Colors.red)),
              onTap: () {
                 _showResetDialog(context, expenseProvider);
              },
            ),
            
             ListTile(
              leading: const Icon(LucideIcons.logOut),
              title: const Text(AppStrings.logoutOption),
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
            child: Text("${AppStrings.errorPrefix}\n$e\n\n$stack", style: const TextStyle(color: Colors.red)),
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
          final startMonthIndex = (selectedMonth + selectedOffset) % 12;
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
                    AppStrings.customizeCycle,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: AppStrings.salaryAmount, 
                      prefixText: "DH "
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(AppStrings.cycleStartsIn),
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
                            child: Text("${AppStrings.cycleStartDay}$day"),
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
                    "${AppStrings.cycleHelperText}$startMonthName $selectedDay.",
                     style: const TextStyle(fontSize: 12, color: Colors.indigo),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel)),
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
                child: const Text(AppStrings.save)
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
        title: const Text(AppStrings.changePasswordOption),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: AppStrings.currentPassword),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: AppStrings.newPassword),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: AppStrings.confirmNewPassword),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel)),
          TextButton(
            onPressed: () async {
              final current = currentPassController.text;
              final newPass = newPassController.text;
              final confirm = confirmPassController.text;

              if (newPass != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.newPasswordMismatch)));
                return;
              }
              if (newPass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.passwordLength)));
                return;
              }

              try {
                // Show loading indicator or handle state? 
                // For simplicity in dialog, we await.
                await auth.changePassword(current, newPass);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.passwordUpdateSuccess)));
                }
              } catch (e) {
                if (ctx.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.errorPrefix}$e")));
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
        title: const Text(AppStrings.resetDataTitle),
        content: const Text(AppStrings.resetDataConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel)),
          TextButton(
            onPressed: () async {
              await provider.resetData();
              if (ctx.mounted) Navigator.pop(ctx);
            }, 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(AppStrings.deleteAll)
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
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.errorPrefix}${updateData['error']}")));
           return;
        }

        if (updateData['updateAvailable'] == true) {
          // Show update available dialog
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text(AppStrings.updateAvailableTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Version: ${updateData['version']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(AppStrings.changelog),
                    const SizedBox(height: 4),
                    Text(updateData['changelog']),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.later)),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startUpdate(context, updateData['url']);
                  },
                  child: const Text(AppStrings.updateNow),
                ),
              ],
            ),
          );
        } else {
          // Debugging info in user feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${AppStrings.upToDate} (Local: ${updateData['localVersion']} vs Remote: ${updateData['version']})"))
          );
        }
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("${AppStrings.checkFailed} (No response)")));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // ensure loading is closed
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.errorPrefix}$e")));
      }
    }
  }

  void _startUpdate(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        double progress = 0;
        String status = AppStrings.startDownload;
        
        return StatefulBuilder(
          builder: (context, setState) {
            // Start download once
            if (progress == 0 && status == AppStrings.startDownload) {
               UpdateService().downloadUpdate(url, (val) {
                 if (context.mounted) {
                   setState(() {
                     progress = val;
                     status = "${AppStrings.downloading}${(val * 100).toStringAsFixed(0)}%";
                   });
                 }
               }).then((path) async {
                 if (context.mounted) {
                   setState(() {
                     status = AppStrings.launchingInstaller;
                     progress = 1.0;
                   });
                   
                   // Small delay to let user see the completion
                   await Future.delayed(const Duration(seconds: 1));
                   
                   if (path != null) {
                      final error = await UpdateService().installUpdate(path);
                      if (context.mounted) {
                        Navigator.pop(context); // Close dialog
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.installFailed}$error")));
                        }
                      }
                   } else {
                     if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.downloadFailed)));
                     }
                   }
                 }
               });
            }

            return AlertDialog(
              title: const Text("Updating..."), // Could assume this is part of transient UI or add to strings if critical
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
