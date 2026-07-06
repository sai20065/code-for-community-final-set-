import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Prajadhwani brand system — bold indigo/saffron/teal/vermilion, replacing
/// the earlier Trust-Blue palette. Every existing call site keeps working
/// unchanged: the original token names (`trustBlue`, `marigoldOrange`, etc.)
/// are kept as aliases onto the new hues below, so the whole app picks up
/// the rebrand without a file-by-file rename.
class AppColors {
  AppColors._();

  // ---- New brand tokens ----
  static const indigo = Color(0xFF2E1F8F);
  static const indigoDeep = Color(0xFF1C1259);
  static const indigoMist = Color(0xFFE9E6F8);

  static const saffron = Color(0xFFFFA630);
  static const saffronDeep = Color(0xFFC97914);
  static const saffronMist = Color(0xFFFFF1DA);

  static const teal = Color(0xFF0B8A6C);
  static const tealDeep = Color(0xFF075F4C);
  static const tealMist = Color(0xFFDBF2EA);

  static const vermilion = Color(0xFFE0384A);
  static const vermilionDeep = Color(0xFFA5202F);
  static const vermilionMist = Color(0xFFFBE1E4);

  static const ink = Color(0xFF14131F);
  static const inkSoft = Color(0xFF57547A);
  static const inkFaint = Color(0xFF8C89AB);
  static const paper = Color(0xFFF3F2EE);
  static const paperRaised = Color(0xFFFFFFFF);

  // ---- Backward-compatible aliases (do not remove — used throughout) ----
  static const trustBlue = indigo;
  static const marigoldOrange = saffron;
  static const leafGreen = teal;
  static const amberWarning = saffron;
  static const coralRed = vermilion;
  static const warmOffWhite = paper;
  static const charcoal = ink;

  // Per-category accents. `roads`/`water`/`education` now map onto the four
  // core brand hues (matching the MP dashboard demand-map legend); the
  // categories the new brief doesn't touch (electricity/health/sanitation)
  // keep their original distinct hues; `skilling` is new.
  static const categoryRoads = vermilion;
  static const categoryWater = teal;
  static const categoryElectricity = Color(0xFFF1C40F);
  static const categoryHealth = Color(0xFFE84393);
  static const categorySanitation = Color(0xFF27AE60);
  static const categoryEducation = indigo;
  static const categorySkilling = saffronDeep;

  // Tricolor-inspired trust strip shown under the AppBar — kept, retinted.
  static const tricolorStrip = [indigo, Colors.white, teal];
}

/// Maps a submission theme/category id to its accent color, so any widget
/// can color-code a chip/icon consistently without re-deriving the mapping.
Color categoryColor(String themeId) {
  switch (themeId) {
    case 'roads':
      return AppColors.categoryRoads;
    case 'water':
      return AppColors.categoryWater;
    case 'electricity':
      return AppColors.categoryElectricity;
    case 'health':
      return AppColors.categoryHealth;
    case 'sanitation':
      return AppColors.categorySanitation;
    case 'education':
      return AppColors.categoryEducation;
    case 'skilling':
      return AppColors.categorySkilling;
    default:
      return AppColors.ink;
  }
}

/// Status colors for the New → Reviewed → In Progress → Resolved stepper
/// (problem reports) — reuses the four core brand hues so status and brand
/// never introduce a fifth ad-hoc color.
Color statusColor(String status) {
  switch (status) {
    case 'resolved':
      return AppColors.teal;
    case 'inProgress':
      return AppColors.saffron;
    case 'new':
      return AppColors.vermilion;
    case 'reviewed':
    default:
      return AppColors.indigo;
  }
}

/// Shared corner-radius scale (14–22px per the brand spec) so cards don't
/// drift to ad-hoc values across screens.
class AppRadii {
  AppRadii._();
  static const sm = 14.0;
  static const md = 18.0;
  static const lg = 22.0;
}

/// Soft layered shadow used on raised cards — two stacked, low-opacity
/// shadows read as "soft" rather than a single hard drop shadow.
List<BoxShadow> get appCardShadow => [
      BoxShadow(
        color: AppColors.ink.withValues(alpha: 0.04),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: AppColors.ink.withValues(alpha: 0.06),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];

class AppTheme {
  AppTheme._();

  static ThemeData get citizen => _build();
  static ThemeData get official => _build();

  static ThemeData _build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      primary: AppColors.indigo,
      secondary: AppColors.saffron,
      surface: AppColors.paper,
      error: AppColors.vermilion,
      brightness: Brightness.light,
    );

    final baseText = GoogleFonts.interTextTheme()
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
    final textTheme = baseText.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(textStyle: baseText.displayLarge, fontWeight: FontWeight.w700),
      displayMedium: GoogleFonts.spaceGrotesk(textStyle: baseText.displayMedium, fontWeight: FontWeight.w700),
      displaySmall: GoogleFonts.spaceGrotesk(textStyle: baseText.displaySmall, fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.spaceGrotesk(textStyle: baseText.headlineLarge, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.spaceGrotesk(textStyle: baseText.headlineMedium, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.spaceGrotesk(textStyle: baseText.headlineSmall, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.spaceGrotesk(textStyle: baseText.titleLarge, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.spaceGrotesk(textStyle: baseText.titleMedium, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.spaceGrotesk(textStyle: baseText.titleSmall, fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.saffron,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.saffron,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}

/// Tricolor-inspired trust strip: a 3px gradient under the AppBar.
class TricolorTrustStrip extends StatelessWidget implements PreferredSizeWidget {
  const TricolorTrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppColors.tricolorStrip),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(3);
}
