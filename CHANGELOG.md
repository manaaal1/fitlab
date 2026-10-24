# Changelog

## 1.1.0

### Added
- Backup and restore: export pieces, photos, looks and wear history to a zip file, and restore it (replacing the current wardrobe) from Settings.
- Pin pieces in a generated look and shuffle only the rest.
- "Style this piece" on a piece's detail screen opens looks built around it.
- Add several pieces at once by picking multiple photos.
- Pieces can have several moods.
- "Wore this today" for a piece, a generated look or a saved look, with wear counts and last-worn dates.
- Forgotten pieces: a banner and filter for clothes not worn in 30 days.
- Automatic colour detection from the photo.
- Colour matching in the generator: clashing accent colours are much less likely.

### Changed
- Database schema v4 (moods column and wear log), migrated automatically from v3 and earlier.

## 1.0.1

### Added
- Share a look as a 1080×1350 image card from the generator or a saved look.
- Bundled Caveat and Poppins fonts; no runtime font downloads. Licences are listed in Settings.
- Golden screenshot tests for the main screens in light, dark and wide layouts.
- Device integration test for onboarding, generate, save, delete and undo.

### Fixed
- Saved look tiles looked grey because their shadow showed through a transparent background.
- Outfit cards in the generator and look detail left a large empty area under each piece.
- Onboarding content sat at the top of the screen instead of the centre.
- The selected mood chip's glow was clipped into a square on the wardrobe filter row.

## 1.0.0

### Added
- Saved looks: name, favourite, rename, delete with undo, grouped by mood.
- Edit and favourite pieces; optional colour swatch and notes.
- Category picker (top, bottom, dress, outerwear, shoes, accessory) replacing free text.
- Wardrobe search plus mood, category and favourite filters.
- Shuffle and save actions in the generator, with a hint for missing pieces.
- Bottom navigation on phones, navigation rail on wide screens.
- Onboarding, settings screen, persisted light/dark/system theme.
- Camera capture where supported.
- Windows and Linux support through `sqflite_common_ffi`.
- Unit, database and widget tests; GitHub Actions CI.

### Changed
- Database schema v3 with migration from v2. Legacy free-text categories and mood labels are normalised.
- Photos are copied into app storage instead of referencing the picker cache.
- Theme tokens replace hard-coded colours, so every screen works in dark mode.
- Responsive grid column count.
- App name "FitLab" and bundle id `com.manal.fitlab`.

### Fixed
- Deleting a piece crashed because it targeted the wrong table.
- The generator only worked when categories were typed exactly as "top", "bottom", "outerwear" or "shoes".
- Possible crashes when leaving a screen during an async operation.
- Form fields scrolled off-screen were skipped by validation.
