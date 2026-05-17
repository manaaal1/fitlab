import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {

  // LIGHT THEME
  static ThemeData lightTheme = ThemeData(

    brightness: Brightness.light,

    scaffoldBackgroundColor:
        const Color(0xFFFDFBF7),

    colorScheme: ColorScheme.light(

      primary: const Color(0xFFB07D62),

      secondary: const Color(0xFFDCCFC0),

      surface: Colors.white,
    ),

    textTheme: TextTheme(

      headlineLarge:
          GoogleFonts.caveat(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),

      headlineMedium:
          GoogleFonts.caveat(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),

      bodyLarge:
          GoogleFonts.poppins(
        fontSize: 16,
        color: Colors.black87,
      ),

      bodyMedium:
          GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.black54,
      ),
    ),

    appBarTheme: AppBarTheme(

      backgroundColor:
          const Color(0xFFFDFBF7),

      elevation: 0,

      centerTitle: true,

      titleTextStyle:
          GoogleFonts.caveat(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),

    floatingActionButtonTheme:
        const FloatingActionButtonThemeData(
      backgroundColor:
          Color(0xFFB07D62),
      foregroundColor: Colors.white,
    ),
  );

  // DARK THEME
  static ThemeData darkTheme = ThemeData(

    brightness: Brightness.dark,

    scaffoldBackgroundColor:
        const Color(0xFF1E1C1A),

    colorScheme: ColorScheme.dark(

      primary: const Color(0xFFD6B7A3),

      secondary: const Color(0xFF3A3531),

      surface: const Color(0xFF2A2724),
    ),

    textTheme: TextTheme(

      headlineLarge:
          GoogleFonts.caveat(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),

      headlineMedium:
          GoogleFonts.caveat(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),

      bodyLarge:
          GoogleFonts.poppins(
        fontSize: 16,
        color: Colors.white,
      ),

      bodyMedium:
          GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.white70,
      ),
    ),

    appBarTheme: AppBarTheme(

      backgroundColor:
          const Color(0xFF1E1C1A),

      elevation: 0,

      centerTitle: true,

      titleTextStyle:
          GoogleFonts.caveat(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),

    floatingActionButtonTheme:
        const FloatingActionButtonThemeData(
      backgroundColor:
          Color(0xFFD6B7A3),
      foregroundColor: Colors.black,
    ),
  );
}