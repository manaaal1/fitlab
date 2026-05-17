import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'screens/add_clothing_screen.dart';
import 'models/clothing_item.dart';
import 'widgets/clothing_card.dart';
import 'services/database_service.dart';
import 'screens/outfit_generator_screen.dart';
import 'theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'widgets/signature_footer.dart';
import 'widgets/empty_state.dart';

import 'providers/theme_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),

      child: const FitLabApp(),
    ),
  );
}

class FitLabApp extends StatelessWidget {
  const FitLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          theme: AppTheme.lightTheme,

          darkTheme: AppTheme.darkTheme,

          themeMode: themeProvider.themeMode,

          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ClothingItem> wardrobe = [];

  @override
  void initState() {
    super.initState();

    loadWardrobe();
  }

  Future<void> loadWardrobe() async {
    final items = await DatabaseService.getClothingItems();

    setState(() {
      wardrobe = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FitLab'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),

                child: Row(
                  children: [
                    Icon(
                      Icons.wb_sunny_rounded,

                      color: themeProvider.isDarkMode
                          ? Colors.grey
                          : Colors.orange,
                    ),

                    Switch(
                      value: themeProvider.isDarkMode,

                      onChanged: (value) {
                        themeProvider.toggleTheme();
                      },
                    ),

                    Icon(
                      Icons.nightlight_round,

                      color: themeProvider.isDarkMode
                          ? Colors.deepPurpleAccent
                          : Colors.grey,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        centerTitle: true,
      ),

      body: wardrobe.isEmpty
          ? const EmptyState(
              icon: Icons.checkroom_rounded,

              title: 'your wardrobe is feeling a little empty ♡',

              subtitle:
                  'add your favorite pieces to start building outfits and aesthetics.',
            )
          : MasonryGridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              itemCount: wardrobe.length,

              itemBuilder: (context, index) {
                return ClothingCard(
                  item: wardrobe[index],

                  onDelete: () async {
                    await DatabaseService.deleteClothing(wardrobe[index].id!);

                    loadWardrobe();
                  },
                );
              },
            ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          FloatingActionButton(
            heroTag: 'generate',

            onPressed: () {
              Navigator.push(
                context,

                MaterialPageRoute(
                  builder: (_) => OutfitGeneratorScreen(wardrobe: wardrobe),
                ),
              );
            },

            child: const Icon(Icons.auto_awesome),
          ),

          const SizedBox(height: 15),

          FloatingActionButton(
            heroTag: 'add',

            onPressed: () async {
              final result = await Navigator.push(
                context,

                MaterialPageRoute(builder: (_) => const AddClothingScreen()),
              );

              if (result == true) {
                loadWardrobe();
              }
            },

            child: const Icon(Icons.add),
          ),
          const SignatureFooter(),
        ],
      ),
    );
  }
}
