import 'package:flutter/material.dart';

import '../core/constants/moods.dart';
import '../core/constants/swatches.dart';
import '../theme/app_theme.dart';
import 'mood_chip.dart';

/// Bold label above a form section, with an optional inline error.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.error, this.trailing});

  final String text;
  final String? error;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        children: [
          Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (error != null)
            Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else if (trailing != null)
            Text(trailing!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Multi-select mood chips. Keeps at least one mood selected.
class MoodMultiPicker extends StatelessWidget {
  const MoodMultiPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<Mood> selected;
  final ValueChanged<Set<Mood>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mood in Mood.values)
          MoodChip(
            mood: mood,
            selected: selected.contains(mood),
            onTap: () {
              final next = {...selected};
              if (!next.remove(mood)) next.add(mood);
              if (next.isNotEmpty) onChanged(next);
            },
          ),
      ],
    );
  }
}

/// Preset colour swatches; tapping the selected one clears it.
class SwatchPicker extends StatelessWidget {
  const SwatchPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.size = 44,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final swatch in Swatch.all)
          Semantics(
            button: true,
            selected: selected == swatch.hex,
            label: 'Colour ${swatch.name}',
            child: GestureDetector(
              onTap: () =>
                  onChanged(selected == swatch.hex ? null : swatch.hex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: swatch.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == swatch.hex
                        ? theme.colorScheme.primary
                        : theme.dividerColor,
                    width: selected == swatch.hex ? 3 : 1,
                  ),
                ),
                child: selected == swatch.hex
                    ? Icon(
                        Icons.check_rounded,
                        size: size * 0.45,
                        color: AppTheme.contrastOn(swatch.color),
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
