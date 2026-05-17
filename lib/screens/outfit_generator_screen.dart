import 'package:flutter/material.dart';

import '../models/clothing_item.dart';
import '../services/outfit_service.dart';
import '../widgets/clothing_card.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../data/mood_data.dart';
import '../widgets/empty_state.dart';

class OutfitGeneratorScreen extends StatefulWidget {
  final List<ClothingItem> wardrobe;

  const OutfitGeneratorScreen({super.key, required this.wardrobe});

  @override
  State<OutfitGeneratorScreen> createState() => _OutfitGeneratorScreenState();
}

class _OutfitGeneratorScreenState extends State<OutfitGeneratorScreen> {
  String selectedMood = '';

  List<ClothingItem> generatedOutfit = [];
  bool isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final availableMoods = OutfitService.getAvailableMoods(widget.wardrobe);

    final allMoods = [
      'Casual',
      'Cozy',
      'Classy',
      'Clean Girl',
      'Soft Girl',
      'Streetwear',
      'Minimal',
      'Dark Academia',
      'Feminine',
      'Chic',
      'Vintage',
      'Sporty',
      'Edgy',
      'Artsy',
      'Modest',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Generate Outfit')),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Choose a mood',

              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Wrap(
              spacing: 10,
              runSpacing: 10,

              children: allMoods.map((mood) {
                final isAvailable = availableMoods.contains(mood);

                final isSelected = selectedMood == mood;

                return GestureDetector(
                  onTap: isAvailable
                      ? () {
                          setState(() {
                            selectedMood = mood;
                            isGenerating = true;
                          });

                          Future.delayed(
                            const Duration(milliseconds: 1800),

                            () {
                              setState(() {
                                generatedOutfit = OutfitService.generateOutfit(
                                  wardrobe: widget.wardrobe,
                                  mood: mood,
                                );

                                isGenerating = false;
                              });
                            },
                          );
                        }
                      : null,

                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),

                    decoration: BoxDecoration(
                      color: !isAvailable
                          ? Colors.grey.shade300
                          : MoodData.moods[mood]!['color'].withOpacity(
                              isSelected ? 1 : 0.22,
                            ),

                      borderRadius: BorderRadius.circular(30),

                      border: Border.all(
                        color: isSelected
                            ? MoodData.moods[mood]!['color']
                            : Colors.transparent,

                        width: 2,
                      ),

                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: MoodData.moods[mood]!['color']
                                    .withOpacity(0.35),

                                blurRadius: 16,

                                offset: const Offset(0, 6),
                              ),
                            ]
                          : [],
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Text(
                          MoodData.moods[mood]!['emoji'],

                          style: const TextStyle(fontSize: 18),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          mood,

                          style: TextStyle(
                            fontWeight: FontWeight.w600,

                            color: !isAvailable
                                ? Colors.grey
                                : isSelected
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: isGenerating
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          const SizedBox(
                            width: 40,
                            height: 40,

                            child: CircularProgressIndicator(),
                          ),

                          const SizedBox(height: 30),

                          AnimatedTextKit(
                            repeatForever: true,

                            animatedTexts: [
                              TypewriterAnimatedText(
                                'curating your vibe ✷',

                                speed: const Duration(milliseconds: 90),

                                textStyle: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),

                              TypewriterAnimatedText(
                                'assembling your aesthetic...',

                                speed: const Duration(milliseconds: 90),

                                textStyle: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),

                              TypewriterAnimatedText(
                                'building your perfect fit ♡',

                                speed: const Duration(milliseconds: 90),

                                textStyle: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : generatedOutfit.isEmpty
                  ? const EmptyState(
                      icon: Icons.auto_awesome_rounded,

                      title: 'your next favorite outfit awaits ✷',

                      subtitle:
                          'choose a mood above and FitLab will curate a look from your wardrobe.',
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),

                      child: GridView.builder(
                        key: ValueKey(generatedOutfit.length),

                        itemCount: generatedOutfit.length,

                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,

                              crossAxisSpacing: 10,

                              mainAxisSpacing: 10,

                              childAspectRatio: 0.65,
                            ),

                        itemBuilder: (context, index) {
                          return ClothingCard(item: generatedOutfit[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
