import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/utils.dart';
import '../../core/app_strings.dart';
import '../../data/models/insurance_claim_model.dart';
import '../../providers/expense_provider.dart';

class InsuranceScreen extends StatefulWidget {
  final String? initialEditClaimId;
  const InsuranceScreen({super.key, this.initialEditClaimId});

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();

  // Make this static so it can be called from anywhere if we have the context and claim
  static void showEditDialog(BuildContext context, InsuranceClaimModel claim) {
     final titleCtrl = TextEditingController(text: claim.title);
    final amountCtrl = TextEditingController(text: claim.totalAmount.toStringAsFixed(2)); 
    DateTime selectedDate = DateTime.parse(claim.date);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark ? const Color(0xFF1E1E2C) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.editClaim,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: AppStrings.descriptionLabel,
                      prefixIcon: const Icon(LucideIcons.fileText, size: 20),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    decoration: InputDecoration(
                      labelText: AppStrings.totalAmountLabel,
                      prefixIcon: const Icon(LucideIcons.banknote, size: 20),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.calendar, size: 20),
                          const SizedBox(width: 12),
                          Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(AppStrings.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final title = titleCtrl.text.trim();
                            final amount = double.tryParse(amountCtrl.text) ?? 0;
                            if (title.isEmpty || amount <= 0) return;

                            await Provider.of<ExpenseProvider>(context, listen: false).editInsuranceClaim(
                              claim,
                              title,
                              amount,
                              selectedDate.toIso8601String(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(AppStrings.saveChanges),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}

class _InsuranceScreenState extends State<InsuranceScreen> {

  @override
  void initState() {
    super.initState();
    if (widget.initialEditClaimId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndOpenDialog();
      });
    }
  }

  void _checkAndOpenDialog() {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    try {
      final claim = provider.insuranceClaims.firstWhere((c) => c.id == widget.initialEditClaimId);
      if (claim.status == 'pending') {
         InsuranceScreen.showEditDialog(context, claim);
      }
    } catch (_) {
      print("Could not find claim to auto-edit");
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final claims = provider.insuranceClaims;
    
    // Sort: Pending first (by date desc), then Paid (by date desc)
    claims.sort((a, b) => b.date.compareTo(a.date));

    final pending = claims.where((c) => c.status == 'pending').toList();
    final paid = claims.where((c) => c.status == 'paid').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.healthInsuranceTitle),
      ),
      body: claims.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(LucideIcons.heartPulse, size: 64, color: Colors.grey[400]),
                   const SizedBox(height: 16),
                   Text(AppStrings.noInsuranceClaims, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isNotEmpty) ...[
                  _buildSectionHeader(AppStrings.pendingClaimsSection),
                  ...pending.map((c) => _ClaimTile(claim: c)),
                  const SizedBox(height: 24),
                ],
                if (paid.isNotEmpty) ...[
                   _buildSectionHeader(AppStrings.historySection),
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
          final theme = Theme.of(context);
          
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark ? const Color(0xFF1E1E2C) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    AppStrings.newInsuranceClaimTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Description Input
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: AppStrings.claimDescriptionHint,
                      prefixIcon: const Icon(LucideIcons.fileText, size: 20),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  
                  // Amount Input
                  TextField(
                    controller: amountCtrl,
                    decoration: InputDecoration(
                      hintText: AppStrings.totalAmountPaidHint,
                      prefixIcon: const Icon(LucideIcons.banknote, size: 20),
                      prefixText: "DH ",
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  
                  // Date Picker
                  GestureDetector(
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.calendar, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('MMM dd, yyyy').format(selectedDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            foregroundColor: Colors.grey,
                          ),
                          child: Text(AppStrings.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(AppStrings.addClaim),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
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
                   Text("${AppStrings.refundedPrefix}${Utils.formatCurrency(claim.refundAmount ?? 0.0)}",  
                     style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                   const SizedBox(height: 8),
                ],
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: Text(AppStrings.delete),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => _confirmDelete(context),
                    ),
                    if (isPending) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(LucideIcons.pencil, size: 16),
                        label: Text(AppStrings.editClaim),
                        style: TextButton.styleFrom(foregroundColor: Colors.blue),
                        onPressed: () => InsuranceScreen.showEditDialog(context, claim),
                      ),
                    ],
                     const Spacer(),
                    if (isPending)
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.checkCheck, size: 16),
                        label: Text(AppStrings.settleRefund),
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
        title: Text(AppStrings.deleteClaimTitle),
        content: Text(AppStrings.deleteClaimContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          TextButton(
            onPressed: () async {
              await Provider.of<ExpenseProvider>(context, listen: false).deleteInsuranceClaim(claim.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.delete),
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
            title: Text(AppStrings.settleClaimTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("${AppStrings.totalPaidPrefix}${Utils.formatCurrency(claim.totalAmount)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 TextField(
                   controller: amountCtrl,
                   decoration: InputDecoration(
                     labelText: AppStrings.refundAmountReceivedLabel,
                     prefixText: "DH ",
                   ),
                   keyboardType: TextInputType.number,
                 ),
                 const SizedBox(height: 16),
                 ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.calendar),
                    title: Text("${AppStrings.refundDatePrefix}${DateFormat('MMM dd, yyyy').format(selectedDate)}"),
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
                child: Text(AppStrings.confirmRefundBtn),
              )
            ],
          );
        }
      ),
    );
  }

}
