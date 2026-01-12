import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/expense_provider.dart';
import '../../providers/auth_provider.dart';
import '../../data/models/event_model.dart';
import '../../core/app_strings.dart';
import '../../core/utils.dart';
import '../widgets/glass_container.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    if (auth.user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("My Events")),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          final events = provider.events;
          // Sort by lastUpdated desc
          final sortedEvents = List<EventModel>.from(events)
             ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

          if (sortedEvents.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(LucideIcons.calendarDays, size: 48, color: theme.disabledColor),
                   const SizedBox(height: 16),
                   Text("No events yet", style: TextStyle(color: theme.disabledColor)),
                 ],
               ),
             );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sortedEvents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, index) {
               final event = sortedEvents[index];
               return GestureDetector(
                 onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)));
                 },
                 child: GlassContainer(
                   padding: const EdgeInsets.all(16),
                   child: Row(
                     children: [
                       Container(
                         width: 50, height: 50,
                         decoration: BoxDecoration(
                           color: Colors.purple.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(12)
                         ),
                         child: Icon(Utils.getIcon(event.icon == 'Calendar' ? 'Plane' : event.icon), color: Colors.purple),
                       ),
                       const SizedBox(width: 16),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(event.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                             if (event.description != null && event.description!.isNotEmpty)
                               Text(event.description!, style: TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                           ],
                         ),
                       ),
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                           Text(Utils.formatCurrency(event.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                           Text(Utils.formatDate(DateTime.parse(event.lastUpdated)), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                         ],
                       )
                     ],
                   ),
                 ),
               );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("New Event"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Event Name", hintText: "e.g. Paris Trip")),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description (Optional)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
               if (nameCtrl.text.trim().isEmpty) return;
               
               final provider = Provider.of<ExpenseProvider>(context, listen: false);
               final auth = Provider.of<AuthProvider>(context, listen: false);
               
               final newEvent = EventModel(
                 id: DateTime.now().millisecondsSinceEpoch.toString(),
                 userId: auth.user!.uid,
                 name: nameCtrl.text.trim(),
                 description: descCtrl.text.trim(),
                 lastUpdated: DateTime.now().toIso8601String(),
               );
               
               await provider.addEvent(newEvent);
               if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text("Create"),
          )
        ],
      )
    );
  }
}
