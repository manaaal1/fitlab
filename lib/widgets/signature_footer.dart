import 'package:flutter/material.dart';

class SignatureFooter extends StatelessWidget {
  const SignatureFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),

      child: Center(
        child: Text(
          'crafted with ♡ by manal',

          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,

            letterSpacing: 0.5,

            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }
}
