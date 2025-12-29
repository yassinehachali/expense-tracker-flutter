import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/beneficiary_model.dart';

class BeneficiarySelector extends StatelessWidget {
  final List<BeneficiaryModel> beneficiaries;
  final String selectedName;
  final Function(String) onSelected;
  final Function(String) onAddNew;

  const BeneficiarySelector({
    super.key,
    required this.beneficiaries,
    required this.selectedName,
    required this.onSelected,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown for existing
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: beneficiaries.any((b) => b.name == selectedName) ? selectedName : null,
              hint: const Text("Select Person"),
              isExpanded: true,
              items: [
                ...beneficiaries.map((b) => DropdownMenuItem(
                  value: b.name,
                  child: Row(
                    children: [
                       CircleAvatar(
                         radius: 12,
                         backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                         child: Text(b.name[0].toUpperCase(), style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
                       ),
                       const SizedBox(width: 8),
                       Text(b.name),
                    ],
                  ),
                )),
                const DropdownMenuItem(
                  value: 'add_new_action',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 16),
                      SizedBox(width: 8),
                      Text("Add New Person..."),
                    ],
                  ),
                )
              ],
              onChanged: (val) {
                if (val == 'add_new_action') {
                   _showAddDialog(context);
                } else if (val != null) {
                   onSelected(val);
                }
              },
            ),
          ),
        ),
        
        // Manual override or display if name matches no one (legacy data)
        if (selectedName.isNotEmpty && !beneficiaries.any((b) => b.name == selectedName))
           Padding(
             padding: const EdgeInsets.only(top: 8, left: 4),
             child: Text(
               "Current: $selectedName (Not in list)", 
               style: TextStyle(fontSize: 12, color: Colors.orange),
             ),
           ),
      ],
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Person"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Name", hintText: "e.g. Alice"),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
               final name = controller.text.trim();
               if (name.isNotEmpty) {
                  onAddNew(name);
                  Navigator.pop(ctx);
               }
            }, 
            child: const Text("Add")
          )
        ],
      )
    );
  }
}
