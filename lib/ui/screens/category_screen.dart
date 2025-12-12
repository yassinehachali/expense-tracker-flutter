// File: lib/ui/screens/category_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../data/services/firestore_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/category_icon.dart';
import '../../core/constants.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _nameController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  
  // List of available icons to choose from
  final List<String> _availableIcons = [
     'Home', 'Utensils', 'Car', 'Zap', 'Film', 'ShoppingBag', 'HeartPulse', 
     'Dumbbell', 'Smartphone', 'Wifi', 'Briefcase', 'Gift', 'Plane', 
     'GraduationCap', 'Coffee', 'Music', 'PawPrint', 'CreditCard'
  ];
  
  String _selectedIcon = 'Home';
  Color _selectedColor = AppColors.palette[0];
  
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final theme = Theme.of(context);
    final uid = auth.user?.uid;

    if (uid == null) return const Scaffold(body: Center(child: Text("Please login")));

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Categories")),
      body: StreamBuilder<List<CategoryModel>>(
        stream: _firestoreService.getCategoriesStream(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          
          final customCategories = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add New Section
                GlassContainer(
                   padding: const EdgeInsets.all(16),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Text("Add New Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       const SizedBox(height: 16),
                       TextField(
                         controller: _nameController,
                         decoration: InputDecoration(
                           hintText: "Category Name",
                           filled: true,
                           fillColor: theme.cardColor,
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                           prefixIcon: const Icon(LucideIcons.tag),
                         ),
                       ),
                       const SizedBox(height: 16),
                       
                       // Color Picker
                       const Text("Select Color", style: TextStyle(fontSize: 12, color: Colors.grey)),
                       const SizedBox(height: 8),
                       SizedBox(
                         height: 50,
                         child: ListView.separated(
                           scrollDirection: Axis.horizontal,
                           itemCount: AppColors.palette.length,
                           separatorBuilder: (_, __) => const SizedBox(width: 12),
                           itemBuilder: (ctx, index) {
                             final color = AppColors.palette[index];
                             final isSelected = _selectedColor == color;
                             return GestureDetector(
                               onTap: () => setState(() => _selectedColor = color),
                               child: AnimatedContainer(
                                 duration: const Duration(milliseconds: 200),
                                 width: 50,
                                 height: 50,
                                 decoration: BoxDecoration(
                                   color: color,
                                   shape: BoxShape.circle,
                                   border: Border.all(
                                     color: isSelected ? Colors.white : Colors.transparent, 
                                     width: isSelected ? 3 : 0
                                   ),
                                   boxShadow: isSelected ? [
                                     BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))
                                   ] : [],
                                 ),
                                 child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                               ),
                             );
                           },
                         ),
                       ),
                       const SizedBox(height: 16),

                       const Text("Select Icon", style: TextStyle(fontSize: 12, color: Colors.grey)),
                       const SizedBox(height: 8),
                       SizedBox(
                         height: 50,
                         child: ListView.separated(
                           scrollDirection: Axis.horizontal,
                           itemCount: _availableIcons.length,
                           separatorBuilder: (_, __) => const SizedBox(width: 12),
                           itemBuilder: (ctx, index) {
                             final iconKey = _availableIcons[index];
                             final isSelected = _selectedIcon == iconKey;
                             return GestureDetector(
                               onTap: () => setState(() => _selectedIcon = iconKey),
                               child: AnimatedContainer(
                                 duration: const Duration(milliseconds: 200),
                                 width: 50,
                                 height: 50,
                                 decoration: BoxDecoration(
                                   color: isSelected ? Color.lerp(theme.primaryColor, Colors.white, 0.3) : theme.cardColor,
                                   borderRadius: BorderRadius.circular(12),
                                   border: Border.all(
                                     color: isSelected ? Colors.white : theme.dividerColor,
                                     width: isSelected ? 3 : 1
                                   ),
                                   boxShadow: isSelected ? [
                                     BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
                                   ] : [],
                                 ),
                                 child: Center(
                                   child: CategoryIcon(
                                     iconKey: iconKey, 
                                     color: isSelected ? Colors.white : theme.iconTheme.color,
                                     size: 24,
                                   ),
                                 ),
                               ),
                             );
                           },
                         ),
                       ),
                       const SizedBox(height: 24),
                       SizedBox(
                         width: double.infinity,
                         child: ElevatedButton(
                           onPressed: () async {
                             if (_nameController.text.trim().isEmpty) return;
                             
                             final newCat = CategoryModel(
                               // id: DateTime.now().millisecondsSinceEpoch.toString(), // Removed ID
                               name: _nameController.text.trim(),
                               icon: _selectedIcon,
                               color: colorToHex(_selectedColor), 
                             );
                             
                             await _firestoreService.addCategory(uid, newCat);
                             _nameController.clear();
                             if (context.mounted) FocusScope.of(context).unfocus();
                           },
                           style: ElevatedButton.styleFrom(
                             backgroundColor: theme.primaryColor,
                             foregroundColor: Colors.white,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                             padding: const EdgeInsets.symmetric(vertical: 16),
                           ),
                           child: const Text("Create Category"),
                         ),
                       )
                     ],
                   ),
                ),
                
                const SizedBox(height: 32),
                const Text("My Categories", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                
                if (customCategories.isEmpty)
                   const Padding(padding: EdgeInsets.all(16), child: Text("No custom categories yet.")),

                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: customCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final cat = customCategories[index];
                    return ListTile(
                      tileColor: theme.cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: hexToColor(cat.color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: CategoryIcon(iconKey: cat.icon, color: hexToColor(cat.color)),
                      ),
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                        onPressed: () async {
                           await _firestoreService.deleteCategory(uid, cat);
                        },
                      ),
                    );
                  },
                ),
                
                // We could also list Default Categories as Read-Only if needed
              ],
            ),
          );
        },
      ),
    );
  }
}
