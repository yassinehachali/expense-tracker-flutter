import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../providers/expense_provider.dart';
import '../../data/models/event_model.dart';
import '../../core/utils.dart';
import '../widgets/expense_card.dart';
import '../widgets/glass_container.dart';
import 'add_expense_screen.dart';

class EventDetailScreen extends StatelessWidget {
  final EventModel event;
  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          // Live object refetch
          final liveEvent = provider.events.firstWhere((e) => e.id == event.id, orElse: () => event);
          
          final eventExpenses = provider.expenses
              .where((e) => e.eventId == event.id)
              .toList()
              ..sort((a, b) => b.date.compareTo(a.date));

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back, color: theme.iconTheme.color),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                   IconButton(
                     icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.settings, color: theme.iconTheme.color),
                    ),
                     onPressed: () => _showSettings(context, provider, liveEvent),
                   ),
                   const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient Background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark 
                              ? [const Color(0xFF2E1065), const Color(0xFF4C1D95)] // Deep Purple
                              : [const Color(0xFFDDD6FE), const Color(0xFFC4B5FD)], // Light Purple
                          )
                        ),
                      ),
                      // Decorative Circles
                      Positioned(
                        top: -50, right: -50,
                        child: Container(
                          width: 200, height: 200,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
                        ),
                      ),
                      Positioned(
                        bottom: -30, left: -30,
                        child: Container(
                          width: 140, height: 140,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
                        ),
                      ),
                      
                      // Content
                      SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                             const SizedBox(height: 20),
                             Container(
                               padding: const EdgeInsets.all(16),
                               decoration: BoxDecoration(
                                 color: Colors.white.withOpacity(0.1),
                                 shape: BoxShape.circle,
                                 border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)
                               ),
                               child: Icon(Utils.getIcon(liveEvent.icon == 'Calendar' ? 'Plane' : liveEvent.icon), size: 48, color: Colors.white),
                             ),
                             const SizedBox(height: 16),
                             Text(
                               liveEvent.name,
                               style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                               textAlign: TextAlign.center,
                             ),
                             if (liveEvent.description != null && liveEvent.description!.isNotEmpty)
                               Padding(
                                 padding: const EdgeInsets.only(top: 4),
                                 child: Text(
                                   liveEvent.description!,
                                   style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                                 ),
                               ),
                               
                             const SizedBox(height: 24),
                             Text(
                               Utils.formatCurrency(liveEvent.totalAmount),
                               style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                             ),
                             Text(
                                "Total Spent".toUpperCase(),
                               style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                             ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                 child: Padding(
                   padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                   child: Text("Transactions", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                 ),
              ),

              if (eventExpenses.isEmpty)
                SliverFillRemaining(
                   hasScrollBody: false,
                   child: Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(LucideIcons.receipt, size: 64, color: theme.disabledColor.withOpacity(0.5)),
                         const SizedBox(height: 16),
                         Text("No transactions yet", style: TextStyle(color: theme.disabledColor)),
                       ],
                     ),
                   ),
                )
              else 
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                         final exp = eventExpenses[index];
                         return Padding(
                           padding: const EdgeInsets.only(bottom: 12),
                           child: ExpenseCard(
                             expense: exp,
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
                                              // Navigate to AddExpenseScreen in Edit Mode
                                              // We need to import AddExpenseScreen first if not imported.
                                              // Checking imports... assuming we need to add it or use named routes.
                                              // Using direct navigation as consistent with other screens.
                                              Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(expenseToEdit: exp)));
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.delete, color: Colors.red),
                                            title: const Text("Delete Transaction", style: TextStyle(color: Colors.red)),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (dCtx) => AlertDialog(
                                                  title: const Text("Delete Transaction?"),
                                                  content: const Text("This action cannot be undone."),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text("Cancel")),
                                                    TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                                                  ],
                                                )
                                              );
                                              
                                              if (confirm == true) {
                                                await provider.deleteExpense(exp.id);
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                             },
                           ),
                         );
                      },
                      childCount: eventExpenses.length,
                    ),
                  ),
                ),
                
              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          );
        },
      ),
    );
  }

  void _showSettings(BuildContext context, ExpenseProvider provider, EventModel event) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text("Event Settings", style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              leading: Icon(event.isClosed ? Icons.check_circle_outline : Icons.circle_outlined, color: event.isClosed ? Colors.green : Colors.grey),
              title: Text(event.isClosed ? "Mark as Active" : "Mark as Completed"),
              subtitle: Text(event.isClosed ? "Re-open this event to add expenses" : "Close this event to prevent new expenses"),
              onTap: () async {
                Navigator.pop(ctx);
                final updated = event.copyWith(isClosed: !event.isClosed);
                await provider.updateEvent(updated);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete Event", style: TextStyle(color: Colors.red)),
              subtitle: const Text("This will delete the event and unlink its expenses.", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text("Delete Event?"),
                    content: const Text("This action will permanently delete the event AND all associated transactions. This cannot be undone."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text("Cancel")),
                      FilledButton(
                         onPressed: () => Navigator.pop(dCtx, true), 
                         style: FilledButton.styleFrom(backgroundColor: Colors.red),
                         child: const Text("Delete")
                      ),
                    ],
                  )
                );
                
                if (confirm == true) {
                   await provider.deleteEvent(event.id);
                   if (context.mounted) Navigator.pop(context); // Close detail screen
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
