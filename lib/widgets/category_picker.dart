import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/categories.dart';

class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ClothingCategory? selected;
  final ValueChanged<ClothingCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in ClothingCategory.values)
          ChoiceChip(
            avatar: Text(category.emoji),
            label: Text(category.label),
            selected: selected == category,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              onChanged(category);
            },
          ),
      ],
    );
  }
}
