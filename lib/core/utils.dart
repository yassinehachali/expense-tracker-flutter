// File: lib/core/utils.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'app_strings.dart';

class Utils {
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.decimalPattern('en_US');
    return '${formatter.format(amount)}\u00A0DH';
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy', AppStrings.language).format(date);
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
    'Bus': LucideIcons.bus,
    'Train': LucideIcons.train,
    'Fuel': LucideIcons.fuel,
    'Zap': LucideIcons.zap,
    'Film': LucideIcons.film,
    'Tv': LucideIcons.tv,
    'ShoppingBag': LucideIcons.shoppingBag,
    'HeartPulse': LucideIcons.heartPulse,
    'Stethoscope': LucideIcons.stethoscope,
    'Pill': LucideIcons.pill,
    'MoreHorizontal': LucideIcons.moreHorizontal,
    'Dumbbell': LucideIcons.dumbbell,
    'Smartphone': LucideIcons.smartphone,
    'Wifi': LucideIcons.wifi,
    'Briefcase': LucideIcons.briefcase,
    'Gift': LucideIcons.gift,
    'Plane': LucideIcons.plane,
    'GraduationCap': LucideIcons.graduationCap,
    'Book': LucideIcons.book,
    'Coffee': LucideIcons.coffee,
    'Beer': LucideIcons.beer,
    'Pizza': LucideIcons.pizza,
    'Music': LucideIcons.music,
    'Gamepad2': LucideIcons.gamepad2,
    'PawPrint': LucideIcons.footprints,
    'Cat': LucideIcons.cat,
    'Dog': LucideIcons.dog,
    'Scissors': LucideIcons.scissors,
    'CreditCard': LucideIcons.creditCard,
    'Landmark': LucideIcons.landmark,
    'Bank': LucideIcons.building2,
    'Baby': LucideIcons.baby,
    'Shirt': LucideIcons.shirt,
    'Banknote': LucideIcons.banknote,
    'Handshake': Icons.handshake,
    'Wallet': LucideIcons.wallet,
    'Coins': LucideIcons.coins,
    'Subscription': LucideIcons.calendarClock,
    'Recurring': LucideIcons.refreshCw,
    'Wrench': LucideIcons.wrench,
    'Hammer': LucideIcons.hammer,
    'Shower': LucideIcons.showerHead,
    'Flame': LucideIcons.flame,
    'Flower': LucideIcons.flower,
    'Laptop': LucideIcons.laptop,
    'Monitor': LucideIcons.monitor,
    'Sofa': LucideIcons.sofa,
    'Cigarette': LucideIcons.cigarette,
    'Vape': LucideIcons.cloudFog,
  };

  static List<String> get availableIconKeys => _iconMap.keys.toList();

  static IconData getIconData(String key) {
    return _iconMap[key] ?? LucideIcons.moreHorizontal;
  }

  // Smart Icon Suggestion Logic
  static String? suggestIconKey(String query) {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return null;

    // 1. Direct match with icon keys
    for (final key in _iconMap.keys) {
      if (key.toLowerCase() == lowerQuery) return key;
    }

    // 2. Keyword match
    for (final entry in _keywordToIcon.entries) {
      for (final keyword in entry.key) {
        // Standard "contains" match for sentence usage
        if (lowerQuery.contains(keyword)) {
          return entry.value;
        }
        // "Prefix" match for single-word typing (e.g. "Vap" -> "Vape")
        if (lowerQuery.length >= 2 && keyword.startsWith(lowerQuery)) {
           return entry.value;
        }
      }
      
      // Also check if the *target icon value* starts with query (e.g. "Vap" -> "Vape" icon key)
      // Since map values are the icon keys themselves (like 'Vape')
      final iconKey = entry.value.toLowerCase();
      if (lowerQuery.length >= 2 && iconKey.startsWith(lowerQuery)) {
         return entry.value;
      }
    }

    return null;
  }

  static const Map<List<String>, String> _keywordToIcon = {
    ['food', 'lunch', 'dinner', 'breakfast', 'meal', 'restaurant', 'eat', 'snack']: 'Utensils',
    ['coffee', 'cafe', 'tea', 'starbucks', 'espresso']: 'Coffee',
    ['drink', 'bar', 'alcohol', 'beer', 'wine', 'pub', 'party']: 'Beer',
    ['pizza', 'dominos', 'pizzahut', 'italian']: 'Pizza',
    
    ['car', 'uber', 'taxi', 'cab', 'drive', 'parking', 'toyota', 'bmw', 'mechanic', 'repair']: 'Car',
    ['fuel', 'gas', 'station', 'petrol', 'diesel', 'oil']: 'Fuel',
    ['bus', 'transport', 'ticket', 'public']: 'Bus',
    ['train', 'metro', 'subway', 'rail']: 'Train',
    ['plane', 'flight', 'travel', 'trip', 'airline', 'airport', 'holiday', 'vacation']: 'Plane',
    
    ['electric', 'bill', 'power', 'light', 'energy', 'zap']: 'Zap',
    ['wifi', 'internet', 'broadband', 'connection', 'data', 'fiber']: 'Wifi',
    ['phone', 'mobile', 'call', 'recharge', 'topup', 'iphone', 'samsung']: 'Smartphone',
    ['water', 'bill', 'shower', 'bath']: 'Shower',
    ['gas', 'heating']: 'Flame',
    
    ['movie', 'cinema', 'theatre', 'film', 'netflix', 'hbo', 'disney']: 'Film',
    ['tv', 'television', 'series', 'show', 'cable']: 'Tv',
    ['music', 'spotify', 'apple m', 'song', 'concert']: 'Music',
    ['game', 'gaming', 'ps5', 'xbox', 'steam', 'playstation', 'nintendo']: 'Gamepad2',
    
    ['doctor', 'medical', 'health', 'hospital', 'clinic', 'visit']: 'Stethoscope',
    ['medication', 'pharmacy', 'drug', 'medicine', 'vitamin']: 'Pill',
    ['heart', 'gym', 'fitness', 'workout', 'sport', 'exercise', 'training', 'yoga']: 'Dumbbell',
    
    ['shop', 'buy', 'store', 'grocer', 'supermarket', 'mart', 'market']: 'ShoppingBag',
    ['gift', 'present', 'birthday', 'donation']: 'Gift',
    ['shirt', 'cloth', 'dress', 'jeans', 'fashion', 'wear', 'zara', 'h&m']: 'Shirt',
    
    ['school', 'college', 'university', 'tuition', 'fee', 'class', 'course', 'lesson']: 'GraduationCap',
    ['book', 'library', 'stationery', 'paper', 'novel', 'read']: 'Book',
    
    ['house', 'rent', 'mortgage', 'apartment', 'home', 'furniture', 'decor']: 'Home',
    ['sofa', 'chair', 'bed', 'table', 'couch']: 'Sofa',
    ['repair', 'fix', 'maintain', 'service']: 'Wrench',
    ['tools', 'hardware', 'construction']: 'Hammer',
    ['garden', 'plant', 'flower', 'florist']: 'Flower',
    
    ['cat', 'kitty', 'kitten', 'meow']: 'Cat',
    ['dog', 'puppy', 'vet', 'pet']: 'Dog',
    
    ['salary', 'income', 'wage', 'pay', 'bonus', 'deposit']: 'Banknote',
    ['bank', 'transfer', 'atm', 'withdraw', 'saving']: 'Bank',
    ['tax', 'govt', 'fine', 'fee']: 'Landmark',
    ['loan', 'debt', 'emi', 'credit']: 'CreditCard',
    ['invest', 'stock', 'share', 'trading', 'crypto', 'bitcoin']: 'Coins',
    ['wallet', 'cash', 'money']: 'Wallet',
    
    ['job', 'work', 'office', 'business', 'meeting']: 'Briefcase',
    ['compute', 'tech', 'software', 'dev', 'pc']: 'Monitor',
    ['laptop', 'macbook']: 'Laptop',
    
    ['sub', 'netflix', 'prime', 'monthly', 'yearly']: 'Subscription',
    
    ['smoke', 'cigarette', 'tobacco', 'cigar']: 'Cigarette',
    ['vape', 'eliquid', 'pod', 'juice']: 'Vape',
  };
}
