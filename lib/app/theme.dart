import 'package:flutter/material.dart';

/// Section 3.1 color palette — every hue below carries specific psychological
/// intent (trust, urgency, calm). Do not introduce ad-hoc colors elsewhere;
/// extend this file instead so the palette stays centrally auditable.
class AppColors {
  AppColors._();

  static const trustBlue = Color(0xFF1957D6);
  static const marigoldOrange = Color(0xFFFF9933);
  static const leafGreen = Color(0xFF2E9E5B);
  static const amberWarning = Color(0xFFF5A623);
  static const coralRed = Color(0xFFE4572E);
  static const warmOffWhite = Color(0xFFFAF8F5);
  static const charcoal = Color(0xFF2B2B2B);

  // Per-category accents (Section 3.1) — lets low-literacy users recognize
  // a theme by color/icon alone.
  static const categoryRoads = Color(0xFF8D7B68); // grey-brown
  static const categoryWater = Color(0xFF16A085); // teal
  static const categoryElectricity = Color(0xFFF1C40F); // yellow
  static const categoryHealth = Color(0xFFE84393); // pink-red
  static const categorySanitation = Color(0xFF27AE60); // green
  static const categoryEducation = Color(0xFF4B4E9E); // indigo

  // Tricolor-inspired trust strip shown under the AppBar (Section 3.4) —
  // a subtle nod, not a reproduction of the national flag.
  static const tricolorStrip = [trustBlue, Colors.white, leafGreen];
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
    default:
      return AppColors.charcoal;
  }
}

/// Status colors for the New → Reviewed → In Progress → Resolved stepper
/// (Section 3.5). Kept separate from category colors since status and
/// category are independent dimensions of a submission.
Color statusColor(String status) {
  switch (status) {
    case 'resolved':
      return AppColors.leafGreen;
    case 'inProgress':
      return AppColors.amberWarning;
    case 'new':
      return AppColors.coralRed;
    case 'reviewed':
    default:
      return AppColors.trustBlue;
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get citizen => _build();
  static ThemeData get official => _build();

  static ThemeData _build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.trustBlue,
      primary: AppColors.trustBlue,
      secondary: AppColors.marigoldOrange,
      surface: AppColors.warmOffWhite,
      error: AppColors.coralRed,
      brightness: Brightness.light,
    );

    final textTheme = Typography.material2021()
        .black
        .apply(bodyColor: AppColors.charcoal, displayColor: AppColors.charcoal);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.warmOffWhite,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.trustBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.marigoldOrange,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.marigoldOrange,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
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
          borderRadius: BorderRadius.circular(16),
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

/// Section 3.4 trust strip: a 3px tricolor-inspired gradient under the AppBar.
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
