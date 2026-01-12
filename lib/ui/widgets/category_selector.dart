import 'package:flutter/material.dart';
import '../../data/models/category_model.dart';
import '../../core/app_strings.dart';
import 'category_icon.dart';

class CategorySelector extends StatefulWidget {
  final List<CategoryModel> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  late final ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Schedule scroll after build to ensure list is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(CategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
       _scrollToSelected();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (widget.categories.isEmpty) return;
    
    final index = widget.categories.indexWhere((c) => c.name == widget.selectedCategory);
    if (index != -1 && _scrollController.hasClients) {
       // Item width = 56 (container) + 16 (separator) approx = 72
       final offset = index * 72.0;

       // Verify dimensions exist before scrolling
       if (_scrollController.position.hasContentDimensions) {
          _scrollController.animateTo(
           offset,
           duration: const Duration(milliseconds: 300),
           curve: Curves.easeInOut,
         );
       } else {
         // Retry after frame if layout not ready
         WidgetsBinding.instance.addPostFrameCallback((_) {
           if (mounted && _scrollController.hasClients && _scrollController.position.hasContentDimensions) {
             _scrollController.animateTo(
               offset,
               duration: const Duration(milliseconds: 300),
               curve: Curves.easeInOut,
             );
           }
         });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) return const SizedBox();
    final theme = Theme.of(context);

    return SizedBox(
      height: 100,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 4), // Add padding to avoid clip
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final isSelected = category.name == widget.selectedCategory;
          
          return GestureDetector(
            onTap: () => widget.onCategorySelected(category.name),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    // Use colorScheme.primary for better visibility in both modes
                    color: isSelected ? theme.colorScheme.primary : theme.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      // Prominent outline ring when selected
                      color: isSelected 
                          ? theme.colorScheme.primary 
                          : theme.dividerColor,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ] : [],
                  ),
                  child: Center(
                    child: CategoryIcon(
                      iconKey: category.icon,
                      size: 24,
                      // High contrast: white/black on primary
                      color: isSelected ? theme.colorScheme.onPrimary : theme.iconTheme.color,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.getCategoryName(category.name),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    // Use primary color for text when selected to match
                    color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
