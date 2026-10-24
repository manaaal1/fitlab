import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extra design tokens that Material's [ColorScheme] does not cover.
@immutable
class FitLabColors extends ThemeExtension<FitLabColors> {
  const FitLabColors({
    required this.chipBackground,
    required this.chipForeground,
    required this.subtleText,
    required this.cardShadow,
    required this.imagePlaceholder,
    required this.favorite,
  });

  final Color chipBackground;
  final Color chipForeground;
  final Color subtleText;
  final Color cardShadow;
  final Color imagePlaceholder;
  final Color favorite;

  static const light = FitLabColors(
    chipBackground: Color(0xFFF1EAE2),
    chipForeground: Color(0xFF4A3F38),
    subtleText: Color(0xFF7A6E66),
    cardShadow: Color(0x1F3B2A1E),
    imagePlaceholder: Color(0xFFEDE5DC),
    favorite: Color(0xFFD9667A),
  );

  static const dark = FitLabColors(
    chipBackground: Color(0xFF34302C),
    chipForeground: Color(0xFFE9DFD6),
    subtleText: Color(0xFFB3A79D),
    cardShadow: Color(0x66000000),
    imagePlaceholder: Color(0xFF3A3531),
    favorite: Color(0xFFF08DA0),
  );

  static FitLabColors of(BuildContext context) =>
      Theme.of(context).extension<FitLabColors>() ?? light;

  @override
  FitLabColors copyWith({
    Color? chipBackground,
    Color? chipForeground,
    Color? subtleText,
    Color? cardShadow,
    Color? imagePlaceholder,
    Color? favorite,
  }) {
    return FitLabColors(
      chipBackground: chipBackground ?? this.chipBackground,
      chipForeground: chipForeground ?? this.chipForeground,
      subtleText: subtleText ?? this.subtleText,
      cardShadow: cardShadow ?? this.cardShadow,
      imagePlaceholder: imagePlaceholder ?? this.imagePlaceholder,
      favorite: favorite ?? this.favorite,
    );
  }

  @override
  FitLabColors lerp(FitLabColors? other, double t) {
    if (other == null) return this;
    return FitLabColors(
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      chipForeground: Color.lerp(chipForeground, other.chipForeground, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      imagePlaceholder: Color.lerp(
        imagePlaceholder,
        other.imagePlaceholder,
        t,
      )!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const lightBackground = Color(0xFFFDFBF7);

  /// Readable foreground for arbitrary swatch or mood colours.
  static Color contrastOn(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF2B2420);
  static const darkBackground = Color(0xFF1E1C1A);

  /// [useGoogleFonts] is turned off in tests, which have no network.
  static ThemeData light({bool useGoogleFonts = true}) => _build(
    brightness: Brightness.light,
    primary: const Color(0xFFB07D62),
    secondary: const Color(0xFFDCCFC0),
    background: lightBackground,
    surface: Colors.white,
    onSurface: const Color(0xFF2B2420),
    tokens: FitLabColors.light,
    useGoogleFonts: useGoogleFonts,
  );

  static ThemeData dark({bool useGoogleFonts = true}) => _build(
    brightness: Brightness.dark,
    primary: const Color(0xFFD6B7A3),
    secondary: const Color(0xFF3A3531),
    background: darkBackground,
    surface: const Color(0xFF2A2724),
    onSurface: const Color(0xFFF3ECE6),
    tokens: FitLabColors.dark,
    useGoogleFonts: useGoogleFonts,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color onSurface,
    required FitLabColors tokens,
    required bool useGoogleFonts,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      onPrimary: isDark ? const Color(0xFF2B2420) : Colors.white,
      secondary: secondary,
      surface: surface,
      onSurface: onSurface,
    );

    final base = ThemeData(brightness: brightness).textTheme;
    final body = useGoogleFonts ? GoogleFonts.poppinsTextTheme(base) : base;
    TextStyle script(double size) {
      final style = TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.1,
      );
      return useGoogleFonts ? GoogleFonts.caveat(textStyle: style) : style;
    }

    final textTheme = body
        .apply(bodyColor: onSurface, displayColor: onSurface)
        .copyWith(
          displaySmall: script(48),
          headlineLarge: script(42),
          headlineMedium: script(30),
          headlineSmall: script(26),
          bodyMedium: body.bodyMedium?.copyWith(color: tokens.subtleText),
        );

    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: script(34),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        shape: rounded16,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.22),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: background,
        indicatorColor: primary.withValues(alpha: 0.22),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.chipBackground,
        selectedColor: primary,
        labelStyle: textTheme.labelLarge?.copyWith(
          color: tokens.chipForeground,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onPrimary,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.chipBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: rounded16,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: primary.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}
