import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;

  final String title;

  final String subtitle;

  const EmptyState({
    super.key,

    required this.icon,

    required this.title,

    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              icon,

              size: 70,

              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),

            const SizedBox(height: 24),

            Text(
              title,

              textAlign: TextAlign.center,

              style: Theme.of(context).textTheme.headlineMedium,
            ),

            const SizedBox(height: 12),

            Text(
              subtitle,

              textAlign: TextAlign.center,

              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
