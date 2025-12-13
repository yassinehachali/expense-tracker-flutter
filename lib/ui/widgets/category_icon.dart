// File: lib/ui/widgets/category_icon.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CategoryIcon extends StatelessWidget {
  final String iconKey;
  final double size;
  final Color? color;

  const CategoryIcon({
    super.key,
    required this.iconKey,
    this.size = 20,
    this.color,
  });

  static const Map<String, IconData> _iconMap = {
    'Home': LucideIcons.home,
    'Utensils': LucideIcons.utensils,
    'Car': LucideIcons.car,
    'Zap': LucideIcons.zap,
    'Film': LucideIcons.film,
    'ShoppingBag': LucideIcons.shoppingBag,
    'HeartPulse': LucideIcons.heartPulse,
    'MoreHorizontal': LucideIcons.moreHorizontal,
    'Dumbbell': LucideIcons.dumbbell,
    'Smartphone': LucideIcons.smartphone,
    'Wifi': LucideIcons.wifi,
    'Briefcase': LucideIcons.briefcase,
    'Gift': LucideIcons.gift,
    'Plane': LucideIcons.plane,
    'GraduationCap': LucideIcons.graduationCap,
    'Coffee': LucideIcons.coffee,
    'Music': LucideIcons.music,
    'Gamepad2': LucideIcons.gamepad2,
    'PawPrint': LucideIcons.footprints,
    'Scissors': LucideIcons.scissors,
    'CreditCard': LucideIcons.creditCard,
    'Landmark': LucideIcons.landmark,
    'Baby': LucideIcons.baby,
    'Shirt': LucideIcons.shirt,
    'Banknote': LucideIcons.banknote,
    'Handshake': Icons.handshake,
    'CheckCircle': LucideIcons.checkCircle,
    'Check': LucideIcons.check,
  };

  @override
  Widget build(BuildContext context) {
    return Icon(
      _iconMap[iconKey] ?? LucideIcons.moreHorizontal,
      size: size,
      color: color,
    );
  }
}
