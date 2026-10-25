import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/image_storage.dart';
import '../data/backup/backup_service.dart';
import '../data/repositories/outfit_repository.dart';
import '../data/repositories/wardrobe_repository.dart';
import '../providers/outfits_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/style_request.dart';
import '../providers/wardrobe_provider.dart';
import '../screens/home/root_shell.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../theme/app_theme.dart';
import 'dart:math';

/// Everything the widget tree needs from outside Flutter. Built once in
/// `main` (or with in-memory fakes in tests).
class AppDependencies {
  const AppDependencies({
    required this.prefs,
    required this.images,
    required this.wardrobeRepository,
    required this.outfitRepository,
    required this.backup,
    this.generatorRandom,
    this.clock,
  });

  final SharedPreferences prefs;
  final ImageStorage images;
  final WardrobeRepository wardrobeRepository;
  final OutfitRepository outfitRepository;
  final BackupService backup;
  final Random? generatorRandom;
  final DateTime Function()? clock;
}

class FitLabApp extends StatelessWidget {
  const FitLabApp({
    super.key,
    required this.dependencies,
    this.useGoogleFonts = true,
    this.generatorRevealDelay,
  });

  final AppDependencies dependencies;
  final bool useGoogleFonts;
  final Duration? generatorRevealDelay;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ImageStorage>.value(value: dependencies.images),
        Provider<BackupService>.value(value: dependencies.backup),
        ChangeNotifierProvider(create: (_) => StyleRequestController()),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(dependencies.prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => WardrobeProvider(
            dependencies.wardrobeRepository,
            dependencies.images,
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => OutfitsProvider(
            dependencies.outfitRepository,
            clock: dependencies.clock,
          )..load(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'FitLab',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(useGoogleFonts: useGoogleFonts),
          darkTheme: AppTheme.dark(useGoogleFonts: useGoogleFonts),
          themeMode: settings.themeMode,
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: settings.seenOnboarding
                ? RootShell(
                    key: const ValueKey('shell'),
                    generatorRevealDelay: generatorRevealDelay,
                    generatorRandom: dependencies.generatorRandom,
                  )
                : const OnboardingScreen(key: ValueKey('onboarding')),
          ),
        ),
      ),
    );
  }
}
