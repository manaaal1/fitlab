# FitLab

FitLab is a Pinterest-inspired wardrobe and outfit generation app built with Flutter.

Users can:

- add clothing pieces from the gallery or camera
- tag each piece with a category and a mood
- generate aesthetic outfit combinations for any mood
- save the looks they love, organised by mood
- enjoy a handcrafted, animated UI in light or dark mode

## Features

- **Mood-based outfit generation.** Picks a top and bottom or a dress, then layers outerwear, shoes and an accessory. Shuffle avoids repeating the last look, and the app tells you which piece is missing when a mood can't make a full outfit yet.
- **Pin and shuffle.** Pin the pieces you like in a generated look and shuffle only the rest.
- **Style this piece.** From any piece, jump straight to looks built around it.
- **Colour matching.** Pieces tagged with colours favour combinations that go together; neutrals pair with anything.
- **Wear tracking.** Log what you wore today for a piece or a whole look, and see how often and how recently each piece was worn.
- **Forgotten pieces.** A gentle nudge toward clothes you haven't worn in a month.
- **Backup and restore.** Save your whole wardrobe, photos and looks to one file, and restore it on any device.
- **Saved looks.** Name and keep outfits, grouped by mood, with favourites, rename and swipe-to-delete with undo.
- **Share a look as an image.** Renders a 4:5 Pinterest-style card with the look's name, mood and photos, then opens the system share sheet.
- **Responsive Pinterest-style wardrobe grid.** Two to six columns depending on width, with search, mood, category and favourite filters.
- **Add, edit and favourite pieces**, with several moods per piece, optional colour and notes. The colour is detected from the photo automatically.
- **Add several pieces at once** by picking multiple photos from the gallery.
- **Dark, light or system theme**, remembered between launches.
- **Animated UI.** Staggered grid entrance, hero transitions, haptics, typewriter "curating" state.
- **First-launch onboarding** and a settings screen.
- **Local database storage** with SQLite and versioned migrations. Photos are copied into app storage so they survive cache clears.
- **Custom app branding**: icon and light/dark native splash. Caveat and Poppins fonts are bundled, so the app works offline from first launch.

## Getting started

```bash
flutter pub get
flutter run
```

Supported targets are Android, iOS, macOS and Windows. Windows and Linux use the `sqflite_common_ffi` backend automatically. The web target is not supported because the app reads photos from the file system.

## Running checks

```bash
flutter analyze
flutter test
```

Tests cover the outfit generator, model parsing, the v2 to v3 database migration, both repositories, and the main UI flows. Database tests run against an in-memory SQLite database.

Golden tests in `test/goldens` render the real screens to PNG with the bundled fonts. Text rendering differs slightly between operating systems, so CI skips them. After an intentional UI change, regenerate them on the machine that owns them:

```bash
flutter test --tags golden --update-goldens
```

The end-to-end flow in `integration_test` needs a connected device or emulator:

```bash
flutter test integration_test
```

## Project structure

```
lib/
├── main.dart              # platform setup, opens DB, runs the app
├── app/app.dart           # providers, theme wiring, onboarding gate
├── core/constants/        # Mood and ClothingCategory enums
├── core/utils/            # ImageStorage (owns the photo folder)
├── data/database/         # schema and migrations
├── data/models/           # ClothingItem, Outfit
├── data/repositories/     # WardrobeRepository, OutfitRepository
├── domain/                # OutfitGenerator (pure Dart)
├── providers/             # Settings, Wardrobe, Outfits
├── screens/               # wardrobe, generator, looks, add/edit, detail, settings, onboarding
├── theme/app_theme.dart   # light/dark themes and FitLabColors tokens
└── widgets/               # cards, chips, empty states, animations
```

## Release signing (Android)

Create a keystore and an `android/key.properties` file. Both are git-ignored.

```bash
keytool -genkey -v -keystore ~/fitlab-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

```properties
storePassword=<your store password>
keyPassword=<your key password>
keyAlias=upload
storeFile=C:/Users/<you>/fitlab-upload.jks
```

Then build with `flutter build appbundle`. Without `key.properties`, release builds are signed with the debug key.

## Built with

- Flutter and Dart
- SQLite (`sqflite`, `sqflite_common_ffi`)
- Provider
- Material Design 3

## Author

crafted with ♡ by manal
