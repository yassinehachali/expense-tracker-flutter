// File: lib/core/constants.dart
import 'package:flutter/material.dart';

class AppColors {
  static const List<Color> palette = [
    Color(0xFFef4444), Color(0xFFf97316), Color(0xFFf59e0b), Color(0xFF84cc16), Color(0xFF10b981),
    Color(0xFF06b6d4), Color(0xFF3b82f6), Color(0xFF6366f1), Color(0xFF8b5cf6), Color(0xFFd946ef),
    Color(0xFFf43f5e), Color(0xFF64748b)
  ];
}

const List<Map<String, dynamic>> DEFAULT_CATEGORIES = [
  { 'name': 'Housing', 'color': '#06b6d4', 'icon': 'Home' },     // Cyan
  { 'name': 'Food', 'color': '#ec4899', 'icon': 'Utensils' },    // Pink
  { 'name': 'Transport', 'color': '#f97316', 'icon': 'Car' },    // Orange
  { 'name': 'Utilities', 'color': '#3b82f6', 'icon': 'Zap' },    // Blue
  { 'name': 'Entertainment', 'color': '#a855f7', 'icon': 'Film' }, // Purple
  { 'name': 'Shopping', 'color': '#10b981', 'icon': 'ShoppingBag' }, // Emerald
  { 'name': 'Health', 'color': '#ef4444', 'icon': 'HeartPulse' }, // Red
  { 'name': 'Others', 'color': '#64748b', 'icon': 'MoreHorizontal' }, // Slate
];

const List<String> MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

/// Helper to parse hex color string '#RRGGBB' to Color
Color hexToColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

/// Helper to convert Color to hex string '#RRGGBB'
String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2)}';
}
