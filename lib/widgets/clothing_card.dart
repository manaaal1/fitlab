import 'dart:io';

import 'package:flutter/material.dart';

import '../models/clothing_item.dart';

class ClothingCard extends StatefulWidget {
  final ClothingItem item;
  final VoidCallback? onDelete;

  const ClothingCard({super.key, required this.item, this.onDelete});

  @override
  State<ClothingCard> createState() => _ClothingCardState();
}

class _ClothingCardState extends State<ClothingCard> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    final image = File(widget.item.imagePath);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.95, end: 1),

      duration: const Duration(milliseconds: 400),

      curve: Curves.easeOut,

      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },

      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            isPressed = true;
          });
        },

        onTapUp: (_) {
          setState(() {
            isPressed = false;
          });
        },

        onTapCancel: () {
          setState(() {
            isPressed = false;
          });
        },
        onLongPress: () {
          showDialog(
            context: context,

            builder: (_) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),

                title: const Text('Delete Item?'),

                content: Text('Remove "${widget.item.name}" from wardrobe?'),

                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },

                    child: const Text('Cancel'),
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);

                      if (widget.onDelete != null) {
                        widget.onDelete!();
                      }
                    },

                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          );
        },

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),

          curve: Curves.easeOut,

          transform: Matrix4.translationValues(0, isPressed ? -8 : 0, 0),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),

            color: Theme.of(context).colorScheme.surface,

            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isPressed ? 0.18 : 0.08),

                blurRadius: isPressed ? 22 : 12,

                offset: Offset(0, isPressed ? 12 : 6),
              ),
            ],
          ),

          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // IMAGE
                Image.file(image, fit: BoxFit.cover, width: double.infinity),

                Padding(
                  padding: const EdgeInsets.all(14),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        widget.item.name,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        widget.item.category,

                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
