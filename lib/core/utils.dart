// File: lib/core/utils.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class Utils {
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.decimalPattern('en_US');
    return '${formatter.format(amount)}\u00A0DH';
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  // Sorting logic helper
  static int compareExpenses(dynamic a, dynamic b, String filterType) {
     int dateA = DateTime.parse(a.date).millisecondsSinceEpoch;
     int dateB = DateTime.parse(b.date).millisecondsSinceEpoch;

     if (dateA != dateB) {
       return dateB - dateA;
     }

     // Secondary sort by createdAt if available
     // Note: In Flutter models we might handle this differently, but keeping simple
     return 0;
  }
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static String getMonthName(int index) {
    if (index < 0 || index > 11) return 'Invalid';
    return _months[index];
  }

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
    'Wallet': LucideIcons.wallet,
  };

  static IconData getIconData(String key) {
    return _iconMap[key] ?? LucideIcons.moreHorizontal;
  }
}
