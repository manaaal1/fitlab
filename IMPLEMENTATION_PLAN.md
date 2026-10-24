# FitLab — Implementation Plan to Completion

_Prepared 2026-10-06 against the current codebase (12 Dart files, ~1,300 lines, Flutter 3.41.4 / Dart 3.11.1)._

> **Status (2026-10-06): implemented.** Phases 0–6 are done, plus share-as-image, bundled fonts, golden screenshot tests and a device integration test. `flutter analyze` reports no issues, 52 tests pass, and a debug APK builds.
> Verified on an Android 17 emulator: the integration test passes, and adding a piece through the real photo picker, persistence after a restart and cache wipe, generating and the share sheet all work by hand. Not yet verified: iOS, a physical phone, and Windows desktop (needs the Visual Studio C++ workload). Web is unsupported because the app reads photos from the file system.
> **1.1.0 (2026-10-06):** added the nine "worth building" features: backup and restore, pin and shuffle, style this piece, multi-photo add, multiple moods per piece, wear tracking, forgotten pieces, colour detection and colour matching. Database is now v4. These are covered by unit, database and widget tests but have not yet been tried on the emulator.

---

## 0. Where the project actually stands

### What works today

| Area | Status | Notes |
|---|---|---|
| Home wardrobe grid | ✅ Working | `MasonryGridView` with a **fixed** 3 columns. Not responsive despite README claim. |
| Add clothing | ⚠️ Partial | Gallery picker, name, free-text category, mood chips, save. Hard-coded light colors break dark mode. |
| Outfit generation | ⚠️ Partial | Random pick per category after a fake 1.8 s delay. Only matches if category is typed exactly `top` / `bottom` / `outerwear` / `shoes`. |
| Delete item | ❌ Broken | `deleteClothing` targets table `clothing`; the table is named `clothes`. Throws `no such table`. |
| Dark / light mode | ⚠️ Partial | Toggle works but is **not persisted**; add screen and generator chips ignore the theme. |
| Local DB | ⚠️ Partial | Single `clothes` table, version 2, no `onUpgrade`. Image paths point at the picker's **cache** dir, which the OS can purge. |
| Branding | ✅ Mostly | Icon + native splash configured and generated. App label still `fit_lab`, id `com.example.fit_lab`. |
| Saved outfits ("organize outfits by mood") | ❌ Missing | No persistence of generated outfits anywhere. |
| Edit item | ❌ Missing | |
| Tests | ❌ Failing | `test/widget_test.dart` is the untouched counter template. |
| Desktop (Windows) dev run | ❌ Crashes | `sqflite` has no Windows implementation; needs `sqflite_common_ffi`. |

### Analyzer baseline (`flutter analyze`)

```
info - use_build_context_synchronously    lib/screens/add_clothing_screen.dart:71
info - deprecated_member_use (withOpacity) lib/widgets/clothing_card.dart:110
info - deprecated_member_use (withOpacity) lib/widgets/empty_state.dart:35
```

`outfit_generator_screen.dart` also uses `withOpacity` on a `dynamic` value, so the analyzer can't see it.

### Full defect list found during review

1. **DB delete uses wrong table name** — `lib/services/database_service.dart:60` (`'clothing'` → `'clothes'`).
2. **Category is free text** but the generator does an exact lowercase match on 4 strings. Most user input will never produce an outfit.
3. **Images saved by cache path** (`image.path` from `image_picker`). Must be copied to the app documents dir.
4. **`Image.file` has no `errorBuilder`** — a missing file renders the red error widget.
5. **`Future.delayed` → `setState` without `mounted` check** in the generator. Crash if the user backs out during the 1.8 s delay.
6. **`Navigator.pop(context)` after `await`** without `mounted` check in `saveItem`.
7. **Mood list duplicated 3×** (add screen, generator, `MoodData`). `MoodData` is `Map<String, Map<String, dynamic>>` with unsafe `!` and `dynamic` access.
8. **Hard-coded colors** (`Colors.grey.shade200`, `Colors.deepPurple`, `Colors.black87`) on the add screen and generator chips → unreadable in dark mode.
9. **Theme not persisted** across launches.
10. **Grid column count fixed at 3** regardless of width.
11. **`SignatureFooter` is inside the FAB `Column`** — it floats above the FABs instead of sitting under the grid.
12. **`flutter_launcher_icons` / `flutter_native_splash` in `dependencies`** instead of `dev_dependencies` (ships tooling in the app binary).
13. **Validation is silent** — `saveItem` just `return`s with no feedback when fields are empty.
14. **Generator shows the "awaits" empty state** even when a mood has items but none in a recognised category — misleading.
15. **No `onUpgrade`** on the DB, so there is no path to add tables.
16. **iOS `Info.plist` lacks `NSPhotoLibraryUsageDescription` / `NSCameraUsageDescription`** — required once camera capture is added, and good practice for review.
17. **Android label `fit_lab`**, applicationId `com.example.fit_lab`, release build signed with the debug key.
18. **`pubspec.yaml` description** is the template default.
19. **Test file fails**, and would also fail because `HomeScreen.initState` hits sqflite with no test binding.

---

## 1. Target architecture (minimal change, maximum stability)

Keep **Provider** (already a dependency). Switching to Riverpod or Bloc is not worth it at this size. Introduce one layer of separation so screens stop talking to the DB directly.

```
lib/
├── main.dart                     # ffi init + MultiProvider + runApp only
├── app/
│   └── app.dart                  # FitLabApp widget (MaterialApp, theme wiring)
├── core/
│   ├── constants/
│   │   ├── moods.dart            # single source of truth: enum Mood + MoodMeta
│   │   └── categories.dart       # enum ClothingCategory
│   └── utils/
│       └── image_storage.dart    # copy picked image → app docs dir, delete on remove
├── data/
│   ├── database/
│   │   ├── app_database.dart     # open/migrate, versioned schema
│   │   └── migrations.dart       # v1→v2→v3 scripts
│   ├── models/
│   │   ├── clothing_item.dart
│   │   └── outfit.dart           # NEW
│   └── repositories/
│       ├── wardrobe_repository.dart
│       └── outfit_repository.dart
├── domain/
│   └── outfit_generator.dart     # pure Dart, fully unit-testable
├── providers/
│   ├── theme_provider.dart       # + persistence
│   ├── wardrobe_provider.dart    # NEW: list, filters, CRUD, loading/error state
│   └── outfits_provider.dart     # NEW: saved outfits
├── screens/
│   ├── home/                     # wardrobe grid + filter bar
│   ├── add_edit_clothing/        # single screen for add AND edit
│   ├── generator/
│   ├── saved_outfits/            # NEW
│   └── settings/                 # NEW (theme, about, clear data)
├── theme/
│   └── app_theme.dart            # + ThemeExtension for mood/surface tokens
└── widgets/
    ├── clothing_card.dart
    ├── mood_chip.dart            # NEW: shared between add + generator
    ├── category_picker.dart      # NEW
    ├── empty_state.dart
    ├── fitlab_image.dart         # NEW: Image.file with error/placeholder
    └── signature_footer.dart
```

Dependencies to add:

```yaml
dependencies:
  path_provider: ^2.1.5        # app documents dir for images
  shared_preferences: ^2.3.0   # theme + onboarding persistence
  sqflite_common_ffi: ^2.3.0   # Windows/Linux/macOS desktop + in-memory tests
  intl: ^0.20.0                # date formatting for saved outfits
  package_info_plus: ^8.0.0    # version string on settings screen

dev_dependencies:
  flutter_launcher_icons: ^0.14.4   # MOVE here
  flutter_native_splash: ^2.4.7     # MOVE here
  mocktail: ^1.0.4                  # repository fakes in widget tests
```

---

## 2. Phased plan

Effort estimates assume one developer. Each phase ends in a runnable, committable state.

---

### Phase 0 — Stabilise (½ day)

**Goal:** app runs on Windows for dev, no crashes, analyzer clean, tests green.

| # | Task | File(s) | Detail |
|---|---|---|---|
| 0.1 | Fix delete table name | `lib/services/database_service.dart` | `'clothing'` → `'clothes'`. |
| 0.2 | Desktop DB support | `lib/main.dart` | Before `runApp`: if not web and platform is Windows/Linux/macOS, call `sqfliteFfiInit()` and set `databaseFactory = databaseFactoryFfi`. Add `sqflite_common_ffi`. |
| 0.3 | `mounted` guards | `add_clothing_screen.dart`, `outfit_generator_screen.dart` | `if (!mounted) return;` after every `await` and inside the `Future.delayed` callback. |
| 0.4 | Replace `withOpacity` | `clothing_card.dart`, `empty_state.dart`, `outfit_generator_screen.dart` | `.withValues(alpha: x)`. |
| 0.5 | Move icon/splash packages to `dev_dependencies` | `pubspec.yaml` | |
| 0.6 | Replace default test | `test/widget_test.dart` | Delete the counter test. Add a placeholder test that passes; real tests land in Phase 5 once repositories are injectable. |
| 0.7 | Fix `SignatureFooter` placement | `main.dart` | Remove from the FAB column; render as the last item under the grid (or in Settings, see 3.9). |

**Acceptance:** `flutter analyze` reports 0 issues. `flutter test` passes. `flutter run -d windows` launches, and an add → delete round-trip works.

---

### Phase 1 — Data layer hardening (1.5 days)

**Goal:** correct, migratable schema; images that survive; a single source of truth for moods and categories.

| # | Task | Detail |
|---|---|---|
| 1.1 | **`ClothingCategory` enum** | `top, bottom, dress, outerwear, shoes, accessory`. Each has `label` and `icon`. Store as `String` via `.name`. `fromString` maps legacy free text with synonyms (`tee/shirt/blouse → top`, `jeans/pants/skirt → bottom`, `jacket/coat → outerwear`, `sneakers/boots/heels → shoes`) and falls back to `top`. |
| 1.2 | **`Mood` enum + `MoodMeta`** | Move the 15 moods into `enum Mood { casual, cozy, ... }` with an extension providing `label`, `emoji`, `Color color`, and `Color onColor` (contrast text color via `ThemeData.estimateBrightnessForColor`). Delete `mood_data.dart` and both hard-coded lists. |
| 1.3 | **Expand `ClothingItem`** | Typed `ClothingCategory category`, typed `Mood mood`, `DateTime createdAt`, `bool isFavorite`, `String? colorHex`, `String? notes`. Add `copyWith`, `==` / `hashCode`. |
| 1.4 | **`Outfit` model** | `id, name, Mood mood, List<int> itemIds, DateTime createdAt, bool isFavorite`. |
| 1.5 | **Schema v3 + migrations** | `AppDatabase.open()` with `onConfigure` (`PRAGMA foreign_keys = ON`), `onCreate` building v3 directly, and `onUpgrade` running `migrations[oldVersion..newVersion]`. v2→v3: `ALTER TABLE clothes ADD COLUMN` for `createdAt TEXT`, `isFavorite INTEGER DEFAULT 0`, `colorHex TEXT`, `notes TEXT`; normalise existing `category` strings through 1.1; create `outfits(id, name, mood, createdAt, isFavorite)` and `outfit_items(outfitId, clothingId, FOREIGN KEY ... ON DELETE CASCADE)`. |
| 1.6 | **`ImageStorage`** | `Future<String> persist(XFile)` copies into `<appDocDir>/wardrobe/<timestamp>-<rand>.<ext>` and returns the **file name only**. `Future<void> delete(String)`. Resolve the absolute path at read time so iOS container path changes don't break images. Pick with `imageQuality: 85, maxWidth: 1600`. Migration copies old absolute-path rows into the folder if the source still exists; otherwise marks the path empty so `FitLabImage` shows a placeholder. |
| 1.7 | **`WardrobeRepository`** | `getAll`, `insert`, `update`, `delete` (also deletes image file), `deleteAll`. Takes a `Database` in the constructor for testability. |
| 1.8 | **`OutfitRepository`** | `getAll`, `getByMood`, `save(Outfit)` in a transaction (insert outfit + items), `delete`, `toggleFavorite`. Join query to hydrate items. |
| 1.9 | **`WardrobeProvider`** | Holds `items`, `moodFilter`, `categoryFilter`, `query`, `isLoading`, `error`. Exposes a `filtered` getter. CRUD methods call the repository and refresh. |
| 1.10 | **`OutfitsProvider`** | Same shape for saved outfits. |
| 1.11 | Wire `MultiProvider` in `main.dart` | `ThemeProvider`, `WardrobeProvider`, `OutfitsProvider`; repositories built once from the opened `Database`. |

**Acceptance:** Existing installs with v2 data open without crashing and show their items. Picked images display after an app restart and after clearing cache. Migration unit tests pass (Phase 5).

---

### Phase 2 — Complete the core features (2 days)

**Goal:** every bullet in the README is actually true.

#### 2A. Add / Edit clothing (`screens/add_edit_clothing/`)

- One screen taking `ClothingItem? existing`. Title "Add Piece" or "Edit Piece".
- **Image:** bottom sheet with Gallery / Camera / Remove. Camera needs `NSCameraUsageDescription` on iOS (Phase 4).
- **Category:** replace the free-text field with `CategoryPicker` (segmented chips with icons). Required.
- **Name:** `TextFormField`, required, max 40 chars.
- **Mood:** shared `MoodChip` widget, theme-aware.
- **Optional:** colour swatch picker (8 presets) and a notes field.
- **Validation:** `Form` + `GlobalKey<FormState>`, inline errors, Save disabled while invalid or saving, `SnackBar` on success.
- **Edit entry point:** tap a card on Home → detail bottom sheet → Edit / Favourite / Delete.

#### 2B. Wardrobe home (`screens/home/`)

- **Filter bar** under the AppBar: horizontally scrolling `MoodChip`s ("All" plus moods present), a category dropdown, and a debounced (250 ms) search field.
- **Responsive columns:** `LayoutBuilder` → `crossAxisCount = (width / 160).floor().clamp(2, 6)`.
- **Card** shows name, category icon, mood dot, favourite heart. Long-press opens the same action sheet as tap.
- **Hero** on the image into the detail/edit screen.
- **Pull-to-refresh** using the provider reload.
- **Empty state copy** varies: no items at all vs. no items matching the filter ("nothing in Cozy yet ♡ — clear filters").

#### 2C. Outfit generator (`domain/outfit_generator.dart` + `screens/generator/`)

Pure function `OutfitGenerator.generate({items, mood, Random? random, Set<int>? avoidIds})`:

- Picks one `top` + one `bottom`, **or** one `dress` (50/50 when both are possible).
- `outerwear` optional (40 %), `shoes` if any, up to one `accessory` (50 %).
- When `avoidIds` is given, re-rolls up to 5 times to avoid returning the identical set (powers Shuffle).
- Returns a `GenerationResult` with `items` and `missing: List<ClothingCategory>` so the UI can say "add a bottom for Cozy to complete this look".

Screen:

- Mood chips show a **count badge** of pieces per mood; unavailable moods are dimmed with a tooltip.
- Cut the fake delay to about 700 ms, kept only for the typewriter animation; use `AnimatedSwitcher` plus staggered `SlideTransition` for result cards.
- Action row after a result: **Shuffle**, **Save look** (name dialog → `OutfitsProvider.save`), **Share** (optional Phase 3 extra).
- Partial-outfit state names the missing category with a CTA to add it.

#### 2D. Saved outfits (`screens/saved_outfits/`) — fulfils "organize outfits by mood"

- Grouped by mood with sticky section headers (emoji + colour); each outfit is a horizontal strip of item thumbnails plus name and date.
- Tap opens a full-screen look view; swipe-to-delete with an undo `SnackBar`; favourite toggle.
- Items whose clothing was deleted drop out via cascade; show "1 piece no longer in wardrobe" when fewer items load than were saved.

#### 2E. Navigation

- Bottom `NavigationBar` with three destinations: **Wardrobe**, **Generate**, **Looks**. Keep the Add FAB on Wardrobe. Settings via an AppBar action.

**Acceptance:** Items can be added, edited, favourited, deleted, filtered and searched. The generator produces a look for any mood with at least one top + bottom or one dress. Saved looks persist and group by mood. All screens are readable in dark mode.

---

### Phase 3 — UI / UX polish and animation (1.5 days)

**Goal:** deliver the "handcrafted, animated, editorial" promise.

| # | Task | Detail |
|---|---|---|
| 3.1 | **Theme tokens** | `ThemeExtension<FitLabColors>` with `cardShadow`, `chipBackground`, `chipSelectedText`, `divider`. Remove every `Colors.*` literal from screens and widgets. Add component themes: `ChipThemeData`, `InputDecorationTheme` (radius 16), `NavigationBarThemeData`, `SnackBarThemeData`, `DialogThemeData`. |
| 3.2 | **Theme persistence** | `ThemeProvider` reads/writes `shared_preferences` key `theme_mode` with values `system / light / dark`. Add a **System** option. |
| 3.3 | **Grid entrance animation** | Stagger cards with one `AnimationController` and index-based `Interval`s, only on first load (flag in provider). |
| 3.4 | **Hero transitions** | Card image → detail. |
| 3.5 | **Haptics** | `HapticFeedback.lightImpact()` on mood select, `mediumImpact()` on generate, `selectionClick()` on toggles. |
| 3.6 | **Generator reveal** | Cards slide and fade in sequence; subtle `ScaleTransition` on the selected mood chip. Keep the `AnimatedTextKit` typewriter during the short delay. |
| 3.7 | **Empty-state illustrations** | Replace bare icons with simple hand-drawn-style SVG/PNG per state under `assets/illustrations/` (declare in `pubspec`). Optional `flutter_svg`. |
| 3.8 | **Onboarding (first launch)** | Three-page `PageView` (Add pieces → Pick a mood → Save looks) gated by `shared_preferences` key `seen_onboarding`. |
| 3.9 | **Settings screen** | Theme selector, "Clear wardrobe" with confirm dialog, version via `package_info_plus`, credits (home for the `SignatureFooter` text). |
| 3.10 | **Accessibility** | `Semantics` labels on cards and chips, minimum 44 px touch targets, no overflow at text scale 1.3, chip text contrast ≥ 4.5:1 using `onColor` from 1.2. |
| 3.11 | **Responsive layout** | Cap content width at 1100 px with `Center` + `ConstrainedBox` on tablet/desktop; generator becomes two-pane at ≥ 900 px (moods left, result right). |

**Acceptance:** No `Colors.*` literals remain in `lib/screens` or `lib/widgets`. Theme survives restart. Grid scroll shows no frames over 16 ms in the DevTools performance overlay on a mid-range Android device.

---

### Phase 4 — Branding, platform config and release prep (½ day)

| # | Task | Detail |
|---|---|---|
| 4.1 | App name | Android `android:label="FitLab"`; iOS `CFBundleDisplayName` "Fit Lab" → "FitLab". |
| 4.2 | Bundle IDs | Choose e.g. `com.manal.fitlab`; update `namespace` and `applicationId` in `android/app/build.gradle.kts`, move the Kotlin package folder, set iOS `PRODUCT_BUNDLE_IDENTIFIER`. |
| 4.3 | iOS permissions | Add `NSPhotoLibraryUsageDescription` and `NSCameraUsageDescription` to `Info.plist`. |
| 4.4 | Regenerate icon and splash | `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create` after the dev-deps move. Add a dark splash variant (`color_dark: "#1E1C1A"`). |
| 4.5 | Android signing | Create `key.properties` plus keystore (git-ignored) and a release `signingConfig`. Enable `isMinifyEnabled` and `isShrinkResources` with Flutter's default ProGuard rules. |
| 4.6 | Version | Bump `1.0.0+1` per release and record in `CHANGELOG.md`. |
| 4.7 | `pubspec.yaml` | Real description; declare `assets/illustrations/`. |
| 4.8 | Platform targets | Keep Windows for dev (ffi from 0.2). Drop `web/` unless web is a goal; `sqflite_common_ffi_web` works but adds a worker setup step. |

**Acceptance:** `flutter build apk --release` succeeds, and `flutter build ios --release` succeeds on macOS. Icon, name and splash are correct on device.

---

### Phase 5 — Testing (1 day)

| Layer | Tests | Tooling |
|---|---|---|
| Unit | `OutfitGenerator`: deterministic with seeded `Random`; top+bottom vs dress; optional layers; `missing` categories; `avoidIds` re-roll. `Mood` / `ClothingCategory` `fromString` fallbacks and synonyms. | `flutter_test` |
| Unit | `ClothingItem` / `Outfit` `toMap` / `fromMap` round-trip. | `flutter_test` |
| DB | `AppDatabase` migrations v2→v3 on an in-memory DB seeded with legacy rows; `WardrobeRepository` CRUD; `OutfitRepository` save, join, cascade delete. | `sqflite_common_ffi` with `inMemoryDatabasePath` |
| Widget | Home: empty state vs grid; filter chips narrow the list; Add FAB navigates. Add/Edit: validation errors; save calls the provider. Generator: unavailable mood is disabled; result renders N cards; Save look opens a dialog. | `mocktail` repository fakes, `pumpWidget` with `MultiProvider` |
| Golden (optional) | `ClothingCard` and `MoodChip` in light and dark. | `flutter_test` goldens |
| Integration | Add item → generate → save look → appears in Looks tab. | `integration_test` on an Android emulator |
| CI | GitHub Actions running `flutter analyze`, `flutter test --coverage`, `flutter build apk --debug` on push. | `.github/workflows/ci.yml` |

**Acceptance:** `flutter test` is green; coverage ≥ 70 % on `lib/domain` and `lib/data`.

---

### Phase 6 — Documentation and hand-off (¼ day)

- README: screenshots (light + dark), a feature list that matches reality, setup steps, the architecture tree above, how to run tests.
- `CONTRIBUTING.md` (lint, commit style) and `CHANGELOG.md`.
- Initialise git (the folder is **not** a repository today; a sensible `.gitignore` already exists) and commit at the end of each phase.

---

## 3. Suggested order and timeline

| Day | Phase |
|---|---|
| 1 | Phase 0 → commit "stabilise" |
| 2–3 | Phase 1 → commit "data layer" (start DB unit tests here) |
| 4–5 | Phase 2A–2C |
| 6 | Phase 2D–2E |
| 7–8 | Phase 3 |
| 9 | Phase 4 + remaining Phase 5 |
| 10 | Phase 5 widget/integration + Phase 6 |

**Total:** about 7 working days of focused work for one developer; about 10 including polish and on-device QA.

---

## 4. Risks and early decisions

1. **Breaking existing installs.** The v2→v3 migration must be tested against a real v2 DB file, including free-text categories and absolute image paths.
2. **Image relocation.** Old absolute-path rows need a one-time copy into the documents directory during migration; skip and show a placeholder when the source is gone.
3. **Camera on the iOS simulator** does not work; test on a physical device.
4. **Scope creep.** "Share outfit as image" (`RepaintBoundary` → PNG → `share_plus`) is a nice Phase 3 extra, not required for done.
5. **Web.** Only pursue if it is a stated goal; it adds a service-worker setup for the database.

---

## 5. Definition of done

- Every README feature bullet is demonstrably true on an Android device and in the Windows dev build.
- `flutter analyze` reports 0 issues, `flutter test` is green, and a CI badge is in the README.
- Dark and light mode are both readable on every screen.
- Data (items, images, looks, theme) survives app restart and an OS cache clear.
- The release APK builds signed with a non-debug key.
