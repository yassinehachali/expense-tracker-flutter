import 'package:flutter/material.dart';
import '../../core/utils.dart';

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

  @override
  Widget build(BuildContext context) {
    return Icon(
      Utils.getIconData(iconKey),
      size: size,
      color: color,
    );
  }
}
