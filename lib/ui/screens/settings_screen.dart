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
import 'package:intl/intl.dart';

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
        appBar: AppBar(title: Text(AppStrings.settingsTitle), centerTitle: false),
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
              title: Text(AppStrings.salaryCycleOption),
              subtitle: Text("${Utils.formatCurrency(expenseProvider.currentCycleSalary)} (${Utils.formatDate(expenseProvider.currentCycleStart)} - ${Utils.formatDate(expenseProvider.currentCycleEnd)})"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showSalaryDialog(context, expenseProvider);
              },
            ),

            ListTile(
              leading: const Icon(LucideIcons.history, color: Colors.green),
              title: Text(AppStrings.rolloverHistory ?? "Rollover History"),
              subtitle: Text(AppStrings.manageRollovers ?? "Manage monthly carry-overs"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showRolloverManagementDialog(context, expenseProvider);
              },
            ),

            
            ListTile(
              leading: const Icon(LucideIcons.list),
              title: Text(AppStrings.categoriesOption),
              subtitle: Text(AppStrings.categoriesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryScreen()));
              },
            ),
            
            ListTile(
              leading: const Icon(LucideIcons.calendarClock),
              title: Text(AppStrings.fixedCharges),
              subtitle: Text(AppStrings.fixedChargesDesc),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FixedChargesScreen()));
              },
            ),
            
            ListTile(
              leading: const Icon(LucideIcons.heartPulse),
              title: Text(AppStrings.healthInsuranceTitle),
              subtitle: Text(AppStrings.healthInsuranceDesc),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const InsuranceScreen()));
              },
            ),
            
            ListTile(
              leading: const Icon(LucideIcons.coins),
              title: Text(AppStrings.loansManager),
              subtitle: Text(AppStrings.manageDebtsDesc),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoansManagerScreen()));
              },
            ),
            
            if (auth.user?.email != null) // Only show for logged in users
               ListTile(
                leading: const Icon(LucideIcons.lock),
                title: Text(AppStrings.changePasswordOption),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showChangePasswordDialog(context, auth);
                },
              ),
              
            if (!kIsWeb) 
              ListTile(
                leading: const Icon(LucideIcons.downloadCloud),
                title: Text(AppStrings.checkUpdatesOption),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _checkForUpdates(context);
                },
              ),

              ListTile(
                leading: const Icon(LucideIcons.globe, color: Colors.blue),
                title: Text(AppStrings.languageOption),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageDialog(context, expenseProvider),
              ),

            const Divider(),

            // Danger Zone
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.red),
              title: Text(AppStrings.resetDataOption, style: const TextStyle(color: Colors.red)),
              onTap: () {
                 _showResetDialog(context, expenseProvider);
              },
            ),


            
             ListTile(
              leading: const Icon(LucideIcons.logOut),
              title: Text(AppStrings.logoutOption),
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
                      "${AppStrings.versionPrefix}${snapshot.data!.version}",
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

  void _showLanguageDialog(BuildContext context, ExpenseProvider provider) {
    String selected = provider.settings?.language ?? 'en';
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(AppStrings.selectLanguage),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text("English"),
                  value: 'en',
                  groupValue: selected,
                  onChanged: (val) {
                    setState(() => selected = val!);
                    provider.setLanguage(val!);
                    Navigator.pop(ctx);
                  },
                ),
                RadioListTile<String>(
                  title: const Text("Français"),
                  value: 'fr',
                  groupValue: selected,
                  onChanged: (val) {
                    setState(() => selected = val!);
                    provider.setLanguage(val!);
                    Navigator.pop(ctx);
                  },
                ),
                RadioListTile<String>(
                  title: const Text("العربية"),
                  value: 'ar',
                  groupValue: selected,
                  onChanged: (val) {
                    setState(() => selected = val!);
                    provider.setLanguage(val!);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
            ],
          );
        }
      ),
    );
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
                   Text(
                    AppStrings.customizeCycle,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppStrings.salaryAmount, 
                      prefixText: "DH "
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(AppStrings.cycleStartsIn),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
              TextButton(
                onPressed: () async {
                  final val = double.tryParse(controller.text) ?? 0;
                  
                  // Save as override for this month
                  try {
                    await provider.updateMonthlyOverride(
                      selectedYear, 
                      selectedMonth, 
                      val, 
                      selectedDay, 
                      selectedOffset
                    ).timeout(const Duration(milliseconds: 500));
                  } catch (e) {
                    // Ignore timeout or errors here, just close.
                    // Verification: If offline, it might timeout but write is queued.
                  }
                  
                  if (ctx.mounted) Navigator.pop(ctx);
                }, 
                child: Text(AppStrings.save)
              ),
            ],
          );
        }
      ),
    );
  }

  void _showRolloverManagementDialog(BuildContext context, ExpenseProvider _) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          final accepted = provider.settings.acceptedRollovers;
          final ignored = provider.settings.ignoredRollovers;
          
          // Filter for CURRENT view only (User Request: "just the history of the month before")
          final targetKey = "${provider.selectedYear}-${provider.selectedMonth + 1}";
          
          final allKeys = {...accepted, ...ignored}
              .where((k) => k == targetKey)
              .toList();

          return AlertDialog(
            title: Text(AppStrings.rolloverHistory),
            content: SizedBox(
              width: double.maxFinite,
              child: allKeys.isEmpty 
              ? Center(child: Text(AppStrings.noHistory))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: allKeys.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, index) {
                    final key = allKeys[index];
                    final isAccepted = accepted.contains(key);
                    final date = _parseKey(key);
                    
                    final displayDate = DateFormat('MMMM yyyy', AppStrings.language).format(date);
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isAccepted ? LucideIcons.checkCircle : LucideIcons.xCircle,
                        color: isAccepted ? Colors.green : Colors.grey,
                      ),
                      title: Text(displayDate),
                      subtitle: Text(
                        isAccepted 
                        ? (AppStrings.statusApplied) 
                        : (AppStrings.statusIgnored),
                        style: TextStyle(
                          color: isAccepted ? Colors.green : Colors.grey,
                          fontSize: 12
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          final parts = key.split('-');
                          final y = int.parse(parts[0]);
                          final m = int.parse(parts[1]) - 1; // back to 0-indexed
                          
                          if (isAccepted) {
                             // Switch to Ignored
                             provider.ignoreRollover(y, m);
                          } else {
                             // Switch to Accepted
                             provider.acceptRollover(y, m);
                          }
                          // No manual refresh needed, Consumer handles it
                        },
                        child: Text(isAccepted ? (AppStrings.disable) : (AppStrings.enable)),
                      ),
                    );
                  },
                ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.close)),
            ],
          );
        }
      ),
    );
  }

  DateTime _parseKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }



  void _showChangePasswordDialog(BuildContext context, AuthProvider auth) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.changePasswordOption),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPassController,
                obscureText: true,
                decoration: InputDecoration(labelText: AppStrings.currentPassword),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPassController,
                obscureText: true,
                decoration: InputDecoration(labelText: AppStrings.newPassword),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: InputDecoration(labelText: AppStrings.confirmNewPassword),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          TextButton(
            onPressed: () async {
              final current = currentPassController.text;
              final newPass = newPassController.text;
              final confirm = confirmPassController.text;

              if (newPass != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.newPasswordMismatch)));
                return;
              }
              if (newPass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.passwordLength)));
                return;
              }

              try {
                // Show loading indicator or handle state? 
                // For simplicity in dialog, we await.
                await auth.changePassword(current, newPass);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.passwordUpdateSuccess)));
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
    final confirmationCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final isMatch = confirmationCtrl.text.trim().toLowerCase() == 'delete';
          
          return AlertDialog(
            title: Text(AppStrings.resetDataTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.resetDataConfirm),
                const SizedBox(height: 16),
                Text(
                  AppStrings.typeDeleteToConfirm,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmationCtrl,
                  decoration: InputDecoration(
                    hintText: "delete",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
              ElevatedButton.icon(
                onPressed: isMatch 
                  ? () async {
                      await provider.resetData();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.allDataReset)));
                      }
                    }
                  : null, 
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: Text(AppStrings.deleteAll),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.red.withOpacity(0.3),
                  disabledForegroundColor: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          );
        }
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
              title: Text(AppStrings.updateAvailableTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${AppStrings.versionPrefix}${updateData['version']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(AppStrings.changelog),
                    const SizedBox(height: 4),
                    Text(updateData['changelog']),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.later)),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startUpdate(context, updateData['url']);
                  },
                  child: Text(AppStrings.updateNow),
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
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.checkFailed} (No response)")));
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.downloadFailed)));
                     }
                   }
                 }
               });
            }

            return AlertDialog(
              title: Text(AppStrings.updatingTitle), // Could assume this is part of transient UI or add to strings if critical
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
