import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/utils.dart';
import '../../data/models/insurance_claim_model.dart';
import '../../providers/expense_provider.dart';

class InsuranceScreen extends StatelessWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final claims = provider.insuranceClaims;
    
    // Sort: Pending first (by date desc), then Paid (by date desc)
    // Actually typically Pending Oldest first? Or Newest? Let's do Newest first for all.
    claims.sort((a, b) => b.date.compareTo(a.date));

    final pending = claims.where((c) => c.status == 'pending').toList();
    final paid = claims.where((c) => c.status == 'paid').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Insurance"),
      ),
      body: claims.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(LucideIcons.heartPulse, size: 64, color: Colors.grey[400]),
                   const SizedBox(height: 16),
                   Text("No insurance claims yet", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isNotEmpty) ...[
                  _buildSectionHeader("Pending Claims"),
                  ...pending.map((c) => _ClaimTile(claim: c)),
                  const SizedBox(height: 24),
                ],
                if (paid.isNotEmpty) ...[
                   _buildSectionHeader("History"),
                   ...paid.map((c) => _ClaimTile(claim: c)),
                ]
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        label: const Text("New Claim"),
        icon: const Icon(LucideIcons.plus),
        backgroundColor: Colors.red[100], 
        foregroundColor: Colors.red[900],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 1.0,
          color: Colors.grey
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("New Insurance Claim"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: "Description (e.g. Doctor Visit)",
                    prefixIcon: Icon(LucideIcons.fileText),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: "Total Amount Paid",
                    prefixText: "DH ",
                    prefixIcon: Icon(LucideIcons.banknote),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.calendar),
                  title: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (title.isEmpty || amount <= 0) return;

                  await Provider.of<ExpenseProvider>(context, listen: false).addInsuranceClaim(
                    title: title,
                    amount: amount,
                    date: selectedDate.toIso8601String(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text("Add Claim"),
              )
            ],
          );
        }
      ),
    );
  }
}

class _ClaimTile extends StatelessWidget {
  final InsuranceClaimModel claim;
  const _ClaimTile({required this.claim});

  @override
  Widget build(BuildContext context) {
    final isPending = claim.status == 'pending';
    final date = DateTime.parse(claim.date);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isPending ? 2 : 0,
      color: isPending ? Theme.of(context).cardColor : Theme.of(context).cardColor.withOpacity(0.6),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isPending ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
          child: Icon(
            isPending ? LucideIcons.clock : LucideIcons.checkCircle,
            color: isPending ? Colors.orange : Colors.green,
            size: 20,
          ),
        ),
        title: Text(claim.title),
        subtitle: Text("${Utils.formatCurrency(claim.totalAmount)} • ${DateFormat('MMM dd').format(date)}"),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isPending) ...[
                   Text("Refunded: ${Utils.formatCurrency(claim.refundAmount ?? 0.0)}",  
                     style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                   const SizedBox(height: 8),
                ],
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: const Text("Delete"),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => _confirmDelete(context),
                    ),
                     const Spacer(),
                    if (isPending)
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.checkCheck, size: 16),
                        label: const Text("Settle Refund"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, 
                          foregroundColor: Colors.white
                        ),
                        onPressed: () => _showSettleDialog(context),
                      ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Claim?"),
        content: const Text("This will remove the claim history."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await Provider.of<ExpenseProvider>(context, listen: false).deleteInsuranceClaim(claim.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showSettleDialog(BuildContext context) {
    final amountCtrl = TextEditingController(text: claim.totalAmount.toStringAsFixed(2)); // Default full refund
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Settle Claim"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Total Paid: ${Utils.formatCurrency(claim.totalAmount)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 TextField(
                   controller: amountCtrl,
                   decoration: const InputDecoration(
                     labelText: "Refund Amount Received",
                     prefixText: "DH ",
                   ),
                   keyboardType: TextInputType.number,
                 ),
                 const SizedBox(height: 16),
                 ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.calendar),
                    title: Text("Refund Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}"),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                 ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (amount <= 0) return;

                  await Provider.of<ExpenseProvider>(context, listen: false).settleInsuranceClaim(
                    claim, 
                    amount, 
                    date: selectedDate.toIso8601String()
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text("Confirm Refund"),
              )
            ],
          );
        }
      ),
    );
  }
}
