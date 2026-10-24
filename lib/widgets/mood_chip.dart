import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/moods.dart';
import '../theme/app_theme.dart';

/// Pill-shaped mood selector used on the wardrobe, add/edit and generator
/// screens. Pass [mood] = null for an "All" chip.
class MoodChip extends StatelessWidget {
  const MoodChip({
    super.key,
    required this.mood,
    required this.selected,
    this.onTap,
    this.count,
    this.enabled = true,
    this.allLabel = 'All',
  });

  final Mood? mood;
  final bool selected;
  final VoidCallback? onTap;
  final int? count;
  final bool enabled;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FitLabColors.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = mood?.color ?? theme.colorScheme.primary;

    final Color background;
    final Color foreground;
    if (!enabled) {
      background = tokens.chipBackground.withValues(alpha: 0.5);
      foreground = tokens.subtleText.withValues(alpha: 0.6);
    } else if (selected) {
      background = accent;
      foreground = mood?.onColor ?? theme.colorScheme.onPrimary;
    } else {
      background = accent.withValues(alpha: isDark ? 0.28 : 0.22);
      foreground = tokens.chipForeground;
    }

    final label = mood?.label ?? allLabel;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: count == null ? label : '$label, $count pieces',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: selected ? 1.04 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: enabled && onTap != null
                ? () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? accent : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mood != null) ...[
                    Text(mood!.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
